# Shared browser runtime

- `media/chrome-win64.zip`：本地 Chromium 介质缓存，Git 忽略。初始化时优先复用；缺失时从 Chrome for Testing 官方 Stable 下载。
- `chromium/chrome-win64/chrome.exe`：解压后的共享浏览器，所有扩展复用。

使用 `skills/browser-inspect/run.ps1 -Initialize` 准备依赖。CDP 模式使用已配置的远程浏览器；本地 Chromium 已存在时直接复用，均跳过 ZIP 检查。只有本地启动模式缺少浏览器程序时，才检查本地 ZIP；ZIP 缺失时先确认官方下载地址可达再下载。网络不可达时会停止并提示原因。下载和解压后的浏览器均由所有扩展共享。
