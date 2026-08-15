//! Cloudflare DNS 自动更新模块
//! 从 CFnat 优选 IP 自动更新 Cloudflare DNS 记录
//! 仅在 web feature 下可用（需要 reqwest）

use std::sync::Arc;
use std::time::Duration;

use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use tokio::sync::watch;

use crate::log::push_log;

/// DNS 更新器配置
#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct DnsUpdaterConfig {
    /// Cloudflare API Token
    pub cf_api_token: String,
    /// Zone 名称，如 "example.com"
    pub zone_name: String,
    /// DNS 记录名称，如 "cf.example.com"
    pub record_name: String,
    /// 更新间隔（秒）
    pub interval_secs: u64,
    /// 是否只使用单个 IP
    pub single_ip: bool,
    /// 是否更新 AAAA 记录
    pub update_aaaa: bool,
    /// 是否启用
    pub enabled: bool,
}

impl Default for DnsUpdaterConfig {
    fn default() -> Self {
        Self {
            cf_api_token: String::new(),
            zone_name: "example.com".to_string(),
            record_name: "cf.example.com".to_string(),
            interval_secs: 60,
            single_ip: true,
            update_aaaa: false,
            enabled: false,
        }
    }
}

/// DNS 更新器运行状态
#[derive(Clone, Serialize, Debug, Default)]
pub struct DnsUpdaterStatus {
    pub running: bool,
    pub last_update: Option<String>,
    pub last_a_record: Option<String>,
    pub last_aaaa_record: Option<String>,
    pub error: Option<String>,
}

/// DNS 更新器状态管理
pub struct DnsUpdaterState {
    pub config: RwLock<DnsUpdaterConfig>,
    pub status: RwLock<DnsUpdaterStatus>,
    cancel: RwLock<Option<watch::Sender<bool>>>,
}

impl DnsUpdaterState {
    pub fn new() -> Self {
        Self {
            config: RwLock::new(DnsUpdaterConfig::default()),
            status: RwLock::new(DnsUpdaterStatus::default()),
            cancel: RwLock::new(None),
        }
    }

    pub fn update_config(&self, new_config: DnsUpdaterConfig) {
        *self.config.write() = new_config;
    }

    pub fn get_config(&self) -> DnsUpdaterConfig {
        self.config.read().clone()
    }

    pub fn get_status(&self) -> DnsUpdaterStatus {
        self.status.read().clone()
    }
}

/// 启动 DNS 更新器后台任务
pub fn start_dns_updater(
    dns_state: Arc<DnsUpdaterState>,
    get_primary_ips: Box<dyn Fn() -> Vec<crate::core::IpInfo> + Send + Sync>,
) -> Result<(), String> {
    let config = dns_state.config.read().clone();

    if config.cf_api_token.is_empty() {
        return Err("CF_API_TOKEN 未设置".to_string());
    }
    if config.zone_name.is_empty() || config.record_name.is_empty() {
        return Err("ZONE_NAME 和 RECORD_NAME 不能为空".to_string());
    }

    // 取消已有任务
    stop_dns_updater(&dns_state);

    let (tx, mut rx) = watch::channel(false);
    *dns_state.cancel.write() = Some(tx);
    dns_state.status.write().running = true;
    dns_state.status.write().error = None;

    tokio::spawn(async move {
        run_dns_updater_loop(dns_state, get_primary_ips, &mut rx).await;
    });

    Ok(())
}

/// 停止 DNS 更新器
pub fn stop_dns_updater(dns_state: &DnsUpdaterState) {
    if let Some(tx) = dns_state.cancel.write().take() {
        let _ = tx.send(true);
    }
    dns_state.status.write().running = false;
}

/// DNS 更新器主循环
async fn run_dns_updater_loop(
    state: Arc<DnsUpdaterState>,
    get_primary_ips: Box<dyn Fn() -> Vec<crate::core::IpInfo> + Send + Sync>,
    cancel: &mut watch::Receiver<bool>,
) {
    let cf_api_url = "https://api.cloudflare.com/client/v4";

    let config = state.get_config();
    let zone_id = match get_zone_id(cf_api_url, &config.cf_api_token, &config.zone_name).await {
        Some(id) => id,
        None => {
            push_log("ERROR", "[DNS] 无法获取 Zone ID，请检查 ZONE_NAME 和 API Token");
            state.status.write().running = false;
            state.status.write().error = Some("无法获取 Zone ID".to_string());
            return;
        }
    };

    push_log("INFO", &format!(
        "[DNS] 更新器启动 | Zone: {} ({}) | Record: {} | 间隔: {}s",
        config.zone_name, zone_id, config.record_name, config.interval_secs
    ));

    let mut last_a_ips: Vec<String> = Vec::new();
    let mut last_aaaa_ips: Vec<String> = Vec::new();

    loop {
        let interval = Duration::from_secs(state.get_config().interval_secs);
        if tokio::select! {
            _ = tokio::time::sleep(interval) => false,
            _ = cancel.changed() => true,
        } {
            break;
        }

        let cfg = state.get_config();
        if !cfg.enabled {
            continue;
        }

        let primary_ips = get_primary_ips();

        // ---- A 记录 (IPv4) ----
        let ipv4s: Vec<String> = primary_ips.iter()
            .filter(|ip| !ip.ip.contains(':'))
            .map(|ip| ip.ip.clone())
            .collect();

        if ipv4s != last_a_ips && !ipv4s.is_empty() {
            if let Some(ref target_ip) = ipv4s.first() {
                let rid = get_record_id(cf_api_url, &cfg.cf_api_token, &zone_id, &cfg.record_name, "A").await;
                if let Some(record_id) = rid {
                    let ok = update_dns_record(cf_api_url, &cfg.cf_api_token, &zone_id, &record_id, &cfg.record_name, "A", target_ip, 60).await;
                    if ok {
                        push_log("INFO", &format!("[DNS] A 记录更新: {} -> {}", cfg.record_name, target_ip));
                        state.status.write().last_a_record = Some(target_ip.clone());
                        state.status.write().last_update = Some(format_now());
                    }
                } else {
                    let ok = create_dns_record(cf_api_url, &cfg.cf_api_token, &zone_id, &cfg.record_name, "A", target_ip, 60).await;
                    if ok {
                        push_log("INFO", &format!("[DNS] A 记录创建: {} -> {}", cfg.record_name, target_ip));
                        state.status.write().last_a_record = Some(target_ip.clone());
                        state.status.write().last_update = Some(format_now());
                    }
                }
                last_a_ips = ipv4s;
            }
        }

        // ---- AAAA 记录 (IPv6) ----
        if cfg.update_aaaa {
            let ipv6s: Vec<String> = primary_ips.iter()
                .filter(|ip| ip.ip.contains(':'))
                .map(|ip| ip.ip.clone())
                .collect();

            if ipv6s != last_aaaa_ips && !ipv6s.is_empty() {
                if let Some(ref target_ip) = ipv6s.first() {
                    let rid = get_record_id(cf_api_url, &cfg.cf_api_token, &zone_id, &cfg.record_name, "AAAA").await;
                    if let Some(record_id) = rid {
                        let ok = update_dns_record(cf_api_url, &cfg.cf_api_token, &zone_id, &record_id, &cfg.record_name, "AAAA", target_ip, 60).await;
                        if ok {
                            push_log("INFO", &format!("[DNS] AAAA 记录更新: {} -> {}", cfg.record_name, target_ip));
                            state.status.write().last_aaaa_record = Some(target_ip.clone());
                            state.status.write().last_update = Some(format_now());
                        }
                    } else {
                        let ok = create_dns_record(cf_api_url, &cfg.cf_api_token, &zone_id, &cfg.record_name, "AAAA", target_ip, 60).await;
                        if ok {
                            push_log("INFO", &format!("[DNS] AAAA 记录创建: {} -> {}", cfg.record_name, target_ip));
                            state.status.write().last_aaaa_record = Some(target_ip.clone());
                            state.status.write().last_update = Some(format_now());
                        }
                    }
                    last_aaaa_ips = ipv6s;
                }
            }
        }
    }

    state.status.write().running = false;
    push_log("INFO", "[DNS] 更新器已停止");
}

// ============ Cloudflare API 辅助函数 ============

async fn get_zone_id(api_url: &str, token: &str, zone_name: &str) -> Option<String> {
    let client = reqwest::Client::new();
    let url = format!("{}/zones?name={}", api_url, zone_name);
    let resp = client.get(&url)
        .header("Authorization", format!("Bearer {}", token))
        .header("Content-Type", "application/json")
        .send().await.ok()?;

    if !resp.status().is_success() {
        return None;
    }

    let body: serde_json::Value = resp.json().await.ok()?;
    body.get("result")?.as_array()?.first()?.get("id")?.as_str().map(|s| s.to_string())
}

async fn get_record_id(api_url: &str, token: &str, zone_id: &str, record_name: &str, record_type: &str) -> Option<String> {
    let client = reqwest::Client::new();
    let url = format!("{}/zones/{}/dns_records?name={}&type={}", api_url, zone_id, record_name, record_type);
    let resp = client.get(&url)
        .header("Authorization", format!("Bearer {}", token))
        .header("Content-Type", "application/json")
        .send().await.ok()?;

    if !resp.status().is_success() {
        return None;
    }

    let body: serde_json::Value = resp.json().await.ok()?;
    body.get("result")?.as_array()?.first()?.get("id")?.as_str().map(|s| s.to_string())
}

async fn update_dns_record(api_url: &str, token: &str, zone_id: &str, record_id: &str, name: &str, rtype: &str, ip: &str, ttl: u64) -> bool {
    let client = reqwest::Client::new();
    let url = format!("{}/zones/{}/dns_records/{}", api_url, zone_id, record_id);
    let body = serde_json::json!({
        "type": rtype,
        "name": name,
        "content": ip,
        "ttl": ttl,
        "proxied": false
    });

    let resp = client.put(&url)
        .header("Authorization", format!("Bearer {}", token))
        .header("Content-Type", "application/json")
        .json(&body)
        .send().await;

    match resp {
        Ok(r) => r.json::<serde_json::Value>().await
            .ok()
            .and_then(|v| v.get("success").and_then(|s| s.as_bool()))
            .unwrap_or(false),
        Err(e) => {
            push_log("ERROR", &format!("[DNS] 更新记录失败: {}", e));
            false
        }
    }
}

async fn create_dns_record(api_url: &str, token: &str, zone_id: &str, name: &str, rtype: &str, ip: &str, ttl: u64) -> bool {
    let client = reqwest::Client::new();
    let url = format!("{}/zones/{}/dns_records", api_url, zone_id);
    let body = serde_json::json!({
        "type": rtype,
        "name": name,
        "content": ip,
        "ttl": ttl,
        "proxied": false
    });

    let resp = client.post(&url)
        .header("Authorization", format!("Bearer {}", token))
        .header("Content-Type", "application/json")
        .json(&body)
        .send().await;

    match resp {
        Ok(r) => r.json::<serde_json::Value>().await
            .ok()
            .and_then(|v| v.get("success").and_then(|s| s.as_bool()))
            .unwrap_or(false),
        Err(e) => {
            push_log("ERROR", &format!("[DNS] 创建记录失败: {}", e));
            false
        }
    }
}

/// 简单时间戳格式化
fn format_now() -> String {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default();
    let total_secs = now.as_secs();
    let h = (total_secs / 3600) % 24;
    let m = (total_secs % 3600) / 60;
    let s = total_secs % 60;
    format!("{:02}:{:02}:{:02}", h, m, s)
}
