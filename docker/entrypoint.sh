#!/usr/bin/env bash
# CFnat Docker 入口脚本
# 从环境变量构建命令行参数，支持所有配置项

set -euo pipefail

ARGS=()

# 必选: IP 文件
IP_FILE="${IP_FILE:-/app/ip.txt}"
ARGS+=("-f" "$IP_FILE")

# 必选: API 监听地址
API_ADDR="${API_ADDR:-0.0.0.0:8080}"
ARGS+=("-api" "$API_ADDR")

# 可选: 转发监听地址
if [[ -n "${ADDR:-}" ]]; then
    ARGS+=("-addr" "$ADDR")
fi

# 可选: 延迟上限
if [[ -n "${DELAY_LIMIT:-}" ]]; then
    ARGS+=("-dl" "$DELAY_LIMIT")
fi

# 可选: 丢包率上限
if [[ -n "${TLR:-}" ]]; then
    ARGS+=("-tlr" "$TLR")
fi

# 可选: 测速并发数
if [[ -n "${THREADS:-}" ]]; then
    ARGS+=("-n" "$THREADS")
fi

# 可选: 负载数量
if [[ -n "${IPS:-}" ]]; then
    ARGS+=("-ips" "$IPS")
fi

# 可选: TLS 端口
if [[ -n "${TLS_PORT:-}" ]]; then
    ARGS+=("-tp" "$TLS_PORT")
fi

# 可选: HTTP 端口
if [[ -n "${HTTP_PORT:-}" ]]; then
    ARGS+=("-p" "$HTTP_PORT")
fi

# 可选: 测速地址
if [[ -n "${HTTP:-}" ]]; then
    ARGS+=("-http" "$HTTP")
fi

# 可选: 数据中心筛选
if [[ -n "${COLO:-}" ]]; then
    ARGS+=("-colo" "$COLO")
fi

# 可选: 最大负载槽数
if [[ -n "${MAX_STICKY_SLOTS:-}" ]]; then
    ARGS+=("-s" "$MAX_STICKY_SLOTS")
fi

# 自定义 IP（逗号分隔）
if [[ -n "${CUSTOM_IPS:-}" ]]; then
    ARGS+=("-ip" "$CUSTOM_IPS")
fi

# 优选域名（逗号分隔）
if [[ -n "${DOMAINS:-}" ]]; then
    ARGS+=("-domain" "$DOMAINS")
fi

echo "启动 CFnat: CFnat ${ARGS[*]}"
exec CFnat "${ARGS[@]}"
