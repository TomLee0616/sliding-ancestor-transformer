#!/usr/bin/env bash
# 原型预览：用首尾两段代表图快速生成 49 帧预览 MP4，验证 RIFE 效果。
# 不会写入 public/，仅输出到 output/video-prototype/ 供肉眼检查。
#
# 用法：
#   bash scripts/video/build-prototype.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_DIR="$PROJECT_ROOT/public/frames"
OUTPUT_DIR="$PROJECT_ROOT/output/video-prototype"
WORK_DIR="$(mktemp -d /tmp/ning-prototype.XXXXXX)"
RIFE_MODEL="${RIFE_MODEL:-$(dirname "$RIFE_BIN")/rife-v4.6}"

trap 'rm -rf "$WORK_DIR"' EXIT

"$SCRIPT_DIR/check-toolchain.sh"

if [[ ! -f "$RIFE_MODEL/flownet.bin" || ! -f "$RIFE_MODEL/flownet.param" ]]; then
  echo "找不到 RIFE v4 模型：$RIFE_MODEL" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

prepare_segment() {
  local stage_a="$1"
  local stage_b="$2"
  local target_dir="$3"
  mkdir -p "$target_dir"

  local a_name b_name
  a_name="$(printf 'stage-%d.png' "$stage_a")"
  b_name="$(printf 'stage-%d.png' "$stage_b")"

  if [[ ! -f "$SOURCE_DIR/$a_name" || ! -f "$SOURCE_DIR/$b_name" ]]; then
    echo "缺少源图：$a_name 或 $b_name" >&2
    exit 1
  fi

  ffmpeg -hide_banner -loglevel error -y \
    -i "$SOURCE_DIR/$a_name" \
    -vf "scale=800:800:force_original_aspect_ratio=increase,crop=800:800" \
    "$target_dir/00.png"
  ffmpeg -hide_banner -loglevel error -y \
    -i "$SOURCE_DIR/$b_name" \
    -vf "scale=800:800:force_original_aspect_ratio=increase,crop=800:800" \
    "$target_dir/01.png"
}

interpolate_segment() {
  local input_dir="$1"
  local output_dir="$2"
  mkdir -p "$output_dir"
  # 注意：RIFE 的 -o 必须以路径分隔符结尾，否则会报 "invalid outputpath extension type"
  (
    cd "$(dirname "$RIFE_BIN")"
    "$RIFE_BIN" -i "$input_dir" -o "$output_dir/" -n 49 -m "$RIFE_MODEL"
  )
}

encode_segment() {
  local input_dir="$1"
  local output_file="$2"
  # Windows 版 FFmpeg 不支持 -pattern_type glob，用数字序列 pattern
  ffmpeg -hide_banner -loglevel error -y \
    -framerate 30 -start_number 1 -i "$input_dir/%08d.png" \
    -c:v libx264 -preset medium -crf 18 \
    -g 4 -keyint_min 1 -sc_threshold 0 \
    -pix_fmt yuv420p -movflags +faststart \
    "$output_file"
}

# 首段：stage 0 → stage 1
prepare_segment 0 1 "$WORK_DIR/early-input"
interpolate_segment "$WORK_DIR/early-input" "$WORK_DIR/early-output"
encode_segment "$WORK_DIR/early-output" "$OUTPUT_DIR/xiaonanning-to-laoning.mp4"

# 末段：stage 4 → stage 5
prepare_segment 4 5 "$WORK_DIR/final-input"
interpolate_segment "$WORK_DIR/final-input" "$WORK_DIR/final-output"
encode_segment "$WORK_DIR/final-output" "$OUTPUT_DIR/ningshen-to-ningzu.mp4"

for video in "$OUTPUT_DIR"/*.mp4; do
  echo "已生成：$video"
  ffprobe -v error -count_frames -select_streams v:0 \
    -show_entries stream=width,height,nb_read_frames \
    -of default=noprint_wrappers=1 "$video"
done
