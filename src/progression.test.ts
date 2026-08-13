import { describe, expect, it } from "vitest";
import {
  clampPosition,
  getProgression,
  LEVELS_PER_STAGE,
  MAX_LEVEL,
  STAGES,
} from "./progression";

describe("clampPosition", () => {
  it("把负数钳到 0", () => {
    expect(clampPosition(-5)).toBe(0);
  });

  it("把超出上限的值钳到 MAX_LEVEL", () => {
    expect(clampPosition(999)).toBe(MAX_LEVEL);
  });

  it("保留区间内的值", () => {
    expect(clampPosition(12)).toBe(12);
  });
});

describe("getProgression", () => {
  it("起始等级落在第一阶段", () => {
    const state = getProgression(0);
    expect(state.level).toBe(0);
    expect(state.stage).toBe("小难宁");
    expect(state.stageIndex).toBe(0);
    expect(state.toIndex).toBe(1);
    expect(state.strength).toBe(0);
  });

  it("末等级落在最后一阶段且 localProgress 为 0", () => {
    const state = getProgression(MAX_LEVEL);
    expect(state.stage).toBe("宁祖");
    expect(state.stageIndex).toBe(STAGES.length - 1);
    expect(state.localProgress).toBe(0);
    expect(state.fromIndex).toBe(state.toIndex);
    expect(state.strength).toBe(1);
  });

  it("阶段索引随等级递增", () => {
    for (let level = 0; level <= MAX_LEVEL; level += 1) {
      const state = getProgression(level);
      expect(state.stageIndex).toBe(Math.min(STAGES.length - 1, Math.floor(level / LEVELS_PER_STAGE)));
      expect(state.stage).toBe(STAGES[state.stageIndex]);
    }
  });

  it("四舍五入非整数等级", () => {
    expect(getProgression(2.4).level).toBe(2);
    expect(getProgression(2.6).level).toBe(3);
  });

  it("localProgress 在阶段内归一化", () => {
    const state = getProgression(3);
    expect(state.stageIndex).toBe(0);
    expect(state.localProgress).toBeCloseTo(0.5, 5);
  });
});
