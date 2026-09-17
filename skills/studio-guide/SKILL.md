---
name: studio-guide
description: PLM-Studio 的统一只读入口，展示 Active 扩展的 ID 和名称并提供新增或修改入口。
---
# studio-guide

用户输入 `/start`、说“开始使用 PLM-Studio”，或没有明确指定新建/修改哪个扩展时，必须先运行本工具，不能直接分析。

工具只读，不显示凭据。所有 Active 扩展始终可选；状态只决定选择后是继续当前迭代、等待验收，还是开启下一轮。`-Json` 供 CLI/Harness 获取结构化状态。

`powershell -NoProfile -File skills/studio-guide/run.ps1`
