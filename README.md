# 滑动变祖器（宁系强度校准器）

把一根滑杆变成「宁系强度校准器」的网页玩具。拖动滑杆（或用键盘），观察角色在 241 帧插值视频里连续进化，从「小难宁」一路变成戴皇冠的「宁祖」。

参考自 [Lichtspektrum/liang-intensity-calibrator](https://github.com/Lichtspektrum/liang-intensity-calibrator)，本项目把所有「梁」替换为「宁」，并改用 6 张阶段代表图 + 两轮 RIFE 插值来生成视频。

## 功能

- 0.01 级精度的滑杆，连续 31 级（30 个等级间隔）
- 6 个进化阶段：小难宁 → 牢宁 → 宁子 → 宁圣 → 宁神 → 宁祖
- 鼠标拖拽、触摸、键盘（←/→/↑/↓/PageUp/PageDown/Home/End）三套输入
- 响应式布局，桌面与移动端均可
- 双视频格式：WebM(VP9) 优先，MP4(H.264) 兜底
- 深色仪器风 UI：扫描网格、四角取景框、末阶段帝冠光环

## 技术栈

Vite 5 + TypeScript，渲染走隐藏 `<video>` → Canvas 2D（`seeked` + `requestVideoFrameCallback` 双重保险）。视频素材由 RIFE ncnn Vulkan + FFmpeg 生成。

---

## 环境准备

本项目运行和生成视频需要三样东西：**Node.js 22+**、**FFmpeg**、**RIFE ncnn Vulkan**。下面以 Windows 为主说明。

### 1. Node.js 22+

下载安装：https://nodejs.org/ （选 LTS 22.x）。

验证：
```bash
node -v   # 应输出 v22.x.x
npm -v
```

### 2. FFmpeg

方式一（推荐，用 winget）：
```bash
winget install Gyan.FFmpeg
```

方式二：从 https://www.gyan.dev/ffmpeg/builds/ 下载 release-full 版，解压后把 `bin` 目录加入 `PATH`。

验证：
```bash
ffmpeg -version
ffprobe -version
```

### 3. RIFE ncnn Vulkan

下载地址：https://github.com/nihui/rife-ncnn-vulkan/releases

Windows 选 `rife-ncnn-vulkan-YYYYMMDD-windows.zip`，解压到任意目录，例如 `D:\tools\rife-ncnn-vulkan\`，里面应有 `rife-ncnn-vulkan.exe`。

再下载 **rife-v4.6 模型**：https://github.com/nihui/rife-ncnn-vulkan/releases/tag/20220424 （页面里的 `rife-v4.6.zip`），解压后把 `rife-v4.6` 文件夹放到 exe 同级目录，里面应包含 `flownet.bin` 和 `flownet.param`。

验证（设置环境变量后）：
```bash
# Git Bash 写法
export RIFE_BIN="/d/tools/rife-ncnn-vulkan/rife-ncnn-vulkan.exe"
"$RIFE_BIN" --help
```

> 提示：RIFE 需要 Vulkan 支持的显卡；多数核显也能跑，只是慢一些。

---

## 使用流程

### 第 0 步：安装前端依赖

```bash
npm install
```

此时 `npm run dev` 已经可以启动，但因为没有视频素材，页面会显示「图像加载失败，请刷新重试」。接下来生成视频。

### 第 1 步：准备 6 张代表图

在 `public/frames/` 放入：

| 文件名 | 对应阶段 |
|---|---|
| `stage-0.png` | 小难宁 |
| `stage-1.png` | 牢宁 |
| `stage-2.png` | 宁子 |
| `stage-3.png` | 宁圣 |
| `stage-4.png` | 宁神 |
| `stage-5.png` | 宁祖 |

要求：PNG，推荐 800×800，6 张主体位置尽量一致（正脸居中）。详见 `public/frames/README.txt`。

### 第 2 步：设置 RIFE 环境变量

每次开新的 Git Bash 窗口都要设置（或写进 `~/.bashrc`）：

```bash
export RIFE_BIN="/d/tools/rife-ncnn-vulkan/rife-ncnn-vulkan.exe"
# 如果模型不在 exe 同级目录的 rife-v4.6 里，再设置：
# export RIFE_MODEL="/d/tools/rife-ncnn-vulkan/rife-v4.6"
```

可以先跑一次校验：
```bash
bash scripts/video/check-toolchain.sh
```

### 第 3 步：生成关键帧（第一轮插值）

```bash
bash scripts/video/build-keyframes.sh
```

把 6 张代表图插值成 31 张关键帧，输出到 `output/keyframes/frame-00.png ~ frame-30.png`。

> 想先快速验证 RIFE 效果？可以跳过这步，直接跑 `bash scripts/video/build-prototype.sh`，它只生成首尾两段的 49 帧预览 MP4 到 `output/video-prototype/`。

### 第 4 步：生成最终视频（第二轮插值）

```bash
bash scripts/video/build-full-video.sh
```

把 31 张关键帧细插值成 241 帧，编码输出到：
- `public/video/ning-evolution.webm`
- `public/video/ning-evolution.mp4`

### 第 5 步：启动

```bash
npm run dev
```

浏览器打开 http://localhost:5173 ，拖动滑杆即可。

---

## 常用命令

| 命令 | 作用 |
|---|---|
| `npm run dev` | 启动开发服务器（默认 5173 端口） |
| `npm run build` | 类型检查 + 生产构建到 `dist/` |
| `npm run preview` | 预览构建产物 |
| `npm test` | 运行单元测试（Vitest） |
| `npm run test:e2e` | 运行浏览器冒烟测试（Playwright） |

---

## 键盘操作

| 按键 | 动作 |
|---|---|
| `←` / `→` | 微调 ∓0.5 级 |
| `↑` / `↓` | 步进 ±1 级 |
| `PageUp` / `PageDown` | 跨一个阶段（±6 级） |
| `Home` / `End` | 跳到 0 级 / 满级 |

> 容器 `.experience` 可聚焦（`tabindex=0`），聚焦后即可用键盘。原生滑块本身也支持方向键。

---

## 自定义阶段名

修改 `src/progression.ts` 里的 `STAGES` 数组即可，UI 会自动跟随。若改动阶段数量，需同步调整 `LEVELS_PER_STAGE` 和代表图张数。

---

## 常见问题

**Q: 页面显示「图像加载失败，请刷新重试」**
A: `public/video/` 下还没有 `ning-evolution.webm` / `.mp4`。按上文流程生成视频。

**Q: 端口 5173 被占用**
A: 改 `vite.config.ts` 里的 `server.port`，或运行 `npm run dev -- --port 5174`。

**Q: RIFE 报错找不到模型**
A: 确认 `RIFE_MODEL` 指向的目录里有 `flownet.bin` 和 `flownet.param`。

**Q: 插值出来的画面抖动/形变**
A: 6 张代表图主体位置差异太大。尽量统一构图、正脸居中、相同朝向。

---

## 素材免责声明

`public/frames/` 与 `public/video/` 中的肖像素材仅用于娱乐演示。在复用或再发布前，请确认你拥有相关肖像与素材的使用权。
