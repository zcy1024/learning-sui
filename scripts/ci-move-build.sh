#!/usr/bin/env bash
# 在仓库内对每个含 Move.toml 的示例包执行 sui move build（需已安装 sui CLI）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 较新的 Sui CLI 在缺少 client 配置时会对若干子命令（含 move build）交互询问；
# CI 与无配置环境需先非交互生成默认 ~/.sui/sui_config/client.yaml（见官方文档 sui client -y）。
if [[ ! -f "${HOME}/.sui/sui_config/client.yaml" ]]; then
  echo "==> no Sui client config; running: sui client -y"
  sui client -y
fi

failed=0
while IFS= read -r toml; do
  dir="$(dirname "$toml")"
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::group::sui move build: $dir"
  else
    echo "==> sui move build: $dir"
  fi
  # GitHub workflow installs `sui@testnet`; default build env matches testnet.  Without `-e
  # testnet`, some Move.lock files that only pin mainnet can fail dependency resolution.
  sui_args=()
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    sui_args+=(-e testnet)
  fi
  if (cd "$dir" && sui move build "${sui_args[@]}"); then
    :
  else
    failed=1
  fi
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::endgroup::"
  fi
done < <(find "$ROOT/src" -name Move.toml | sort)

if [[ "$failed" -ne 0 ]]; then
  echo "one or more packages failed sui move build" >&2
  exit 1
fi
echo "all Move packages built OK"
