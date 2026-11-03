mod engine;
mod github;
mod tui;

use std::process::ExitCode;

pub type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;

const USAGE: &str = "\
RepoStation: the divineOS app store for GitHub

usage:
  repostation                       browse in the terminal UI
  repostation search <terms>        search GitHub
  repostation install <owner/repo>  build from source and install
  repostation update [owner/repo]   rebuild what moved upstream (everything when omitted)
  repostation remove <owner/repo>   uninstall
  repostation list                  show installed apps

Builds use -march=native / target-cpu=native and install into ~/.local/opt/repostation,
with commands linked into ~/.local/bin. Set GITHUB_TOKEN to lift GitHub's rate limits.";

fn search(terms: &str) -> Result<()> {
    for r in github::search(terms, false)?.iter().take(20) {
        let desc: String = r.description.as_deref().unwrap_or("").chars().take(70).collect();
        println!("{:>7}  {:<36} {:<10} {desc}", github::fmt_count(r.stargazers_count), r.full_name, r.language.as_deref().unwrap_or(""));
    }
    Ok(())
}

fn list() {
    let installed = engine::load();
    if installed.is_empty() {
        println!("Nothing installed yet. Try: repostation install sharkdp/bat");
    }
    for e in installed {
        println!("{:<36} {:<8} {:<6} {}", e.repo, e.commit.get(..7).unwrap_or(&e.commit), e.system, e.bins.join(" "));
    }
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    let result = match args.as_slice() {
        [] => tui::run(),
        ["search", terms @ ..] if !terms.is_empty() => search(&terms.join(" ")),
        ["install", repo] => engine::install(repo),
        ["update"] => engine::update(None),
        ["update", repo] => engine::update(Some(repo)),
        ["remove", repo] => engine::remove(repo),
        ["list"] => {
            list();
            Ok(())
        }
        ["help" | "-h" | "--help"] => {
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
            eprintln!("repostation: {e}");
            ExitCode::FAILURE
        }
    }
}
