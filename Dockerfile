# ===== 阶段1: 构建 =====
FROM rust:1-bookworm AS builder
WORKDIR /app

# Docker 构建环境：降低 LTO 避免交叉编译 OOM，移除 CI 专用 remap-path-prefix
COPY .cargo/ .cargo/
RUN sed -i 's/lto = "fat"/lto = "thin"/' .cargo/config.toml \
    && sed -i '/remap-path-prefix/d' .cargo/config.toml

# 复制全部源码
COPY . .

# 编译 release 版本
RUN cargo build --release --bin CFnat --features web 2>&1

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
