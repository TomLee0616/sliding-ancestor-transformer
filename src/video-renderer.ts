import { clampPosition, MAX_LEVEL } from "./progression";

const VIDEO_FPS = 30;
// MAX_LEVEL(30) * 8 = 240，加上首帧共 241 帧。
const INTERPOLATION_FACTOR = 8;

export interface EvolutionVideoRenderer {
  readonly video: HTMLVideoElement;
  load(): Promise<void>;
  render(position: number): void;
  redraw(): void;
}

/** 把滑块位置映射到视频时间轴上的时刻。 */
export function positionToVideoTime(position: number, duration: number): number {
  return (clampPosition(position) / MAX_LEVEL) * duration;
}

function videoAssetPath(filename: string): string {
  const base = import.meta.env.BASE_URL.endsWith("/")
    ? import.meta.env.BASE_URL
    : `${import.meta.env.BASE_URL}/`;
  return `${base}video/${filename}`;
}

function resizeCanvasToDisplaySize(canvas: HTMLCanvasElement): void {
  const ratio = Math.min(window.devicePixelRatio || 1, 2);
  const width = Math.round(canvas.clientWidth * ratio);
  const height = Math.round(canvas.clientHeight * ratio);

  if (canvas.width !== width || canvas.height !== height) {
    canvas.width = width;
    canvas.height = height;
  }
}

/** 创建一个把隐藏 <video> 的当前帧绘制到 canvas 的渲染器。 */
export function createEvolutionVideoRenderer(
  canvas: HTMLCanvasElement,
): EvolutionVideoRenderer {
  const video = document.createElement("video");
  video.className = "evolution-video";
  video.preload = "auto";
  video.muted = true;
  video.playsInline = true;
  video.tabIndex = -1;
  video.setAttribute("aria-hidden", "true");

  const webmSource = document.createElement("source");
  webmSource.src = videoAssetPath("ning-evolution.webm");
  webmSource.type = 'video/webm; codecs="vp9"';

  const mp4Source = document.createElement("source");
  mp4Source.src = videoAssetPath("ning-evolution.mp4");
  mp4Source.type = 'video/mp4; codecs="avc1.64001f"';

  video.append(webmSource, mp4Source);
  canvas.after(video);

  let requestedTime = 0;
  let seekFrame = 0;

  const drawNow = (): void => {
    if (video.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) {
      return;
    }

    resizeCanvasToDisplaySize(canvas);
    const context = canvas.getContext("2d");
    if (!context) {
      throw new Error("当前浏览器不支持 Canvas 2D");
    }

    context.clearRect(0, 0, canvas.width, canvas.height);
    context.imageSmoothingEnabled = true;
    context.imageSmoothingQuality = "high";
    context.drawImage(video, 0, 0, canvas.width, canvas.height);
  };

  // seeked 后再补一帧 rVFC，确保解码完成的画面真正画上去。
  const drawDecodedFrame = (): void => {
    drawNow();
    if (typeof video.requestVideoFrameCallback === "function") {
      video.requestVideoFrameCallback(() => drawNow());
    }
  };

  video.addEventListener("seeked", drawDecodedFrame);

  const render = (position: number): void => {
    const clampedPosition = clampPosition(position);
    requestedTime = positionToVideoTime(clampedPosition, video.duration || 0);
    canvas.dataset.frame = String(
      Math.round(clampedPosition * INTERPOLATION_FACTOR),
    ).padStart(3, "0");

    cancelAnimationFrame(seekFrame);
    seekFrame = requestAnimationFrame(() => {
      if (!Number.isFinite(requestedTime) || video.readyState < 1) {
        return;
      }

      // 避免越过最后一帧时间戳导致 seek 卡住。
      const lastFrameTime = Math.max(0, video.duration - 1 / VIDEO_FPS);
      video.currentTime = Math.min(requestedTime, lastFrameTime);
    });
  };

  return {
    video,
    load() {
      return new Promise<void>((resolve, reject) => {
        const handleReady = (): void => {
          drawNow();
          resolve();
        };
        const handleError = (): void => {
          reject(new Error("连续人像视频加载失败"));
        };

        video.addEventListener("loadeddata", handleReady, { once: true });
        video.addEventListener("error", handleError, { once: true });
        video.load();
      });
    },
    render,
    redraw: drawNow,
  };
}
