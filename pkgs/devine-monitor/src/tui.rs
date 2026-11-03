//! Terminal view: CPU, memory and GPU, network, temperatures, and a process table you can
//! sort, filter and kill from.

use crate::sample::{Proc, Sampler, Snapshot, fmt_bytes, fmt_uptime};
use ratatui::crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers};
use ratatui::layout::{Constraint, Layout, Rect};
use ratatui::style::{Color, Style, Stylize};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, LineGauge, Paragraph, RenderDirection, Row, Sparkline, Table, TableState};
use ratatui::{DefaultTerminal, Frame};
use std::collections::VecDeque;
use std::io;
use std::time::{Duration, Instant};

const ACCENT: Color = Color::Rgb(10, 132, 255);
const SKY: Color = Color::Rgb(100, 210, 255);
const INDIGO: Color = Color::Rgb(94, 92, 230);
const DIM: Color = Color::Rgb(128, 138, 160);
const SELECTED: Color = Color::Rgb(18, 38, 68);
const WARM: Color = Color::Rgb(255, 204, 0);
const HOT: Color = Color::Rgb(255, 69, 58);
const HISTORY: usize = 300;
const TICK: Duration = Duration::from_secs(1);

#[derive(Clone, Copy, PartialEq)]
enum Sort {
    Cpu,
    Mem,
    Pid,
    Name,
}

pub struct App {
    sampler: Option<Sampler>,
    snap: Snapshot,
    cpu: VecDeque<u64>,
    gpu: VecDeque<u64>,
    rx: VecDeque<u64>,
    tx: VecDeque<u64>,
    sort: Sort,
    filter: String,
    filtering: bool,
    table: TableState,
    selected: Option<u32>,
    confirm: Option<(Proc, bool)>, // process, SIGKILL?
    status: String,
}

pub fn run() -> io::Result<()> {
    let sampler = Sampler::new().map_err(io::Error::other)?;
    std::thread::sleep(sysinfo::MINIMUM_CPU_UPDATE_INTERVAL);
    let mut terminal = ratatui::init();
    let result = App::new(Some(sampler)).event_loop(&mut terminal);
    ratatui::restore();
    result
}

fn push(q: &mut VecDeque<u64>, v: u64) {
    if q.len() == HISTORY {
        q.pop_front();
    }
    q.push_back(v);
}

fn heat(pct: f32) -> Color {
    if pct >= 85.0 { HOT } else if pct >= 60.0 { WARM } else { ACCENT }
}

/// A bar `width` cells wide, in eighths: ███▌
fn bar(frac: f32, width: usize) -> String {
    const PARTS: [char; 8] = [' ', '▏', '▎', '▍', '▌', '▋', '▊', '▉'];
    let eighths = (frac.clamp(0.0, 1.0) * (width * 8) as f32).round() as usize;
    let mut s = "█".repeat(eighths / 8);
    if eighths / 8 < width {
        s.push(PARTS[eighths % 8]);
    }
    format!("{s:<width$}")
}

fn panel(title: Line<'static>) -> Block<'static> {
    Block::bordered().border_type(BorderType::Rounded).border_style(Style::new().fg(DIM)).title(title)
}

fn spark<'a>(q: &'a VecDeque<u64>, color: Color, max: Option<u64>) -> Sparkline<'a> {
    let s = Sparkline::default().data(q.iter().rev().copied()).direction(RenderDirection::RightToLeft).style(Style::new().fg(color));
    match max {
        Some(m) => s.max(m),
        None => s,
    }
}

impl App {
    fn new(sampler: Option<Sampler>) -> App {
        let mut app = App {
            sampler,
            snap: Snapshot::default(),
            cpu: VecDeque::new(),
            gpu: VecDeque::new(),
            rx: VecDeque::new(),
            tx: VecDeque::new(),
            sort: Sort::Cpu,
            filter: String::new(),
            filtering: false,
            table: TableState::default(),
            selected: None,
            confirm: None,
            status: String::new(),
        };
        app.tick();
        app
    }

    fn tick(&mut self) {
        let Some(snap) = self.sampler.as_mut().map(Sampler::sample) else { return };
        self.ingest(snap);
    }

    fn ingest(&mut self, snap: Snapshot) {
        push(&mut self.cpu, snap.cpu as u64);
        push(&mut self.gpu, snap.gpu.as_ref().map_or(0, |g| g.util as u64));
        push(&mut self.rx, snap.net_rx);
        push(&mut self.tx, snap.net_tx);
        self.snap = snap;
    }

    fn event_loop(&mut self, terminal: &mut DefaultTerminal) -> io::Result<()> {
        let mut next = Instant::now() + TICK;
        loop {
            terminal.draw(|f| self.draw(f))?;
            if event::poll(next.saturating_duration_since(Instant::now()))? {
                if let Event::Key(k) = event::read()?
                    && k.kind == KeyEventKind::Press
                    && self.on_key(k.code, k.modifiers)
                {
                    return Ok(());
                }
            } else {
                self.tick();
                next = Instant::now() + TICK;
            }
        }
    }

    /// Processes after filter and sort.
    fn visible(&self) -> Vec<&Proc> {
        let needle = self.filter.to_lowercase();
        let mut rows: Vec<&Proc> = self
            .snap
            .procs
            .iter()
            .filter(|p| needle.is_empty() || p.name.to_lowercase().contains(&needle) || p.cmd.to_lowercase().contains(&needle))
            .collect();
        match self.sort {
            Sort::Cpu => rows.sort_by(|a, b| b.cpu.total_cmp(&a.cpu)),
            Sort::Mem => rows.sort_by_key(|p| std::cmp::Reverse(p.mem)),
            Sort::Pid => rows.sort_by_key(|p| p.pid),
            Sort::Name => rows.sort_by_key(|p| p.name.to_lowercase()),
        }
        rows
    }

    /// Returns true to quit.
    fn on_key(&mut self, code: KeyCode, mods: KeyModifiers) -> bool {
        if code == KeyCode::Char('c') && mods.contains(KeyModifiers::CONTROL) {
            return true;
        }
        if let Some((p, force)) = self.confirm.take() {
            if code == KeyCode::Char('y') {
                let sent = self.sampler.as_ref().is_some_and(|s| s.kill(p.pid, force));
                self.status = if sent {
                    format!("sent {} to {} ({})", if force { "SIGKILL" } else { "SIGTERM" }, p.name, p.pid)
                } else {
                    format!("couldn't signal {} ({}): not yours, or already gone", p.name, p.pid)
                };
            } else {
                self.status.clear();
            }
            return false;
        }
        if self.filtering {
            match code {
                KeyCode::Enter => self.filtering = false,
                KeyCode::Esc => {
                    self.filtering = false;
                    self.filter.clear();
                }
                KeyCode::Backspace => {
                    self.filter.pop();
                }
                KeyCode::Char(c) => self.filter.push(c),
                _ => {}
            }
            return false;
        }
        match code {
            KeyCode::Char('q') => return true,
            KeyCode::Esc if !self.filter.is_empty() => self.filter.clear(),
            KeyCode::Esc => return true,
            KeyCode::Char('/') => self.filtering = true,
            KeyCode::Char('c') => self.sort = Sort::Cpu,
            KeyCode::Char('m') => self.sort = Sort::Mem,
            KeyCode::Char('p') => self.sort = Sort::Pid,
            KeyCode::Char('n') => self.sort = Sort::Name,
            KeyCode::Down | KeyCode::Char('j') => self.step(1),
            KeyCode::Up | KeyCode::Char('k') => self.step(-1),
            KeyCode::PageDown => self.step(15),
            KeyCode::PageUp => self.step(-15),
            KeyCode::Home => self.step(isize::MIN / 2),
            KeyCode::End => self.step(isize::MAX / 2),
            KeyCode::Char('x') | KeyCode::Delete | KeyCode::Char('X') => {
                let force = code == KeyCode::Char('X');
                if let Some(p) = self.visible().into_iter().find(|p| Some(p.pid) == self.selected).cloned() {
                    self.status = format!("{} {} ({})? y/N", if force { "Force-kill" } else { "End" }, p.name, p.pid);
                    self.confirm = Some((p, force));
                }
            }
            _ => {}
        }
        false
    }

    /// Move the selection; it follows the PID, so re-sorting doesn't jump to another process.
    fn step(&mut self, delta: isize) {
        let rows = self.visible();
        if rows.is_empty() {
            return;
        }
        let at = rows.iter().position(|p| Some(p.pid) == self.selected).unwrap_or(0) as isize;
        let to = at.saturating_add(delta).clamp(0, rows.len() as isize - 1) as usize;
        self.selected = Some(rows[to].pid);
    }

    pub fn draw(&mut self, f: &mut Frame) {
        let [head, top, mid, procs, foot] = Layout::vertical([
            Constraint::Length(1),
            Constraint::Length(11),
            Constraint::Length(8),
            Constraint::Min(6),
            Constraint::Length(1),
        ])
        .areas(f.area());

        let s = &self.snap;
        f.render_widget(
            Line::from(vec![
                " devine".fg(SKY).bold(),
                "-monitor  ".fg(ACCENT).bold(),
                format!("{} · up {} · load {:.2} {:.2} {:.2}", s.host, fmt_uptime(s.uptime), s.load[0], s.load[1], s.load[2]).fg(DIM),
            ]),
            head,
        );

        let [cpu, mem] = Layout::horizontal([Constraint::Fill(3), Constraint::Fill(2)]).areas(top);
        self.draw_cpu(f, cpu);
        self.draw_mem_gpu(f, mem);
        let [net, temps] = Layout::horizontal([Constraint::Fill(3), Constraint::Fill(2)]).areas(mid);
        self.draw_net(f, net);
        self.draw_temps(f, temps);
        self.draw_procs(f, procs);

        let keys = if self.filtering { "type to filter · ↵ keep · esc clear" } else { "c/m/p/n sort · / filter · ↑↓ select · x end · X kill · q quit" };
        let [left, right] = Layout::horizontal([Constraint::Fill(1), Constraint::Length(self.status.chars().count() as u16 + 1)]).areas(foot);
        f.render_widget(Paragraph::new(keys.fg(DIM)), left);
        f.render_widget(Paragraph::new(self.status.clone().fg(if self.confirm.is_some() { WARM } else { SKY })), right);
    }

    fn draw_cpu(&self, f: &mut Frame, area: Rect) {
        let s = &self.snap;
        let temp = s.cpu_temp.map(|t| format!(" · {t:.0}°C")).unwrap_or_default();
        let block = panel(Line::from(vec![" CPU ".bold(), format!("{:.0}%{temp} ", s.cpu).fg(heat(s.cpu))]));
        let inner = block.inner(area);
        f.render_widget(block, area);
        let [graph, cores] = Layout::vertical([Constraint::Length(4), Constraint::Min(0)]).areas(inner);
        f.render_widget(spark(&self.cpu, ACCENT, Some(100)), graph);

        let cell = 17; // "nn ████████ 100%" + gap
        let cols = (cores.width as usize / cell).max(1);
        let lines: Vec<Line> = s
            .cores
            .chunks(cols)
            .enumerate()
            .map(|(row, chunk)| {
                Line::from(
                    chunk
                        .iter()
                        .enumerate()
                        .flat_map(|(i, &pct)| {
                            [
                                format!("{:>2} ", row * cols + i).fg(DIM),
                                bar(pct / 100.0, 8).fg(heat(pct)),
                                format!("{pct:>4.0}% ").into(),
                            ]
                        })
                        .collect::<Vec<Span>>(),
                )
            })
            .collect();
        f.render_widget(Paragraph::new(lines), cores);
    }

    fn draw_mem_gpu(&self, f: &mut Frame, area: Rect) {
        let s = &self.snap;
        let block = panel(" Memory & GPU ".bold().into());
        let inner = block.inner(area);
        f.render_widget(block, area);
        let rows = Layout::vertical([Constraint::Length(1); 5].into_iter().chain([Constraint::Min(0)])).split(inner);

        let gauge = |label: String, ratio: f64, color: Color| {
            LineGauge::default()
                .ratio(ratio.clamp(0.0, 1.0))
                .label(label)
                .filled_style(Style::new().fg(color))
                .unfilled_style(Style::new().fg(Color::Rgb(40, 48, 66)))
        };
        let ratio = |used: u64, total: u64| if total == 0 { 0.0 } else { used as f64 / total as f64 };
        f.render_widget(gauge(format!("Mem  {:>6}/{}", fmt_bytes(s.mem_used), fmt_bytes(s.mem_total)), ratio(s.mem_used, s.mem_total), ACCENT), rows[0]);
        f.render_widget(gauge(format!("Swap {:>6}/{}", fmt_bytes(s.swap_used), fmt_bytes(s.swap_total)), ratio(s.swap_used, s.swap_total), INDIGO), rows[1]);

        let Some(g) = &s.gpu else {
            f.render_widget(Paragraph::new("No GPU stats (NVIDIA via NVML, AMD via sysfs)".fg(DIM)), rows[3]);
            return;
        };
        let extra = [g.temp.map(|t| format!("{t:.0}°C")), g.power_w.map(|w| format!("{w:.0} W"))].into_iter().flatten().collect::<Vec<_>>().join(" · ");
        f.render_widget(Line::from(vec![g.name.clone().bold(), format!("  {extra}").fg(DIM)]), rows[2]);
        f.render_widget(gauge(format!("GPU  {:>5.0}%", g.util), g.util as f64 / 100.0, heat(g.util)), rows[3]);
        f.render_widget(gauge(format!("VRAM {:>6}/{}", fmt_bytes(g.vram_used), fmt_bytes(g.vram_total)), ratio(g.vram_used, g.vram_total), SKY), rows[4]);
        f.render_widget(spark(&self.gpu, SKY, Some(100)), rows[5]);
    }

    fn draw_net(&self, f: &mut Frame, area: Rect) {
        let block = panel(" Network ".bold().into());
        let inner = block.inner(area);
        f.render_widget(block, area);
        let [rx_label, rx, tx_label, tx] = Layout::vertical([Constraint::Length(1), Constraint::Fill(1), Constraint::Length(1), Constraint::Fill(1)]).areas(inner);
        f.render_widget(Line::from(format!("↓ {}/s", fmt_bytes(self.snap.net_rx)).fg(SKY)), rx_label);
        f.render_widget(spark(&self.rx, SKY, None), rx);
        f.render_widget(Line::from(format!("↑ {}/s", fmt_bytes(self.snap.net_tx)).fg(INDIGO)), tx_label);
        f.render_widget(spark(&self.tx, INDIGO, None), tx);
    }

    fn draw_temps(&self, f: &mut Frame, area: Rect) {
        let block = panel(" Temperatures ".bold().into());
        let mut temps = self.snap.temps.clone();
        temps.sort_by(|a, b| b.celsius.total_cmp(&a.celsius));
        let lines: Vec<Line> = if temps.is_empty() {
            vec!["no sensors reported".fg(DIM).into()]
        } else {
            temps
                .iter()
                .map(|t| {
                    let color = if t.celsius >= 85.0 { HOT } else if t.celsius >= 70.0 { WARM } else { Color::Reset };
                    Line::from(vec![format!("{:>5.0}°C  ", t.celsius).fg(color), t.label.clone().fg(DIM)])
                })
                .collect()
        };
        f.render_widget(Paragraph::new(lines).block(block), area);
    }

    fn draw_procs(&mut self, f: &mut Frame, area: Rect) {
        let header_cell = |label: &'static str, sort: Option<Sort>| {
            if sort == Some(self.sort) { format!("{label}▼").fg(ACCENT).bold() } else { label.fg(DIM).bold() }
        };
        let header = Row::new([
            header_cell("PID", Some(Sort::Pid)),
            header_cell("USER", None),
            header_cell("CPU%", Some(Sort::Cpu)),
            header_cell("MEM", Some(Sort::Mem)),
            header_cell("COMMAND", Some(Sort::Name)),
        ]);

        let visible = self.visible();
        let count = visible.len();
        let index = visible.iter().position(|p| Some(p.pid) == self.selected);
        let first = visible.first().map(|p| p.pid);
        let rows: Vec<Row> = visible
            .iter()
            .map(|p| {
                Row::new([
                    p.pid.to_string().into(),
                    p.user.chars().take(10).collect::<String>().fg(DIM).into(),
                    format!("{:.1}", p.cpu).fg(heat(p.cpu)).into(),
                    fmt_bytes(p.mem).into(),
                    Line::from(vec![p.name.clone().bold(), format!("  {}", p.cmd).fg(DIM)]),
                ])
            })
            .collect();

        if index.is_none() {
            self.selected = first;
        }
        self.table.select(index.or(first.map(|_| 0)));

        let filter = if self.filtering || !self.filter.is_empty() { format!(" · / {}", self.filter) } else { String::new() };
        let table = Table::new(rows, [Constraint::Length(7), Constraint::Length(10), Constraint::Length(6), Constraint::Length(7), Constraint::Fill(1)])
            .header(header)
            .block(panel(Line::from(vec![" Processes ".bold(), format!("{count}{filter} ").fg(DIM)])))
            .row_highlight_style(Style::new().bg(SELECTED))
            .highlight_symbol("▌");
        f.render_stateful_widget(table, area, &mut self.table);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sample::{Gpu, Temp};
    use ratatui::{Terminal, backend::TestBackend};

    fn fixture() -> App {
        let mut app = App::new(None);
        app.ingest(Snapshot {
            host: "divine".into(),
            uptime: 11_520,
            load: [0.52, 0.40, 0.31],
            cpu: 23.0,
            cores: vec![12.0, 95.0, 40.0, 70.0, 3.0, 18.0, 22.0, 61.0],
            cpu_temp: Some(54.0),
            mem_used: 5 << 30,
            mem_total: 16 << 30,
            swap_used: 0,
            swap_total: 8 << 30,
            gpu: Some(Gpu { name: "RTX 4060 Laptop".into(), util: 34.0, vram_used: 2 << 30, vram_total: 8 << 30, temp: Some(52.0), power_w: Some(18.0) }),
            net_rx: 1_250_000,
            net_tx: 120_000,
            temps: vec![Temp { label: "Package id 0".into(), celsius: 54.0 }, Temp { label: "nvme Composite".into(), celsius: 88.0 }],
            procs: vec![
                Proc { pid: 4242, name: "kitty".into(), user: "live".into(), cpu: 3.5, mem: 180 << 20, cmd: "kitty".into() },
                Proc { pid: 1337, name: "cargo".into(), user: "live".into(), cpu: 380.0, mem: 900 << 20, cmd: "cargo build --release".into() },
                Proc { pid: 1, name: "systemd".into(), user: "root".into(), cpu: 0.0, mem: 12 << 20, cmd: "/sbin/init".into() },
            ],
        });
        app
    }

    fn render(app: &mut App) -> String {
        let mut terminal = Terminal::new(TestBackend::new(110, 34)).unwrap();
        terminal.draw(|f| app.draw(f)).unwrap();
        let buf = terminal.backend().buffer();
        buf.content().chunks(buf.area.width as usize).map(|row| row.iter().map(|c| c.symbol()).collect::<String>() + "\n").collect()
    }

    #[test]
    fn renders_dashboard() {
        let screen = render(&mut fixture());
        println!("{screen}");
        for needle in ["devine-monitor", "CPU 23% · 54°C", "RTX 4060 Laptop", "VRAM", "↓ 1.2M/s", "88°C", "cargo build --release", "CPU%▼"] {
            assert!(screen.contains(needle), "missing {needle}");
        }
        // sorted by CPU: cargo before kitty before systemd
        assert!(screen.find("cargo build").unwrap() < screen.find("kitty").unwrap());
    }

    #[test]
    fn filter_sort_and_selection_follow_the_process() {
        let mut app = fixture();
        render(&mut app);
        assert_eq!(app.selected, Some(1337)); // top CPU process selected first
        app.on_key(KeyCode::Char('j'), KeyModifiers::NONE);
        assert_eq!(app.selected, Some(4242));
        app.on_key(KeyCode::Char('p'), KeyModifiers::NONE); // re-sort by PID: selection stays on kitty
        render(&mut app);
        assert_eq!(app.selected, Some(4242));
        app.on_key(KeyCode::Char('/'), KeyModifiers::NONE);
        for c in "init".chars() {
            app.on_key(KeyCode::Char(c), KeyModifiers::NONE);
        }
        assert_eq!(app.visible().iter().map(|p| p.pid).collect::<Vec<_>>(), [1]);
        app.on_key(KeyCode::Esc, KeyModifiers::NONE);
        assert_eq!(app.visible().len(), 3);
        app.on_key(KeyCode::Char('x'), KeyModifiers::NONE);
        assert!(app.status.contains("End kitty (4242)? y/N"));
        app.on_key(KeyCode::Char('n'), KeyModifiers::NONE); // anything but y cancels
        assert!(app.confirm.is_none());
    }

    #[test]
    fn bars_fill_in_eighths() {
        assert_eq!(bar(0.0, 4), "    ");
        assert_eq!(bar(0.5, 4), "██  ");
        assert_eq!(bar(1.0, 4), "████");
        assert_eq!(bar(0.53, 4), "██▏ ");
    }
}
