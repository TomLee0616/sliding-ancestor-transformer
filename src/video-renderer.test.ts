import { describe, expect, it } from "vitest";
import { MAX_LEVEL } from "./progression";
import { positionToVideoTime } from "./video-renderer";

describe("positionToVideoTime", () => {
  it("起始位置映射到 0", () => {
    expect(positionToVideoTime(0, 10)).toBe(0);
  });

  it("最大位置映射到视频全长", () => {
    expect(positionToVideoTime(MAX_LEVEL, 10)).toBe(10);
  });

  it("中间位置线性映射", () => {
    expect(positionToVideoTime(MAX_LEVEL / 2, 8)).toBe(4);
  });

  it("超出范围会被钳制", () => {
    expect(positionToVideoTime(-100, 10)).toBe(0);
    expect(positionToVideoTime(9999, 10)).toBe(10);
  });
});
