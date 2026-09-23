---
name: studio-guide
description: 旧版只读扩展列表兼容工具；新任务统一由 controller/run.ps1 路由。
---
# studio-guide

此 Skill 只保留旧自动化兼容。自然语言入口统一使用 `controller/run.ps1 -Json`，由 Controller 返回能力模式、Active 扩展及下一步状态；不需要触发词。

工具只读，不显示凭据。所有 Active 扩展始终可选；状态只决定选择后是继续当前迭代、等待验收，还是开启下一轮。`-Json` 供 CLI/Harness 获取结构化状态。

`powershell -NoProfile -File skills/studio-guide/run.ps1`
