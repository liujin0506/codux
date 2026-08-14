#!/usr/bin/env bash
# Mirrors .github/workflows/release-agent.yml "Build Linux agent on Debian 10 baseline".
set -euo pipefail

: "${CARGO_BUILD_TARGET:?CARGO_BUILD_TARGET is required}"
: "${LINUX_DOCKER_PLATFORM:?LINUX_DOCKER_PLATFORM is required}"

docker run --rm \
  --platform "${LINUX_DOCKER_PLATFORM}" \
  -v "$PWD:/workspace" \
  -w /workspace \
  -e CARGO_BUILD_TARGET="${CARGO_BUILD_TARGET}" \
  -e CARGO_HOME=/workspace/target/linux-release-cargo-home \
  debian:10 \
  bash -lc '
    set -euo pipefail
    if ! apt-get update; then
      sed -i \
        -e "s|deb.debian.org/debian|archive.debian.org/debian|g" \
        -e "s|security.debian.org/debian-security|archive.debian.org/debian-security|g" \
        /etc/apt/sources.list
      printf "Acquire::Check-Valid-Until \"false\";\n" >/etc/apt/apt.conf.d/99no-check-valid
      apt-get update
    fi
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl git build-essential cmake pkg-config perl python3 file
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
    . "$CARGO_HOME/env"
    rustup target add "$CARGO_BUILD_TARGET"
    cargo build -p codux-agent --release --target "$CARGO_BUILD_TARGET"
  '
