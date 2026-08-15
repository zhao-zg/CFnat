use axum::{
    extract::State,
    Json,
};

use super::{AppState, ApiResponse, StartRequest, StatusResponse, DnsUpdaterRequest};
use crate::core::{ServiceConfig, types::ConfigOverrides};
#[cfg(feature = "web")]
use crate::core::dns_updater::DnsUpdaterConfig;
use crate::log::get_log_buffer;

pub async fn get_status(State(state): State<AppState>) -> Json<StatusResponse> {
    let info = state.service.build_full_status();
    Json(StatusResponse::from(info))
}

pub async fn get_config(State(state): State<AppState>) -> Json<ServiceConfig> {
    Json(state.service.get_config())
}

pub async fn start_service(
    State(state): State<AppState>,
    Json(req): Json<StartRequest>,
) -> Json<ApiResponse> {
    let mut config = state.service.get_config();

    config.apply_overrides(&ConfigOverrides::from(&req));

    state.service.update_config(config);

    let result = state.service.start_with_sources(
        req.ip_file.as_deref(),
        req.ip_content.as_deref(),
        req.custom_ips.as_deref(),
        req.domains.as_deref(),
    ).await;

    match result {
        Ok(_) => Json(ApiResponse {
            success: true,
            message: "服务已启动".to_string(),
        }),
        Err(e) => Json(ApiResponse {
            success: false,
            message: e,
        }),
    }
}

pub async fn stop_service(State(state): State<AppState>) -> Json<ApiResponse> {
    match state.service.stop().await {
        Ok(_) => Json(ApiResponse {
            success: true,
            message: "服务已停止".to_string(),
        }),
        Err(e) => Json(ApiResponse {
            success: false,
            message: e,
        }),
    }
}

pub async fn health_check() -> Json<ApiResponse> {
    Json(ApiResponse {
        success: true,
        message: "服务运行正常".to_string(),
    })
}

pub async fn get_logs() -> Json<Vec<crate::log::LogEntry>> {
    Json(get_log_buffer().get_all())
}

pub async fn clear_logs() -> Json<ApiResponse> {
    get_log_buffer().clear();
    Json(ApiResponse {
        success: true,
        message: "日志已清空".to_string(),
    })
}

// ============ DNS 更新器 API ============

/// 获取 DNS 更新器配置
#[cfg(feature = "web")]
pub async fn get_dns_config(State(state): State<AppState>) -> Json<DnsUpdaterConfig> {
    Json(state.service.dns_updater.get_config())
}

/// 更新 DNS 更新器配置
#[cfg(feature = "web")]
pub async fn update_dns_config(
    State(state): State<AppState>,
    Json(req): Json<DnsUpdaterRequest>,
) -> Json<ApiResponse> {
    let config = DnsUpdaterConfig {
        cf_api_token: req.cf_api_token,
        zone_name: req.zone_name,
        record_name: req.record_name,
        interval_secs: req.interval_secs,
        single_ip: req.single_ip,
        update_aaaa: req.update_aaaa,
        enabled: req.enabled,
    };

    state.service.dns_updater.update_config(config);

    // 如果配置了启用，且主服务在运行，自动启动 DNS 更新器
    if config.enabled && !config.cf_api_token.is_empty() && state.service.is_running() {
        let dns_state = state.service.dns_updater.clone();
        let get_ips = {
            let lb = state.service.loadbalancer.clone();
            Box::new(move || {
                if let Some(lb) = lb.read().as_ref() {
                    lb.get_primary_backends()
                        .iter()
                        .map(|b| crate::core::IpInfo::from_backend(b))
                        .collect()
                } else {
                    vec![]
                }
            }) as Box<dyn Fn() -> Vec<crate::core::IpInfo> + Send + Sync>
        };

        match crate::core::start_dns_updater(dns_state, get_ips) {
            Ok(_) => return Json(ApiResponse { success: true, message: "DNS 更新器已启动".to_string() }),
            Err(e) => return Json(ApiResponse { success: false, message: e }),
        }
    }

    // 如果禁用，停止 DNS 更新器
    if !config.enabled {
        crate::core::stop_dns_updater(&state.service.dns_updater);
        return Json(ApiResponse { success: true, message: "DNS 更新器已停止".to_string() });
    }

    Json(ApiResponse { success: true, message: "配置已保存".to_string() })
}

/// 获取 DNS 更新器状态
#[cfg(feature = "web")]
pub async fn get_dns_status(State(state): State<AppState>) -> Json<crate::core::DnsUpdaterStatus> {
    Json(state.service.dns_updater.get_status())
}