pub mod backend;
pub mod cancel;
pub mod config;
pub mod dns_resolver;
#[cfg(feature = "web")]
pub mod dns_updater;
pub mod forward;
pub mod httping;
pub mod hyper;
pub mod ip;
pub mod loadbalancer;
pub mod pool;
pub mod service;
#[cfg(target_os = "linux")]
pub mod splice;
pub mod types;

pub use backend::Backend;
pub use cancel::CancellationToken;
pub use config::Config;
pub use dns_resolver::{resolve_domain, resolve_domains, looks_like_domain};
#[cfg(feature = "web")]
pub use dns_updater::{DnsUpdaterConfig, DnsUpdaterState, DnsUpdaterStatus, start_dns_updater, stop_dns_updater};
pub use forward::run_forward;
pub use httping::{run_continuous_httping, HttpingConfig};
pub use hyper::{build_hyper_client, parse_url};
pub use ip::IpPool;
pub use loadbalancer::LoadBalancer;
pub use pool::init_global_limiter;
pub use service::{ServiceConfig, ServiceState};
pub use types::{ConfigOverrides, IpInfo, StatusInfo};