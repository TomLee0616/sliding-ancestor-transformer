本目录用于放置 6 张阶段代表图，供 RIFE 插值生成 241 帧进化视频。

命名规范（必须）：
  stage-0.png  →  小难宁
  stage-1.png  →  牢宁
  stage-2.png  →  宁子
  stage-3.png  →  宁圣
  stage-4.png  →  宁神
  stage-5.png  →  宁祖（建议戴皇冠 / 最威严的形态）

要求：
  - 格式：PNG
  - 尺寸：推荐 800x800（脚本会自动裁剪到 800x800，比例不对会居中裁切）
  - 6 张图主体位置尽量一致（正脸、居中），否则插值过渡会有形变抖动

流程：
  1. 把 6 张图按上面的命名放进本目录
  2. 运行 bash scripts/video/build-keyframes.sh   （6 张 → 31 张关键帧）
  3. 运行 bash scripts/video/build-full-video.sh   （31 张 → 241 帧视频）

如果想先快速验证 RIFE 效果，可以只放好图后运行：
  bash scripts/video/build-prototype.sh
它会在 output/video-prototype/ 生成首尾两段的 49 帧预览 MP4。

注意：请确认你拥有相关肖像与素材的使用权后再使用。
