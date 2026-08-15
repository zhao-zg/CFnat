# ===== 阶段1: 构建 =====
FROM rust:1.87-bookworm AS builder
WORKDIR /app

# 先复制依赖文件，利用 Docker 缓存加速增量构建
COPY Cargo.toml Cargo.lock* ./
COPY src/ ./src/
COPY .cargo/ .cargo/

# 构建 CFnat 二进制（启用 web feature）
RUN cargo build --release --bin CFnat --features web

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
