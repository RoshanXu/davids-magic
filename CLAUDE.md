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
  index.html             全部逻辑都在这一个文件里（HTML + CSS + JS，约 900 行）
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

### FFmpeg 加载链路（改任何一环都会加载失败）

页面 `<script type="module">` 的执行顺序，出错点全在这里：

1. `import { FFmpeg } from './ffmpeg/ffmpeg/index.js'`、`import { toBlobURL } from './ffmpeg/util/index.js'` —— 相对路径，基于页面 URL（线上在 `/david/` 下解析）。
2. `initFFmpeg()` 里 `toBlobURL('./ffmpeg/core/ffmpeg-core.js')` → 主线程 `fetch` → `ArrayBuffer` → `Blob URL`。
3. 再 `toBlobURL('./ffmpeg/core/ffmpeg-core.wasm')`（约 32MB）→ 同上。
4. `ffmpeg.load({ coreURL, wasmURL })` → `new Worker('./ffmpeg/ffmpeg/worker.js', { type: 'module' })`。
5. worker 内 `load()`：先 `importScripts(blobURL)`（module worker 里不可用，抛错）→ catch 里 `await import(blobURL)` 取 `.default` 得 `createFFmpegCore`。
6. `createFFmpegCore({ mainScriptUrlOrBlob: blobURL + '#' + btoa(JSON.stringify({wasmURL, workerURL})) })` → 内部 `_locateFile` 解出 wasm 的 blob URL → 实例化 wasm。
7. 加载完成 → 启用导出按钮。

要点：core 是 **ESM 构建**（文件尾 `export default createFFmpegCore`）；core/wasm 全程走 **blob URL**，所以主文档绝不能进 cross-origin isolation（见踩坑 1）。

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

### 部署拓扑（线上）

```
浏览器 https://www.pandabox.site/david/xxx
  → 宿主 nginx（/etc/nginx/sites-available/flask-proxy，443）
      location /david/ → proxy_pass http://127.0.0.1:8080/   ← 尾斜杠重写路径：/david/xxx → /xxx
  → 容器 nginx（docker/nginx.conf，监听 80）
      root /usr/share/nginx/html（Dockerfile COPY web/ 进来）
      .wasm/.js → expires 30d immutable；.html → no-cache
```

- 宿主只做 SSL + 反代，**不加 COOP/COEP**；容器 nginx 也不加（单线程 core 不需要）。
- 页面相对路径 `./ffmpeg/...` 基于 `/david/` 解析，所以 `proxy_pass` 的尾斜杠不能丢，否则路径错位 404。
- 改 `web/index.html` 或 `docker/nginx.conf` 后必须 `docker compose up -d --build`（COPY 进镜像才生效）。

### Flutter 版（本地开发）

```bash
flutter run                  # 桌面/设备
flutter build windows        # 需同目录放 ffmpeg.exe / ffprobe.exe
flutter build apk
```

## ⚠️ 关键不变量（违反任意一条 → FFmpeg 加载失败或导出异常）

- 用**单线程** core `@ffmpeg/core@0.12.6`（不是 `@ffmpeg/core-mt`）。
- **不给**任何响应加 `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy`（cross-origin isolation 会破坏 blob URL 加载）。
- **不 gzip** `application/wasm`（浪费内存，手机端易失败）。
- html `no-cache`、wasm/js `immutable`（改完页面无需强刷）。
- FFmpeg 路径用相对路径 `./ffmpeg/...`。
- 宿主 nginx `location /david/` 的 `proxy_pass` 必须带尾斜杠。

## 关键技术细节 & 踩坑

1. **当前用单线程 FFmpeg.wasm core（`@ffmpeg/core@0.12.6`），不需要 SharedArrayBuffer，也不需要 COOP/COEP 头**；反之给主文档加 `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp` 会进入 cross-origin isolation，反而破坏 blob URL 加载导致「FFmpeg 加载失败」。若未来换多线程 core（`@ffmpeg/core-mt`）才需要这些头。
2. **微信内置浏览器无法保存文件**（iOS WKWebView 不认 `<a download>`，安卓 X5 屏蔽 blob 下载；Web Share API 也不可用）。纯前端无解，只能引导「右上角···→在浏览器打开」。想原生保存需接微信 JS-SDK（要后端签名 + 公众号 + JS 安全域名），目前未做。
3. **html 已配 `no-cache`**（`docker/nginx.conf` 里 `location ~* \.html$`），更新后刷新即生效；wasm/js 配 `immutable` 长期缓存（改 core 需改文件名或清缓存）。
4. 导出拼接受限：视频拼接假定每段都有音轨；帧率统一 30；横竖屏/不同比例混合会自动黑边补齐；音视频混合 + 视频输出会报错（需分别导出）。
5. Flutter 版 `FfmpegService`：Android 用 `FFmpegKit`，Windows 用应用目录下的 `ffmpeg.exe`/`ffprobe.exe`（`Process.run`），桌面端还会把命令存到 `%TEMP%/_dm_cmd.bat` 便于复现。

## Git 约定

- 提交信息用 Conventional Commits（`feat:` / `fix:` / `ci:`）。
- 两个远程：`origin` → gitee.com/ROSHAN_XU/davids-magic，`github` → github.com/RoshanXu/davids-magic；`main` 跟踪 `github/main`。
- git 配了代理 `http://127.0.0.1:7890`（本地 Clash 等）；连不上时需确认代理已开，或对国内 gitee 用 `git -c http.proxy= -c https.proxy= push ...` 临时关代理。
- 默认分支是 `main`，不要在 `main` 上直接提交，先开分支。
