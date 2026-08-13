#!/usr/bin/env bash
# 第二轮插值：31 张关键帧 → 241 帧连续视频（webm + mp4）。
#
# 前置：先运行 build-keyframes.sh 生成 output/keyframes/frame-00.png ~ frame-30.png
# 输出：public/video/ning-evolution.webm 和 ning-evolution.mp4
#
# 策略：31 张关键帧作为整体喂给 RIFE，-n 241，输出 241 帧均匀序列。
#
# 用法：
#   source scripts/env.sh
#   bash scripts/video/build-full-video.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KEYFRAME_DIR="$PROJECT_ROOT/output/keyframes"
OUTPUT_DIR="$PROJECT_ROOT/public/video"
WORK_DIR="$(mktemp -d /tmp/ning-full-video.XXXXXX)"
RIFE_MODEL="${RIFE_MODEL:-$(dirname "$RIFE_BIN")/rife-v4.6}"

trap 'rm -rf "$WORK_DIR"' EXIT

"$SCRIPT_DIR/check-toolchain.sh"

if [[ ! -f "$RIFE_MODEL/flownet.bin" || ! -f "$RIFE_MODEL/flownet.param" ]]; then
  echo "找不到 RIFE v4 模型：$RIFE_MODEL" >&2
  exit 1
fi

if [[ ! -d "$KEYFRAME_DIR" ]]; then
  echo "未找到关键帧目录：$KEYFRAME_DIR" >&2
  echo "请先运行：bash scripts/video/build-keyframes.sh" >&2
  exit 1
fi

expected_keyframes=31
actual_keyframes="$(find "$KEYFRAME_DIR" -maxdepth 1 -type f -name 'frame-*.png' | wc -l | tr -d ' ')"
if [[ "$actual_keyframes" -ne "$expected_keyframes" ]]; then
  echo "关键帧数量不对：期望 $expected_keyframes，实际 $actual_keyframes" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR" "$WORK_DIR/input" "$WORK_DIR/interpolated"

# 关键帧按顺序复制到统一输入目录
for ((level = 0; level < 30; level += 1)); do
  cp "$KEYFRAME_DIR/$(printf 'frame-%02d.png' "$level")" \
     "$WORK_DIR/input/$(printf '%03d.png' "$level")"
done

# 31 张关键帧，目标 241 帧
# 注意：RIFE 的 -o 必须以路径分隔符结尾，否则会报 "invalid outputpath extension type"
(
  cd "$(dirname "$RIFE_BIN")"
  "$RIFE_BIN" \
    -i "$WORK_DIR/input" \
    -o "$WORK_DIR/interpolated/" \
    -n 241 \
    -m "$RIFE_MODEL"
) >/dev/null

frame_count="$(find "$WORK_DIR/interpolated" -type f -name '*.png' | wc -l | tr -d ' ')"
if [[ "$frame_count" != "241" ]]; then
  echo "插值帧数不对：期望 241，实际 $frame_count" >&2
  exit 1
fi

# Windows 版 FFmpeg 不支持 -pattern_type glob，用数字序列 pattern。
# RIFE 输出文件名为 00000001.png ~ 00000241.png，从 1 开始连续。
# WebM (VP9)
ffmpeg -hide_banner -loglevel error -y \
  -framerate 30 -start_number 1 -i "$WORK_DIR/interpolated/%08d.png" \
  -c:v libvpx-vp9 -crf 28 -b:v 0 -row-mt 1 -cpu-used 2 \
  -g 4 -pix_fmt yuv420p \
  "$OUTPUT_DIR/ning-evolution.webm"

# MP4 (H.264)，关键帧密集以便帧级 seek
ffmpeg -hide_banner -loglevel error -y \
  -framerate 30 -start_number 1 -i "$WORK_DIR/interpolated/%08d.png" \
  -c:v libx264 -preset medium -crf 18 \
  -g 4 -keyint_min 1 -sc_threshold 0 \
  -pix_fmt yuv420p -movflags +faststart \
  "$OUTPUT_DIR/ning-evolution.mp4"

for video in "$OUTPUT_DIR"/ning-evolution.webm "$OUTPUT_DIR"/ning-evolution.mp4; do
  echo "已生成：$video"
  ffprobe -v error -count_frames -select_streams v:0 \
    -show_entries stream=width,height,r_frame_rate,nb_read_frames:format=duration \
    -of default=noprint_wrappers=1 "$video"
done
