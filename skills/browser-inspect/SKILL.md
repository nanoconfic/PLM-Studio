---
name: browser-inspect
description: 使用 PLM-Studio 工作区共享的 Chromium 检查页面并保存运行时证据。
---
# browser-inspect

浏览器介质和 Playwright 依赖是工作区级资源，所有扩展复用。必须传入 `-Extension`，工具从该扩展读取绑定的 profile，不使用全局活动环境。`-Run` 的证据写入 `runtime/browser/<EXT-nnn>`。

## 可执行入口

`powershell -NoProfile -File skills/browser-inspect/run.ps1 -Extension EXT-001 -Initialize`
