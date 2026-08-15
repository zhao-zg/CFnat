# ===== 阶段1: 构建 =====
FROM rust:1.87-bookworm AS builder
WORKDIR /app

# 复制所有源码
COPY . .

# Docker 构建环境不需要 CI 的 remap-path-prefix，覆盖 cargo 配置
RUN sed -i '/remap-path-prefix/d' .cargo/config.toml

# 生成 lockfile 并构建 CFnat 二进制（启用 web feature）
RUN cargo generate-lockfile 2>/dev/null; \
    cargo build --release --bin CFnat --features web

# ===== 阶段2: 运行时 =====
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl jq && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/CFnat /usr/local/bin/
COPY docker/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/CFnat /usr/local/bin/entrypoint.sh

WORKDIR /app
EXPOSE 1234 8080
ENTRYPOINT ["entrypoint.sh"]
