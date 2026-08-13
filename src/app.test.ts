import { describe, expect, it, beforeEach } from "vitest";
import { mountApp, type AppController } from "./app";
import { MAX_LEVEL } from "./progression";

function setup(): {
  root: HTMLElement;
  controller: AppController;
  levels: number[];
} {
  const root = document.createElement("div");
  document.body.innerHTML = "";
  document.body.appendChild(root);
  const levels: number[] = [];
  const controller = mountApp(root, (level) => levels.push(level));
  return { root, controller, levels };
}

describe("mountApp", () => {
  beforeEach(() => {
    document.body.innerHTML = "";
  });

  it("挂载后渲染标题与初始阶段名", () => {
    const { root } = setup();
    expect(root.querySelector("h1")?.textContent).toBe("滑动变祖器");
    expect(root.querySelector(".stage-name")?.textContent).toBe("小难宁");
  });

  it("滑块初始禁用，等级输出为 00 / 30", () => {
    const { root } = setup();
    const slider = root.querySelector<HTMLInputElement>("#strength-slider")!;
    expect(slider.disabled).toBe(true);
    expect(slider.min).toBe("0");
    expect(slider.max).toBe(String(MAX_LEVEL));
    expect(slider.step).toBe("0.01");
    expect(root.querySelector(".level-output")?.textContent).toBe(`00 / ${MAX_LEVEL}`);
  });

  it("setLevel 更新阶段名、刻度高亮和 CSS 变量", () => {
    const { controller, levels } = setup();
    controller.setLevel(MAX_LEVEL);

    expect(controller.level).toBe(MAX_LEVEL);
    // levels 末尾记录的是 setLevel(MAX_LEVEL) 触发的回调
    expect(levels.at(-1)).toBe(MAX_LEVEL);

    controller.setLevel(15);
    expect(controller.level).toBe(15);
  });

  it("setReady 解禁滑块并隐藏加载态", () => {
    const { controller } = setup();
    controller.setReady();
    expect(controller.slider.disabled).toBe(false);
  });

  it("setError 禁用滑块并显示错误文案", () => {
    const { controller } = setup();
    controller.setError("出错了");
    expect(controller.slider.disabled).toBe(true);
  });

  it("键盘 ArrowRight 使等级减小", () => {
    const { root, controller } = setup();
    controller.setLevel(10);

    const experience = root.querySelector<HTMLElement>(".experience")!;
    experience.dispatchEvent(
      new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true }),
    );
    expect(controller.level).toBe(9.5);
  });

  it("键盘 PageUp 跨一个阶段（+6）", () => {
    const { root, controller } = setup();
    controller.setLevel(3);

    const experience = root.querySelector<HTMLElement>(".experience")!;
    experience.dispatchEvent(
      new KeyboardEvent("keydown", { key: "PageUp", bubbles: true }),
    );
    expect(controller.level).toBe(9);
  });

  it("键盘 End 跳到满级，Home 回到 0", () => {
    const { root, controller } = setup();
    const experience = root.querySelector<HTMLElement>(".experience")!;

    experience.dispatchEvent(
      new KeyboardEvent("keydown", { key: "End", bubbles: true }),
    );
    expect(controller.level).toBe(MAX_LEVEL);

    experience.dispatchEvent(
      new KeyboardEvent("keydown", { key: "Home", bubbles: true }),
    );
    expect(controller.level).toBe(0);
  });
});
