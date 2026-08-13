import { expect, test } from "@playwright/test";

test.describe("滑动变祖器", () => {
  test("页面加载后显示标题与初始阶段", async ({ page }) => {
    await page.goto("/");

    await expect(page.locator("h1")).toHaveText("滑动变祖器");
    await expect(page.locator(".stage-name")).toHaveText("小难宁");
    await expect(page.locator(".level-output")).toContainText("00 / 30");
  });

  test("键盘 ArrowRight 能降低等级（需先解锁滑块）", async ({ page }) => {
    await page.goto("/");

    // 视频可能不存在（无素材环境），手动解禁滑块以便测试交互
    await page.evaluate(() => {
      const slider = document.getElementById(
        "strength-slider",
      ) as HTMLInputElement | null;
      slider?.removeAttribute("disabled");
      const loadState = document.querySelector(".load-state") as HTMLElement | null;
      if (loadState) loadState.hidden = true;
    });

    const experience = page.locator(".experience");
    await experience.focus();

    // 先拉到中间，再按 ArrowRight（本实现中 Right = -0.5）
    await page.evaluate(() => {
      const slider = document.getElementById(
        "strength-slider",
      ) as HTMLInputElement;
      slider.value = "10";
      slider.dispatchEvent(new Event("input", { bubbles: true }));
    });
    await expect(page.locator(".level-output")).toContainText("10 / 30");

    await page.keyboard.press("ArrowRight");
    await expect(page.locator(".level-output")).toContainText("09 / 30");
  });
});
