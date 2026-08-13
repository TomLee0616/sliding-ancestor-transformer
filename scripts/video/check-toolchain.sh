#!/usr/bin/env bash
# 校验视频生成所需的工具链是否就绪。
# 被 build-*.sh 在开头调用，也可单独运行：bash scripts/video/check-toolchain.sh

set -euo pipefail

status=0

require() {
  local name="$1"
  local hint="$2"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "✗ 缺少命令：$name" >&2
    echo "  $hint" >&2
    status=1
  else
    echo "✓ $name：$(command -v "$name")"
  fi
}

require ffmpeg "请安装 FFmpeg，Windows 可用 winget install Gyan.FFmpeg 或下载 https://www.gyan.dev/ffmpeg/builds/"
require ffprobe "随 FFmpeg 一起提供"

if [[ -z "${RIFE_BIN:-}" ]]; then
  echo "✗ 未设置环境变量 RIFE_BIN" >&2
  echo "  请指向 rife-ncnn-vulkan 可执行文件，例如：" >&2
  echo '  export RIFE_BIN="/D/tools/rife-ncnn-vulkan-20220424/rife-ncnn-vulkan.exe"' >&2
  status=1
else
  if [[ -f "$RIFE_BIN" ]]; then
    echo "✓ RIFE_BIN：$RIFE_BIN"
  else
    echo "✗ RIFE_BIN 指向的文件不存在：$RIFE_BIN" >&2
    status=1
  fi
fi

exit $status
