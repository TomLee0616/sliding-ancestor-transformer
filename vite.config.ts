import { defineConfig } from "vite";

// GitHub Pages 部署在子路径 https://用户名.github.io/sliding-ancestor-transformer/
// 所以生产构建的 base 必须设为该子路径，否则资源 404。
// 本地 dev 时 base 用默认 '/'，不影响开发。
export default defineConfig({
  base: process.env.NODE_ENV === "production" ? "/sliding-ancestor-transformer/" : "/",
  server: {
    port: 5173,
    // 忽略 public/ 的文件监视：里面的图/视频是静态资源，
    // 在下载或重新生成（RIFE 写入）时会产生 .crdownload 等瞬态文件，
    // 触发 Windows 上的 EBUSY 锁错误导致 dev server 崩溃。
    watch: {
      ignored: ["**/public/**"],
    },
  },
});
