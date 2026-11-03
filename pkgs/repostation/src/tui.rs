//! The store UI: categories │ results │ details, a README reader, and install/update/remove.
//! Installs suspend the UI and run in the plain terminal so sudo prompts and build output
//! behave normally.

use crate::engine::{self, Installed};
use crate::github::{self, BUILDABLE, Repo, fmt_count, rating};
use crate::Result;
use ratatui::crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers};
use ratatui::layout::{Constraint, Layout, Rect};
use ratatui::style::{Color, Style, Stylize};
use ratatui::text::{Line, Span, Text};
use ratatui::widgets::{Block, BorderType, List, ListItem, ListState, Paragraph, Wrap};
use ratatui::{DefaultTerminal, Frame};
use std::io::{self, Write};
use std::process::Command;

const ACCENT: Color = Color::Rgb(10, 132, 255);
const SKY: Color = Color::Rgb(100, 210, 255);
const DIM: Color = Color::Rgb(128, 138, 160);
const SELECTED: Color = Color::Rgb(18, 38, 68);

/// (label, GitHub search qualifiers). An empty query means "what's installed".
const CATEGORIES: &[(&str, &str)] = &[
    ("Popular", "stars:>15000"),
    ("CLI tools", "topic:cli stars:>1000"),
    ("Terminal UI", "topic:tui stars:>300"),
    ("System", "topic:system-monitor stars:>150"),
    ("Editors", "topic:text-editor stars:>500"),
    ("Git", "topic:git topic:cli stars:>300"),
    ("Networking", "topic:networking topic:cli stars:>300"),
    ("Wayland", "topic:wayland stars:>200"),
    ("Dev tools", "topic:developer-tools stars:>1000"),
    ("Games", "topic:terminal-game stars:>100"),
    ("Installed", ""),
];

#[derive(Clone, Copy, PartialEq)]
enum Focus {
    Categories,
    Results,
    Search,
}

#[derive(Clone, Copy)]
enum Action {
    Install,
    Update,
    Remove,
}

pub struct App {
    cat: usize,
    query: String,
    focus: Focus,
    repos: Vec<Repo>,
    list: ListState,
    readme: Option<(Text<'static>, u16)>,
    status: String,
    installed: Vec<Installed>,
}

pub fn run() -> Result<()> {
    let mut terminal = ratatui::init();
    let result = App::new().event_loop(&mut terminal);
    ratatui::restore();
    result
}

/// Leave the alternate screen, run `f` in the normal terminal, then come back.
fn suspend<T>(terminal: &mut DefaultTerminal, f: impl FnOnce() -> T) -> T {
    ratatui::restore();
    println!();
    let out = f();
    print!("\n\x1b[2mPress Enter to return to RepoStation…\x1b[0m");
    let _ = io::stdout().flush();
    let _ = io::stdin().read_line(&mut String::new());
    *terminal = ratatui::init();
    out
}

impl App {
    fn new() -> App {
        App {
            cat: 0,
            query: String::new(),
            focus: Focus::Results,
            repos: Vec::new(),
            list: ListState::default(),
            readme: None,
            status: String::new(),
            installed: engine::load(),
        }
    }

    fn event_loop(mut self, terminal: &mut DefaultTerminal) -> Result<()> {
        self.load(terminal)?;
        loop {
            terminal.draw(|f| self.draw(f))?;
            let Event::Key(key) = event::read()? else { continue };
            if key.kind != KeyEventKind::Press {
                continue;
            }
            if key.code == KeyCode::Char('c') && key.modifiers.contains(KeyModifiers::CONTROL) {
                return Ok(());
            }
            if self.on_key(terminal, key.code)? {
                return Ok(());
            }
        }
    }

    fn selected(&self) -> Option<&Repo> {
        self.list.selected().and_then(|i| self.repos.get(i))
    }

    fn installed_entry(&self, name: &str) -> Option<&Installed> {
        self.installed.iter().find(|e| e.repo.eq_ignore_ascii_case(name))
    }

    /// Show `msg` in the status line and draw once before a blocking network call.
    fn busy(&mut self, terminal: &mut DefaultTerminal, msg: &str) -> Result<()> {
        self.status = msg.into();
        terminal.draw(|f| self.draw(f))?;
        Ok(())
    }

    fn load(&mut self, terminal: &mut DefaultTerminal) -> Result<()> {
        let (label, qualifiers) = CATEGORIES[self.cat];
        let browsing = self.query.is_empty();
        let result = if browsing && qualifiers.is_empty() {
            Ok(self.installed.iter().map(|e| Repo { full_name: e.repo.clone(), ..Repo::default() }).collect())
        } else {
            self.busy(terminal, "Searching GitHub…")?;
            if browsing { github::search(qualifiers, true) } else { github::search(&self.query, false) }
        };
        match result {
            Ok(mut repos) => {
                if browsing && !qualifiers.is_empty() {
                    repos.retain(|r| r.language.as_deref().is_some_and(|l| BUILDABLE.contains(&l)));
                }
                self.status = format!("{} · {} repositories", if browsing { label } else { "Search" }, repos.len());
                self.repos = repos;
                self.list.select((!self.repos.is_empty()).then_some(0));
            }
            Err(e) => self.status = format!("error: {e}"),
        }
        Ok(())
    }

    /// Returns true to quit.
    fn on_key(&mut self, terminal: &mut DefaultTerminal, code: KeyCode) -> Result<bool> {
        if self.focus == Focus::Search {
            match code {
                KeyCode::Enter => {
                    self.focus = Focus::Results;
                    self.load(terminal)?;
                }
                KeyCode::Esc => self.focus = Focus::Results,
                KeyCode::Backspace => {
                    self.query.pop();
                }
                KeyCode::Char(c) => self.query.push(c),
                _ => {}
            }
            return Ok(false);
        }

        if let Some((_, scroll)) = &mut self.readme {
            match code {
                KeyCode::Esc | KeyCode::Enter | KeyCode::Char('q') => self.readme = None,
                KeyCode::Down | KeyCode::Char('j') => *scroll = scroll.saturating_add(1),
                KeyCode::Up | KeyCode::Char('k') => *scroll = scroll.saturating_sub(1),
                KeyCode::PageDown | KeyCode::Char(' ') => *scroll = scroll.saturating_add(20),
                KeyCode::PageUp => *scroll = scroll.saturating_sub(20),
                KeyCode::Home | KeyCode::Char('g') => *scroll = 0,
                _ => {}
            }
            return Ok(false);
        }

        match code {
            KeyCode::Char('q') => return Ok(true),
            KeyCode::Esc if !self.query.is_empty() => {
                self.query.clear();
                self.load(terminal)?;
            }
            KeyCode::Esc => return Ok(true),
            KeyCode::Char('/') => self.focus = Focus::Search,
            KeyCode::Tab | KeyCode::BackTab => {
                self.focus = if self.focus == Focus::Results { Focus::Categories } else { Focus::Results }
            }
            KeyCode::Left | KeyCode::Char('h') => self.focus = Focus::Categories,
            KeyCode::Right | KeyCode::Char('l') => self.focus = Focus::Results,
            KeyCode::Down | KeyCode::Char('j') => self.step(terminal, 1)?,
            KeyCode::Up | KeyCode::Char('k') => self.step(terminal, -1)?,
            KeyCode::Enter if self.focus == Focus::Categories => self.focus = Focus::Results,
            KeyCode::Enter => self.open_readme(terminal)?,
            KeyCode::Char('i') => self.act(terminal, Action::Install),
            KeyCode::Char('u') => self.act(terminal, Action::Update),
            KeyCode::Char('x') => self.act(terminal, Action::Remove),
            KeyCode::Char('r') => self.load(terminal)?,
            KeyCode::Char('o') => {
                if let Some(r) = self.selected() {
                    let url = format!("https://github.com/{}", r.full_name);
                    let _ = Command::new("xdg-open").arg(&url).spawn();
                    self.status = format!("Opened {url}");
                }
            }
            _ => {}
        }
        Ok(false)
    }

    fn step(&mut self, terminal: &mut DefaultTerminal, delta: isize) -> Result<()> {
        if self.focus == Focus::Categories {
            self.cat = (self.cat as isize + delta).rem_euclid(CATEGORIES.len() as isize) as usize;
            self.query.clear();
            return self.load(terminal);
        }
        if !self.repos.is_empty() {
            let i = self.list.selected().unwrap_or(0) as isize + delta;
            self.list.select(Some(i.clamp(0, self.repos.len() as isize - 1) as usize));
        }
        Ok(())
    }

    fn open_readme(&mut self, terminal: &mut DefaultTerminal) -> Result<()> {
        let Some(name) = self.selected().map(|r| r.full_name.clone()) else { return Ok(()) };
        self.busy(terminal, "Loading README…")?;
        match github::readme(&name) {
            Ok(md) => {
                self.readme = Some((render_markdown(&md), 0));
                self.status = format!("{name} · README");
            }
            Err(e) => self.status = format!("README: {e}"),
        }
        Ok(())
    }

    fn act(&mut self, terminal: &mut DefaultTerminal, action: Action) {
        let Some(name) = self.selected().map(|r| r.full_name.clone()) else { return };
        let installed = self.installed_entry(&name).is_some();
        match (action, installed) {
            (Action::Install, true) => return self.status = format!("{name} is installed; press u to update"),
            (Action::Update | Action::Remove, false) => return self.status = format!("{name} isn't installed; press i"),
            _ => {}
        }
        let result = suspend(terminal, || {
            let r = match action {
                Action::Install => engine::install(&name),
                Action::Update => engine::update(Some(&name)),
                Action::Remove if engine::ask(&format!("Remove {name}?")) => engine::remove(&name),
                Action::Remove => Ok(()),
            };
            if let Err(e) = &r {
                println!("\x1b[1;31merror:\x1b[0m {e}");
            }
            r
        });
        self.installed = engine::load();
        self.status = match result {
            Ok(()) => format!("{name}: done"),
            Err(e) => format!("{name}: {e}"),
        };
    }

    // ───────────────────────────── drawing ─────────────────────────────

    pub fn draw(&mut self, f: &mut Frame) {
        let [top, body, foot] = Layout::vertical([Constraint::Length(3), Constraint::Min(0), Constraint::Length(1)]).areas(f.area());
        self.draw_search(f, top);

        if let Some((text, scroll)) = &self.readme {
            let block = panel(self.selected().map_or("README", |r| r.full_name.as_str()), true);
            f.render_widget(Paragraph::new(text.clone()).wrap(Wrap { trim: false }).scroll((*scroll, 0)).block(block), body);
            footer(f, foot, "↑↓ scroll  space page  esc back", &self.status);
            return;
        }

        let [cats, results, details] = Layout::horizontal([Constraint::Length(17), Constraint::Fill(3), Constraint::Fill(2)]).areas(body);

        let items = CATEGORIES.iter().enumerate().map(|(i, (label, _))| {
            if i == self.cat { ListItem::new(format!("▸ {label}").fg(ACCENT).bold()) } else { ListItem::new(format!("  {label}")) }
        });
        f.render_widget(List::new(items).block(panel("Browse", self.focus == Focus::Categories)), cats);

        let width = results.width.saturating_sub(7) as usize;
        let items = self.repos.iter().map(|r| {
            let mark = if self.installed_entry(&r.full_name).is_some() { "✓ ".fg(Color::Green) } else { "  ".into() };
            ListItem::new(vec![
                Line::from(vec![
                    mark,
                    format!("★ {:>6}  ", fmt_count(r.stargazers_count)).fg(Color::Yellow),
                    r.full_name.clone().bold(),
                    format!("  {}", r.language.as_deref().unwrap_or("")).fg(DIM),
                ]),
                Line::from(format!("    {}", truncate(r.description.as_deref().unwrap_or(""), width))).fg(DIM),
            ])
        });
        let list = List::new(items)
            .block(panel("Results", self.focus == Focus::Results))
            .highlight_style(Style::new().bg(SELECTED))
            .highlight_symbol("▌");
        f.render_stateful_widget(list, results, &mut self.list);

        f.render_widget(Paragraph::new(self.details()).wrap(Wrap { trim: true }).block(panel("Details", false)), details);
        footer(f, foot, "/ search  tab browse  ↵ readme  i install  u update  x remove  o open  q quit", &self.status);
    }

    fn draw_search(&self, f: &mut Frame, area: Rect) {
        let editing = self.focus == Focus::Search;
        let title = Line::from(vec![" Repo".fg(SKY).bold(), "Station ".fg(ACCENT).bold()]);
        let input: Span = if self.query.is_empty() && !editing {
            "Press / to search GitHub".fg(DIM)
        } else {
            self.query.clone().into()
        };
        let block = Block::bordered()
            .border_type(BorderType::Rounded)
            .border_style(Style::new().fg(if editing { ACCENT } else { DIM }))
            .title(title);
        f.render_widget(Paragraph::new(Line::from(vec![" ".into(), input])).block(block), area);
        if editing {
            f.set_cursor_position((area.x + 2 + self.query.chars().count() as u16, area.y + 1));
        }
    }

    fn details(&self) -> Text<'static> {
        let Some(r) = self.selected() else { return Text::from("Nothing selected".fg(DIM)) };
        let kv = |k: &str, v: String| Line::from(vec![format!("{k:<10}").fg(DIM), v.into()]);
        let mut lines = vec![
            Line::from(r.full_name.clone().fg(SKY).bold()),
            Line::from(rating(r.stargazers_count).fg(Color::Yellow)),
            Line::default(),
            Line::from(r.description.clone().unwrap_or_default()),
            Line::default(),
            kv("Stars", fmt_count(r.stargazers_count)),
            kv("Forks", fmt_count(r.forks_count)),
            kv("Language", r.language.clone().unwrap_or_else(|| "—".into())),
            kv("License", r.license.as_ref().and_then(|l| l.spdx_id.clone()).unwrap_or_else(|| "—".into())),
            kv("Updated", r.updated_at.get(..10).unwrap_or("—").into()),
            kv("Build", r.likely_build().into()),
        ];
        if !r.topics.is_empty() {
            lines.push(Line::default());
            lines.push(Line::from(r.topics.iter().map(|t| format!("#{t} ")).collect::<String>().fg(ACCENT)));
        }
        if let Some(e) = self.installed_entry(&r.full_name) {
            lines.push(Line::default());
            lines.push(Line::from("✓ Installed".fg(Color::Green).bold()));
            lines.push(kv("Commit", e.commit.get(..7).unwrap_or(&e.commit).into()));
            lines.push(kv("Built by", e.system.clone()));
            lines.push(kv("Commands", e.bins.join(" ")));
        }
        Text::from(lines)
    }
}

fn panel(title: &str, focused: bool) -> Block<'static> {
    Block::bordered()
        .border_type(BorderType::Rounded)
        .border_style(Style::new().fg(if focused { ACCENT } else { DIM }))
        .title(format!(" {title} ").bold())
}

fn footer(f: &mut Frame, area: Rect, keys: &str, status: &str) {
    let [left, right] = Layout::horizontal([Constraint::Fill(1), Constraint::Length(status.chars().count() as u16 + 1)]).areas(area);
    f.render_widget(Paragraph::new(keys.to_owned().fg(DIM)), left);
    f.render_widget(Paragraph::new(status.to_owned().fg(SKY)), right);
}

fn truncate(s: &str, max: usize) -> String {
    if s.chars().count() <= max { s.into() } else { s.chars().take(max.saturating_sub(1)).collect::<String>() + "…" }
}

/// Just enough Markdown for a terminal: headings, code blocks, no HTML noise.
fn render_markdown(md: &str) -> Text<'static> {
    let mut in_code = false;
    let mut lines = Vec::new();
    for raw in md.lines() {
        if raw.trim_start().starts_with("```") {
            in_code = !in_code;
            continue;
        }
        if in_code {
            lines.push(Line::from(format!("  {raw}").fg(SKY)));
            continue;
        }
        let text = strip_html(raw);
        if text.trim().is_empty() && !raw.trim().is_empty() {
            continue; // the line was only tags/images
        }
        if let Some(h) = text.trim_start().strip_prefix('#') {
            lines.push(Line::from(h.trim_start_matches('#').trim().to_owned().fg(ACCENT).bold()));
        } else {
            lines.push(Line::from(text));
        }
    }
    Text::from(lines)
}

fn strip_html(line: &str) -> String {
    let mut out = String::with_capacity(line.len());
    let mut in_tag = false;
    for c in line.chars() {
        match c {
            '<' => in_tag = true,
            '>' if in_tag => in_tag = false,
            _ if !in_tag => out.push(c),
            _ => {}
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use ratatui::{Terminal, backend::TestBackend};

    #[test]
    fn renders_store_layout() {
        let mut app = App::new();
        app.repos = vec![Repo {
            full_name: "sharkdp/bat".into(),
            description: Some("A cat(1) clone with wings.".into()),
            stargazers_count: 52_400,
            forks_count: 1_300,
            language: Some("Rust".into()),
            topics: vec!["cli".into(), "terminal".into()],
            updated_at: "2026-10-01T00:00:00Z".into(),
            ..Repo::default()
        }];
        app.list.select(Some(0));
        app.status = "CLI tools · 1 repositories".into();
        let mut terminal = Terminal::new(TestBackend::new(110, 24)).unwrap();
        terminal.draw(|f| app.draw(f)).unwrap();
        let buf = terminal.backend().buffer();
        let screen: String = buf.content().chunks(buf.area.width as usize).map(|row| row.iter().map(|c| c.symbol()).collect::<String>() + "\n").collect();
        println!("{screen}");
        for needle in ["RepoStation", "sharkdp/bat", "★★★★★", "Cargo", "52.4k", "#cli"] {
            assert!(screen.contains(needle), "missing {needle}");
        }
    }

    #[test]
    fn markdown_drops_html_and_styles_headings() {
        let text = render_markdown("<p align=\"center\"><img src=\"x.png\"></p>\n# Title\nplain <b>bold</b>\n```\ncode\n```");
        let lines: Vec<String> = text.lines.iter().map(|l| l.to_string()).collect();
        assert_eq!(lines, ["Title", "plain bold", "  code"]);
    }
}
