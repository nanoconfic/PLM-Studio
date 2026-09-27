---
name: browser-inspect
description: 使用 PLM-Studio 工作区共享的 Chromium 检查页面并保存运行时证据。
---
# browser-inspect

浏览器介质和 Playwright 依赖是工作区级资源，所有扩展复用。必须传入 `-Extension`，工具从该扩展读取绑定的 profile，不使用全局活动环境。`-Run` 的证据写入 `runtime/browser/<EXT-nnn>`。

## 可执行入口

`powershell -NoProfile -File skills/browser-inspect/run.ps1 -Extension EXT-001 -Initialize`

`-Initialize` 会先检查浏览器模式和可执行文件：CDP 模式直接使用配置的远程浏览器；本地 Chromium 已存在时直接复用。这两种情况都跳过 ZIP 检查。只有本地启动模式缺少浏览器程序时，才优先使用 `tools/browser/media/chrome-win64.zip`；介质缺失时，工具从 Chrome for Testing 官方 Stable 元数据取得 Windows x64 下载地址，先请求该地址确认网络可达，再下载到 `tools/browser/media` 并解压。下载失败时会保留错误地址与原因；网络受限时可手动把介质放回上述 ZIP 路径后重试。
