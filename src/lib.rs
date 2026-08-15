pub mod args;
pub mod log;

#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;

#[cfg(feature = "web")]
pub mod api;
pub mod core;

#[cfg(feature = "web")]
pub use api::{create_router, AppState};
pub use args::Args;
pub use core::{
    Backend, Config, HttpingConfig, IpPool, LoadBalancer,
    ServiceConfig, ServiceState,
    build_hyper_client, init_global_limiter, parse_url, run_continuous_httping, run_forward,
    resolve_domain, resolve_domains, looks_like_domain,
};
#[cfg(feature = "web")]
pub use core::{DnsUpdaterConfig, DnsUpdaterState, DnsUpdaterStatus, start_dns_updater, stop_dns_updater};
pub use log::{get_log_buffer, push_log, reset_start_time, LogBuffer, LogEntry};