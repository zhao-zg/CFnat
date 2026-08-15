use std::net::IpAddr;
use std::str::FromStr;
use tokio::net::lookup_host;

use crate::log::push_log;

/// 从域名解析出所有 IPv4 / IPv6 地址
/// 支持格式:
///   - "bestproxy.seesforge.workers.dev"  (域名)
///   - "bestproxy.seesforge.workers.dev:443" (域名:端口，端口会被忽略)
pub async fn resolve_domain(domain: &str) -> Vec<IpAddr> {
    // 去掉可能的端口部分
    let hostname = if domain.contains(':') {
        // 如果是 IPv6 地址如 [::1]:443，不应截断
        if domain.starts_with('[') {
            if let Some(end) = domain.find("]:") {
                &domain[1..end]
            } else {
                domain.trim_start_matches('[').trim_end_matches(']')
            }
        } else {
            domain.split(':').next().unwrap_or(domain)
        }
    } else {
        domain
    };

    // 如果本身已经是 IP，直接返回
    if let Ok(ip) = IpAddr::from_str(hostname) {
        return vec![ip];
    }

    // 通过 DNS 解析
    let lookup_target = format!("{}:0", hostname);
    match lookup_host(&lookup_target).await {
        Ok(addrs) => {
            let ips: Vec<IpAddr> = addrs.map(|sock| sock.ip()).collect();
            if ips.is_empty() {
                push_log("WARN", &format!("[DNS] 域名 {} 解析结果为空", hostname));
            } else {
                push_log("INFO", &format!("[DNS] 域名 {} → {} 个 IP", hostname, ips.len()));
            }
            ips
        }
        Err(e) => {
            push_log("WARN", &format!("[DNS] 域名 {} 解析失败: {}", hostname, e));
            vec![]
        }
    }
}

/// 从多个域名批量解析，去重
pub async fn resolve_domains(domains: &[String]) -> Vec<IpAddr> {
    let mut all_ips = Vec::new();
    let mut seen = std::collections::HashSet::new();

    for domain in domains {
        let domain_trimmed = domain.trim();
        if domain_trimmed.is_empty() {
            continue;
        }
        for ip in resolve_domain(domain_trimmed).await {
            if seen.insert(ip) {
                all_ips.push(ip);
            }
        }
    }

    all_ips
}

/// 判断一个字符串是否看起来像域名（而非 IP 或 CIDR）
pub fn looks_like_domain(s: &str) -> bool {
    let s = s.trim();
    // 已经是 IP 地址
    if IpAddr::from_str(s).is_ok() {
        return false;
    }
    // 已经是 CIDR
    if s.contains('/') {
        return false;
    }
    // 包含点且不含空白 -> 视为域名
    s.contains('.') && !s.contains(' ') && !s.contains('\t')
}
