---
name: workspace-doctor
description: 检查 PLM-Studio 工作区，或按指定扩展的交付模式检查所需条件。
---
# workspace-doctor

不带 `-Extension` 时只检查工作区身份和默认策略。带扩展编号时，按 `static`、`static-demo`、`embedded-static`、`backend` 分别校验，避免为静态原型追问无关环境。

`powershell -NoProfile -File skills/workspace-doctor/run.ps1 -Extension EXT-001`
