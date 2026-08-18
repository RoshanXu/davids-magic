# CLAUDE.md

## 项目概述

DavidMagic（大卫的魔法工具）—— 面向老年用户的**本地音视频处理工具**：合并、剪辑、格式转换。
设计原则：界面简洁、字体大号、流程清晰、防误操作、支持 Windows / Android。

需求细节见 `PRD.md`，最初构思见 `构思.md`。

## ⚠️ 关键：仓库里有「两套实现」，不要搞混

| | Flutter 原生版 | Web 版 |
|---|---|---|
| 位置 | `lib/`、`android/`、`windows/`、`linux/` | `web/`（**独立手写，不是 Flutter web 构建产物**） |
| ffmpeg 方案 | `ffmpeg_kit_flutter_full`（Android 内置）/ `ffmpeg.exe`+`ffprobe.exe`（Windows，放应用目录） | FFmpeg.wasm（本地打包在 `web/ffmpeg/`） |
| 状态 | 早期开发、功能较全（草稿、片段删除、进度） | **当前线上部署的重点**，通过 Docker/nginx 部署，主要在微信里用 |
| 改动影响 | 改 `lib/` 只影响桌面/安卓 App | 改 `web/` 只影响网页版 |

**改 Web 版就改 `web/index.html`；改 Flutter 版就改 `lib/`。两边互不影响。**

## 目录结构

```
lib/                     Flutter 原生版
  main.dart              入口（主题、草稿恢复）
  models/                media_file.dart / export_settings.dart
  providers/project_provider.dart   状态管理（provider）
  services/              ffmpeg_service.dart（核心）/ draft_service.dart
  screens/home_screen.dart
  widgets/               file_list_panel / clip_dialog / export_dialog / preview_dialog / progress_dialog ...
web/                     Web 版（线上）
  index.html             全部逻辑都在这一个文件里（HTML + CSS + JS，约 700 行）
  ffmpeg/                ffmpeg-core.wasm(~32MB) + js 加载器（本地，无 CDN 依赖）
docker/                  nginx.conf
Dockerfile / docker-compose.yml
PRD.md / 构思.md / README.md
```

## Web 版（`web/index.html`）结构要点

单文件应用，用原生 ES Module 引入 `./ffmpeg/ffmpeg/index.js`。主要部分：

- `initFFmpeg()`：`ffmpeg.load({ coreURL, wasmURL })`，本地 `toBlobURL`，加载完才启用导出按钮。
- 状态：`files[]`（File 对象）、`selectedFormat`、`selectedQuality`（`undefined`=未选/原画、`null`=原画、数字=统一高度）、`fileResolutions`（Map: File→{w,h}）。
- `probeVideoResolution(file)`：用浏览器 `<video>` 读宽高（快）；**不用 ffmpeg 探测**（ffmpeg.wasm 只能读虚拟 FS，探测得先 writeFile 整个文件，慢）。
- `updateQualitySection()`：画质栏默认隐藏；仅当导入「多个不同分辨率视频」时显示，默认选最高分辨率 + 「原画」选项。
- `doExport()`：单文件 = 裁剪+转码；多文件 = `concat` 滤镜拼接（`buildVideoConcat`/`buildAudioConcat`，统一分辨率/帧率 30/像素格式/音频参数）。
- `triggerDownload()`：优先 Web Share API → 微信 UA 检测弹「在浏览器打开」引导 → 传统 `<a download>`（延迟 revoke blob URL）。

## 构建 / 运行 / 部署

### Web 版（Docker，线上）

```bash
docker build -t davids-magic:latest .
docker compose up -d --build          # 映射 8080→80，访问 http://localhost:8080
docker run -d --name davids-magic -p 8080:80 davids-magic:latest
```

Dockerfile 是构建时 `COPY web/` 进 nginx 镜像，**改 `web/index.html` 后必须重新 build 才生效**。
快速更新单文件（临时，容器重建即丢失）：
```bash
docker cp web/index.html davids-magic:/usr/share/nginx/html/index.html
```

### Flutter 版（本地开发）

```bash
flutter run                  # 桌面/设备
flutter build windows        # 需同目录放 ffmpeg.exe / ffprobe.exe
flutter build apk
```

## 关键技术细节 & 踩坑

1. **当前用单线程 FFmpeg.wasm core（`@ffmpeg/core@0.12.6`），不需要 SharedArrayBuffer，也不需要 COOP/COEP 头**；反之给主文档加 `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp` 会进入 cross-origin isolation，反而破坏 blob URL 加载导致「FFmpeg 加载失败」。若未来换多线程 core（`@ffmpeg/core-mt`）才需要这些头。
2. **微信内置浏览器无法保存文件**（iOS WKWebView 不认 `<a download>`，安卓 X5 屏蔽 blob 下载；Web Share API 也不可用）。纯前端无解，只能引导「右上角···→在浏览器打开」。想原生保存需接微信 JS-SDK（要后端签名 + 公众号 + JS 安全域名），目前未做。
3. **nginx 对 html 配了 `expires 7d`**，更新后浏览器可能缓存旧版，需强刷或改成 `no-cache`。
4. 导出拼接受限：视频拼接假定每段都有音轨；帧率统一 30；横竖屏/不同比例混合会自动黑边补齐；音视频混合 + 视频输出会报错（需分别导出）。
5. Flutter 版 `FfmpegService`：Android 用 `FFmpegKit`，Windows 用应用目录下的 `ffmpeg.exe`/`ffprobe.exe`（`Process.run`），桌面端还会把命令存到 `%TEMP%/_dm_cmd.bat` 便于复现。

## Git 约定

- 提交信息用 Conventional Commits（`feat:` / `fix:` / `ci:`）。
- 两个远程：`origin` → gitee.com/ROSHAN_XU/davids-magic，`github` → github.com/RoshanXu/davids-magic；`main` 跟踪 `github/main`。
- git 配了代理 `http://127.0.0.1:7890`（本地 Clash 等）；连不上时需确认代理已开，或对国内 gitee 用 `git -c http.proxy= -c https.proxy= push ...` 临时关代理。
- 默认分支是 `main`，不要在 `main` 上直接提交，先开分支。
