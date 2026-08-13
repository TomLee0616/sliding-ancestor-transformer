#!/usr/bin/env bash
# 工具链环境变量便捷脚本。
# 用法（在跑视频脚本前 source 一次）：
#   source scripts/env.sh
# 之后再运行：
#   bash scripts/video/build-keyframes.sh
#   bash scripts/video/build-full-video.sh

# 把 winget 装的 FFmpeg 加入 PATH（本次会话生效）
FFMPEG_BIN_DIR="/c/Users/admin/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-9.0-full_build/bin"
if [[ -d "$FFMPEG_BIN_DIR" ]]; then
  case ":$PATH:" in
    *":$FFMPEG_BIN_DIR:"*) ;;
    *) export PATH="$FFMPEG_BIN_DIR:$PATH" ;;
  esac
fi

# RIFE 可执行程序与模型（放在项目内的 tools/ 目录，路径稳定）
export RIFE_BIN="/d/Ztest/tools/rife-ncnn-vulkan-20221029-windows/rife-ncnn-vulkan.exe"
export RIFE_MODEL="/d/Ztest/tools/rife-ncnn-vulkan-20221029-windows/rife-v4.6"

echo "✓ FFmpeg:  $(command -v ffmpeg || echo '未找到')"
echo "✓ ffprobe: $(command -v ffprobe || echo '未找到')"
echo "✓ RIFE_BIN:   $RIFE_BIN"
echo "✓ RIFE_MODEL: $RIFE_MODEL"
