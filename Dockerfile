# ===== 多架构运行时镜像 =====
# 二进制由 GitHub Actions 通过 cargo-zigbuild 预编译
# 此 Dockerfile 只负责打包运行时环境
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl jq && rm -rf /var/lib/apt/lists/*

# TARGETARCH 由 Docker Buildx 自动注入 (amd64 或 arm64)
ARG TARGETARCH
COPY binaries/${TARGETARCH}/CFnat /usr/local/bin/
COPY docker/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/CFnat /usr/local/bin/entrypoint.sh

WORKDIR /app
EXPOSE 1234 8080
ENTRYPOINT ["entrypoint.sh"]
