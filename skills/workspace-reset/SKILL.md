---
name: workspace-reset
description: 归档并重置运行产物，或归档单个扩展；不删除知识和其他扩展。
---
# workspace-reset

使用 `-WhatIf` 预览。`runtime` 只归档可重新生成的运行产物；`extension` 归档指定扩展。工作区配置、知识和其他扩展不受影响。

`powershell -NoProfile -File skills/workspace-reset/run.ps1 -Mode runtime -WhatIf`
