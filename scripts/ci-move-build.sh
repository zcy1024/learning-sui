#!/usr/bin/env bash
# 在仓库内对每个含 Move.toml 的示例包执行 sui move build（需已安装 sui CLI）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 较新的 Sui CLI 在缺少 client 配置时会对若干子命令（含 move build）交互询问。
# `-y` 必须配合子命令才会创建配置；单独 `sui client -y` 只会打印 help。这里用 `envs`
# 触发初始化（与官方文档「sui client -y」意图一致，见 `sui client --help`）。
if [[ ! -f "${HOME}/.sui/sui_config/client.yaml" ]]; then
  echo "==> no Sui client config; running: sui client -y envs"
  sui client -y envs
fi

failed=0
while IFS= read -r toml; do
  dir="$(dirname "$toml")"
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::group::sui move build: $dir"
  else
    echo "==> sui move build: $dir"
  fi
  # 与 CI 一致使用 testnet 环境解析依赖（部分 Move.lock 仅含 testnet pin）；且避免在
  # `set -u` 下展开空数组 `"${sui_args[@]}"`（macOS 默认 bash 3.2 等会报错）。
  if (cd "$dir" && sui move build -e testnet); then
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
