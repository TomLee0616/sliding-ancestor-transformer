// 6 个进化阶段，从"小难宁"一路变到戴皇冠的"宁祖"。
export const STAGES = ["小难宁", "牢宁", "宁子", "宁圣", "宁神", "宁祖"] as const;

// 滑块最大等级（也是关键帧索引上限）。
export const MAX_LEVEL = 30;

// 每个阶段覆盖的等级数：30 / 6 = 5 段过渡 + 末段定格。
export const LEVELS_PER_STAGE = 6;

export type StageName = (typeof STAGES)[number];

export interface ProgressionState {
  level: number;
  stage: StageName;
  stageIndex: number;
  fromIndex: number;
  toIndex: number;
  // 当前阶段内的归一化进度 [0,1]，末阶段恒为 0。
  localProgress: number;
  // 全局归一化强度 [0,1]。
  strength: number;
}

/** 把任意数值钳制到 [0, MAX_LEVEL]。 */
export function clampPosition(rawPosition: number): number {
  return Math.min(MAX_LEVEL, Math.max(0, rawPosition));
}

/** 根据原始等级计算完整的进度状态。 */
export function getProgression(rawLevel: number): ProgressionState {
  const level = Math.round(clampPosition(rawLevel));
  const stageIndex = Math.floor(level / LEVELS_PER_STAGE);
  const isFinalStage = stageIndex === STAGES.length - 1;
  const localProgress = isFinalStage
    ? 0
    : (level - stageIndex * LEVELS_PER_STAGE) / LEVELS_PER_STAGE;

  return {
    level,
    stage: STAGES[stageIndex],
    stageIndex,
    fromIndex: stageIndex,
    toIndex: isFinalStage ? stageIndex : stageIndex + 1,
    localProgress,
    strength: level / MAX_LEVEL,
  };
}
