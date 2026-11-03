//! One sampler feeds both the TUI and the `--json` stream (which the divine-shell GUI reads).
//! GPUs: NVIDIA through NVML (loaded at runtime, so no driver needed to start), AMD through
//! amdgpu's sysfs files. Intel iGPUs expose no busy counter in sysfs and show as absent.

use nvml_wrapper::Nvml;
use nvml_wrapper::enum_wrappers::device::TemperatureSensor;
use serde::Serialize;
use std::fs;
use std::path::Path;
use std::time::Instant;
use sysinfo::{Components, Networks, Pid, ProcessRefreshKind, ProcessesToUpdate, Signal, System, UpdateKind, Users};

#[derive(Debug, Clone, Default, Serialize)]
pub struct Snapshot {
    pub host: String,
    pub uptime: u64,
    pub load: [f64; 3],
    pub cpu: f32,
    pub cores: Vec<f32>,
    pub cpu_temp: Option<f32>,
    pub mem_used: u64,
    pub mem_total: u64,
    pub swap_used: u64,
    pub swap_total: u64,
    pub gpu: Option<Gpu>,
    /// bytes per second, all interfaces
    pub net_rx: u64,
    pub net_tx: u64,
    pub temps: Vec<Temp>,
    pub procs: Vec<Proc>,
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct Gpu {
    pub name: String,
    pub util: f32,
    pub vram_used: u64,
    pub vram_total: u64,
    pub temp: Option<f32>,
    pub power_w: Option<f32>,
}

#[derive(Debug, Clone, Serialize)]
pub struct Temp {
    pub label: String,
    pub celsius: f32,
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct Proc {
    pub pid: u32,
    pub name: String,
    pub user: String,
    /// percent of one core, like top
    pub cpu: f32,
    pub mem: u64,
    pub cmd: String,
}

/// Sensor labels that mean "the CPU package", most specific first.
const CPU_SENSORS: &[&str] = &["Package id 0", "Tctl", "Tdie", "k10temp", "coretemp", "cpu"];

/// Sensors, interfaces and users are optional: a system that can't list them still gets
/// CPU, memory and processes.
pub struct Sampler {
    sys: System,
    components: Option<Components>,
    networks: Option<Networks>,
    users: Option<Users>,
    nvml: Option<Nvml>,
    last: Instant,
}

impl Sampler {
    pub fn new() -> Result<Sampler, sysinfo::Error> {
        let mut s = Sampler {
            sys: System::new()?,
            components: Components::new_with_refreshed_list().ok(),
            networks: Networks::new_with_refreshed_list().ok(),
            users: Users::new_with_refreshed_list().ok(),
            nvml: Nvml::init().ok(),
            last: Instant::now(),
        };
        s.refresh(); // CPU and network figures are deltas: prime them
        Ok(s)
    }

    fn refresh(&mut self) {
        self.sys.refresh_cpu_usage();
        self.sys.refresh_memory();
        let kind = ProcessRefreshKind::nothing()
            .with_cpu()
            .with_memory()
            .with_user(UpdateKind::OnlyIfNotSet)
            .with_cmd(UpdateKind::OnlyIfNotSet);
        self.sys.refresh_processes_specifics(ProcessesToUpdate::All, true, kind);
        if let Some(c) = &mut self.components {
            c.refresh(true);
        }
        if let Some(n) = &mut self.networks {
            n.refresh(true);
        }
        self.last = Instant::now();
    }

    pub fn sample(&mut self) -> Snapshot {
        let secs = self.last.elapsed().as_secs_f64().max(0.001);
        self.refresh();

        let temps: Vec<Temp> = self
            .components
            .iter()
            .flat_map(|list| list.iter())
            .filter_map(|c| Some(Temp { label: c.label().to_string(), celsius: c.temperature()? }))
            .filter(|t| t.celsius > 0.0)
            .collect();
        let cpu_temp = CPU_SENSORS
            .iter()
            .find_map(|want| temps.iter().find(|t| t.label.to_lowercase().contains(&want.to_lowercase())))
            .map(|t| t.celsius);

        let (rx, tx) = self.networks.iter().flat_map(|list| list.iter()).fold((0, 0), |(rx, tx), (_, n)| (rx + n.received(), tx + n.transmitted()));

        let procs = self
            .sys
            .processes()
            .values()
            .map(|p| Proc {
                pid: p.pid().as_u32(),
                name: p.name().to_string_lossy().into_owned(),
                user: p.user_id().and_then(|u| self.users.as_ref()?.get_user_by_id(u)).map(|u| u.name().to_string()).unwrap_or_default(),
                cpu: p.cpu_usage(),
                mem: p.memory(),
                cmd: p.cmd().iter().map(|a| a.to_string_lossy()).collect::<Vec<_>>().join(" "),
            })
            .collect();

        Snapshot {
            host: System::host_name().unwrap_or_default(),
            uptime: System::uptime().unwrap_or(0),
            load: System::load_average().map_or([0.0; 3], |l| [l.one, l.five, l.fifteen]),
            cpu: self.sys.global_cpu_usage(),
            cores: self.sys.cpus().iter().map(|c| c.usage()).collect(),
            cpu_temp,
            mem_used: self.sys.used_memory(),
            mem_total: self.sys.total_memory(),
            swap_used: self.sys.used_swap(),
            swap_total: self.sys.total_swap(),
            gpu: self.nvidia().or_else(amd),
            net_rx: (rx as f64 / secs) as u64,
            net_tx: (tx as f64 / secs) as u64,
            temps,
            procs,
        }
    }

    /// SIGTERM, or SIGKILL when `force`. False when the process is gone or isn't ours.
    pub fn kill(&self, pid: u32, force: bool) -> bool {
        let signal = if force { Signal::Kill } else { Signal::Term };
        self.sys.process(Pid::from_u32(pid)).and_then(|p| p.kill_with(signal)).unwrap_or(false)
    }

    fn nvidia(&self) -> Option<Gpu> {
        let dev = self.nvml.as_ref()?.device_by_index(0).ok()?;
        let mem = dev.memory_info().ok()?;
        Some(Gpu {
            name: dev.name().unwrap_or_else(|_| "NVIDIA GPU".into()),
            util: dev.utilization_rates().map_or(0.0, |u| u.gpu as f32),
            vram_used: mem.used,
            vram_total: mem.total,
            temp: dev.temperature(TemperatureSensor::Gpu).ok().map(|t| t as f32),
            power_w: dev.power_usage().ok().map(|mw| mw as f32 / 1000.0),
        })
    }
}

fn read_num(path: &Path) -> Option<f64> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

/// First amdgpu card, from /sys/class/drm/cardN/device.
fn amd() -> Option<Gpu> {
    let dev = fs::read_dir("/sys/class/drm").ok()?.flatten().map(|e| e.path().join("device")).find(|d| d.join("gpu_busy_percent").exists())?;
    let hwmon = fs::read_dir(dev.join("hwmon")).ok().and_then(|mut d| d.next()).and_then(|e| e.ok()).map(|e| e.path());
    let sensor = |file: &str, scale: f64| hwmon.as_ref().and_then(|h| read_num(&h.join(file))).map(|v| (v / scale) as f32);
    Some(Gpu {
        name: fs::read_to_string(dev.join("product_name")).map(|s| s.trim().to_string()).unwrap_or_else(|_| "AMD GPU".into()),
        util: read_num(&dev.join("gpu_busy_percent"))? as f32,
        vram_used: read_num(&dev.join("mem_info_vram_used")).unwrap_or(0.0) as u64,
        vram_total: read_num(&dev.join("mem_info_vram_total")).unwrap_or(0.0) as u64,
        temp: sensor("temp1_input", 1000.0),
        power_w: sensor("power1_average", 1e6).or_else(|| sensor("power1_input", 1e6)),
    })
}

/// 5_368_709_120 → "5.0G"
pub fn fmt_bytes(b: u64) -> String {
    const UNITS: [&str; 5] = ["B", "K", "M", "G", "T"];
    let mut v = b as f64;
    let mut i = 0;
    while v >= 1024.0 && i < UNITS.len() - 1 {
        v /= 1024.0;
        i += 1;
    }
    if i == 0 { format!("{b}B") } else { format!("{v:.1}{}", UNITS[i]) }
}

/// 11_520 → "3h 12m"
pub fn fmt_uptime(secs: u64) -> String {
    let (d, h, m) = (secs / 86_400, secs / 3_600 % 24, secs / 60 % 60);
    if d > 0 { format!("{d}d {h}h") } else { format!("{h}h {m}m") }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn samples_this_machine() {
        let mut s = Sampler::new().unwrap();
        std::thread::sleep(sysinfo::MINIMUM_CPU_UPDATE_INTERVAL);
        let snap = s.sample();
        assert!(!snap.cores.is_empty());
        assert!(snap.mem_total > 0 && snap.mem_used <= snap.mem_total);
        assert!((0.0..=100.0).contains(&snap.cpu));
        assert!(snap.procs.iter().any(|p| p.pid == std::process::id()));
        let json = serde_json::to_string(&snap).unwrap();
        assert!(json.contains("\"mem_total\""));
    }

    #[test]
    fn formats_units() {
        assert_eq!(fmt_bytes(512), "512B");
        assert_eq!(fmt_bytes(5 * 1024 * 1024 * 1024), "5.0G");
        assert_eq!(fmt_uptime(11_520), "3h 12m");
        assert_eq!(fmt_uptime(200_000), "2d 7h");
    }
}
