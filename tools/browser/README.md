# Shared browser runtime

- `media/chrome-win64.zip`：用户提供的 Chromium 压缩包，作为离线介质保留。
- `chromium/chrome-win64/chrome.exe`：解压后的共享浏览器，所有扩展复用。

使用 `skills/browser-inspect/run.ps1 -Initialize` 准备依赖；不会为单个扩展重复下载浏览器。
