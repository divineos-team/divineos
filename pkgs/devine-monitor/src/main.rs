mod sample;
mod tui;

use sample::Sampler;
use std::io::{self, Write};
use std::process::{Command, ExitCode};
use std::time::Duration;

const USAGE: &str = "\
devine-monitor: CPU, memory, GPU, temperatures, network and processes

usage:
  devine-monitor                       terminal dashboard
  devine-monitor --gui                 glass window (toggles the divine-shell monitor)
  devine-monitor --json [--interval MS]
                                       one JSON snapshot per line (default every 1000 ms)";

/// The stream the divine-shell window reads. Ends quietly when the reader goes away.
fn json(interval: Duration) -> io::Result<()> {
    let mut sampler = Sampler::new().map_err(io::Error::other)?;
    let mut out = io::stdout().lock();
    loop {
        std::thread::sleep(interval);
        let mut snap = sampler.sample();
        snap.procs.sort_by(|a, b| b.cpu.total_cmp(&a.cpu));
        snap.procs.truncate(8);
        let line = serde_json::to_string(&snap)?;
        match writeln!(out, "{line}").and_then(|_| out.flush()) {
            Err(e) if e.kind() == io::ErrorKind::BrokenPipe => return Ok(()),
            other => other?,
        }
    }
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    let result = match args.as_slice() {
        [] => tui::run(),
        ["--json"] => json(Duration::from_secs(1)),
        ["--json", "--interval", ms] => match ms.parse::<u64>() {
            Ok(ms) if ms >= 250 => json(Duration::from_millis(ms)),
            _ => Err(io::Error::other("--interval takes milliseconds, at least 250")),
        },
        ["--gui"] => Command::new("qs").args(["-p", "/usr/share/divine-shell", "ipc", "call", "monitor", "toggle"]).status().and_then(|s| {
            if s.success() { Ok(()) } else { Err(io::Error::other("divine-shell isn't running")) }
        }),
        ["-h" | "--help" | "help"] => {
            println!("{USAGE}");
            Ok(())
        }
        _ => {
            eprintln!("{USAGE}");
            return ExitCode::from(2);
        }
    };
    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("devine-monitor: {e}");
            ExitCode::FAILURE
        }
    }
}
