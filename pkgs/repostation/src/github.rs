//! Minimal GitHub REST client: repository search and READMEs.
//! Anonymous requests get 10 searches/min; `GITHUB_TOKEN` raises that to 30/min and 5000/h.

use crate::Result;
use serde::Deserialize;
use ureq::http::Response;
use ureq::typestate::WithoutBody;
use ureq::{Body, RequestBuilder};

/// Languages the build engine knows how to turn into binaries.
pub const BUILDABLE: &[&str] = &["Rust", "Go", "C", "C++", "JavaScript", "TypeScript", "Vala"];

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct Repo {
    pub full_name: String,
    pub description: Option<String>,
    pub stargazers_count: u64,
    pub forks_count: u64,
    pub language: Option<String>,
    pub license: Option<License>,
    pub updated_at: String,
    pub topics: Vec<String>,
    pub html_url: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct License {
    pub spdx_id: Option<String>,
}

#[derive(Deserialize)]
struct SearchPage {
    items: Vec<Repo>,
}

impl Repo {
    /// Best guess before cloning; the engine detects the real build system afterwards.
    pub fn likely_build(&self) -> &'static str {
        match self.language.as_deref() {
            Some("Rust") => "Cargo",
            Some("Go") => "Go",
            Some("C" | "C++") => "Meson / CMake / Make",
            Some("JavaScript" | "TypeScript") => "npm",
            Some("Vala") => "Meson",
            _ => "unknown until cloned",
        }
    }
}

/// 48213 → "48.2k"
pub fn fmt_count(n: u64) -> String {
    match n {
        0..1_000 => n.to_string(),
        1_000..1_000_000 => format!("{:.1}k", n as f64 / 1e3),
        _ => format!("{:.1}M", n as f64 / 1e6),
    }
}

/// Stars on a log scale: 10 → ★, 100 → ★★, … 100k → ★★★★★.
pub fn rating(stars: u64) -> String {
    let n = (stars.max(1) as f64).log10().round().clamp(0.0, 5.0) as usize;
    format!("{}{}", "★".repeat(n), "☆".repeat(5 - n))
}

fn request(url: &str, accept: &str) -> RequestBuilder<WithoutBody> {
    let req = ureq::get(url)
        .header("User-Agent", "repostation")
        .header("Accept", accept)
        .header("X-GitHub-Api-Version", "2022-11-28");
    match std::env::var("GITHUB_TOKEN") {
        Ok(token) if !token.is_empty() => req.header("Authorization", format!("Bearer {token}")),
        _ => req,
    }
}

fn call(req: RequestBuilder<WithoutBody>) -> Result<Response<Body>> {
    req.call().map_err(|e| match e {
        ureq::Error::StatusCode(403 | 429) => "GitHub rate limit reached; wait a minute or set GITHUB_TOKEN".into(),
        ureq::Error::StatusCode(404) => "not found on GitHub".into(),
        e => e.into(),
    })
}

/// Search repositories. `by_stars` sorts by popularity instead of relevance.
pub fn search(query: &str, by_stars: bool) -> Result<Vec<Repo>> {
    let mut req = request("https://api.github.com/search/repositories", "application/vnd.github+json")
        .query("q", format!("{query} archived:false"))
        .query("per_page", "50");
    if by_stars {
        req = req.query("sort", "stars");
    }
    Ok(call(req)?.body_mut().read_json::<SearchPage>()?.items)
}

/// Raw README text of `owner/repo`.
pub fn readme(full_name: &str) -> Result<String> {
    let url = format!("https://api.github.com/repos/{full_name}/readme");
    Ok(call(request(&url, "application/vnd.github.raw"))?.body_mut().read_to_string()?)
}
