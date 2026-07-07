import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// 构建产物输出到 web/dist，由仓库根目录的 server.js 静态托管（同域名同端口，wss 自动同源）。
export default defineConfig({
  plugins: [react()],
  base: "/",
  build: {
    outDir: "dist",
    target: "es2018",
    assetsInlineLimit: 8192,
  },
  server: {
    port: 5173,
    proxy: {},
  },
});
