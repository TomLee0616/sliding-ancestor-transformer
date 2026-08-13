#!/usr/bin/env bash
# 第一轮插值：6 张阶段代表图 → 31 张关键帧。
#
# 输入：public/frames/stage-0.png ~ stage-5.png （6 张）
# 输出：output/keyframes/frame-00.png ~ frame-30.png （31 张）
#
# 策略（逐段独立插值 + 逐段人脸对齐）：
#   对每对相邻阶段 (stage-i, stage-i+1)：
#   1. 用 align_pair.py 把 stage-i 临时对齐到 stage-i+1（消除主体缩放/位移差异）
#   2. RIFE -n 7 插值出 7 帧（首帧=对齐的 stage-i，末帧=stage-i+1，中间5帧为过渡）
#   3. 把这 7 帧贴到全局 level 序号上
#
#   关键：每段的第一帧用【原始源图】覆盖（不用对齐版），确保拖到整数等级时
#   显示的就是该阶段对应的原图。末帧自然成为下一段的首帧（也是原始源图）。
#
#   这样既保证阶段锚点准确（level 0/6/12/18/24/30 = 原图），
#   又让中间过渡帧经过对齐，无鬼影。
#
# 用法：
#   source scripts/env.sh
#   bash scripts/video/build-keyframes.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_DIR="$PROJECT_ROOT/public/frames"
OUTPUT_DIR="$PROJECT_ROOT/output/keyframes"
WORK_DIR="$(mktemp -d /tmp/ning-keyframes.XXXXXX)"
RIFE_MODEL="${RIFE_MODEL:-$(dirname "$RIFE_BIN")/rife-v4.6}"

trap 'rm -rf "$WORK_DIR"' EXIT

"$SCRIPT_DIR/check-toolchain.sh"

if [[ ! -f "$RIFE_MODEL/flownet.bin" || ! -f "$RIFE_MODEL/flownet.param" ]]; then
  echo "找不到 RIFE v4 模型：$RIFE_MODEL" >&2
  exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 校验 6 张源图齐全
for ((stage = 0; stage <= 5; stage += 1)); do
  if [[ ! -f "$SOURCE_DIR/$(printf 'stage-%d.png' "$stage")" ]]; then
    echo "缺少源图：$SOURCE_DIR/stage-$stage.png" >&2
    exit 1
  fi
done

# 把源图规整成 800x800，存到 WORK_DIR/src/00.png ~ 05.png（作为锚点帧的权威来源）
mkdir -p "$WORK_DIR/src"
for ((stage = 0; stage <= 5; stage += 1)); do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$SOURCE_DIR/$(printf 'stage-%d.png' "$stage")" \
    -vf "scale=800:800:force_original_aspect_ratio=increase,crop=800:800" \
    "$WORK_DIR/src/$(printf '%02d.png' "$stage")"
done

# 逐段插值
for ((stage = 0; stage < 5; stage += 1)); do
  next=$((stage + 1))
  seg_in="$WORK_DIR/seg-$stage-in"
  seg_out="$WORK_DIR/seg-$stage-out"
  mkdir -p "$seg_in" "$seg_out"

  # 人脸对齐：把 stage-a 对齐到 stage-b（若 python 可用）
  if command -v python >/dev/null 2>&1; then
    python "$PROJECT_ROOT/scripts/align_pair.py" "$SOURCE_DIR" "$seg_in" "$stage" "$next" \
      >/dev/null 2>&1 || {
        # 对齐失败则回退到规整后的原图
        cp "$WORK_DIR/src/$(printf '%02d.png' "$stage")" "$seg_in/00.png"
        cp "$WORK_DIR/src/$(printf '%02d.png' "$next")" "$seg_in/01.png"
      }
  else
    cp "$WORK_DIR/src/$(printf '%02d.png' "$stage")" "$seg_in/00.png"
    cp "$WORK_DIR/src/$(printf '%02d.png' "$next")" "$seg_in/01.png"
  fi

  # RIFE 插值：-n 7 输出 7 帧，首帧=stage-a(对齐)，末帧=stage-b
  (
    cd "$(dirname "$RIFE_BIN")"
    "$RIFE_BIN" -i "$seg_in" -o "$seg_out/" -n 7 -m "$RIFE_MODEL"
  ) >/dev/null

  # 写入全局 level 序号
  # 这段的 level 范围：stage*6 .. (stage+1)*6，共 7 个 level（含两端）
  base_level=$((stage * 6))
  for ((i = 1; i <= 7; i += 1)); do
    level=$((base_level + i - 1))
    rife_name="$(printf '%08d.png' "$i")"
    out_name="$(printf 'frame-%02d.png' "$level")"

    if [[ $i -eq 1 ]]; then
      # 首帧：用【原始源图】覆盖，确保阶段锚点准确
      cp "$WORK_DIR/src/$(printf '%02d.png' "$stage")" "$OUTPUT_DIR/$out_name"
    elif [[ $i -eq 7 && $stage -eq 4 ]]; then
      # 最后一段的末帧（level 30）：用原始 stage-5 源图
      cp "$WORK_DIR/src/05.png" "$OUTPUT_DIR/$out_name"
    else
      # 中间过渡帧：用 RIFE 插值结果
      cp "$seg_out/$rife_name" "$OUTPUT_DIR/$out_name"
    fi
  done

  echo "段 stage-$stage → stage-$next 完成（level $base_level ~ $((base_level + 6))）"
done

echo "已生成 31 张关键帧到 $OUTPUT_DIR"
echo "（frame-00.png ~ frame-30.png，阶段锚点 frame-00/06/12/18/24/30 = 原始源图）"
