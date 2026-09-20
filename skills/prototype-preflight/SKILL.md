---
name: prototype-preflight
description: 在 PLM-Studio 开始原型页面设计或实现前，校验交付模式、已确认需求、PLM 点击/嵌入路径、样式来源及批量数据展示方式。
---
# 原型开工门禁

交付模式明确后仍必须停留在需求阶段。把用户提供的原型设计需求写入 `extension.yaml`，并只在用户明确确认后设置 `workflow.requirements_confirmed=true`。

开始页面结构、视觉设计或代码实现之前运行：

```powershell
powershell -NoProfile -File skills/prototype-preflight/run.ps1 -Extension EXT-001
```

门禁要求：

- 目标、场景、输入/数据来源、页面与交互、验收标准、约束和不做范围完整；
- `target.navigation_path` 是 PLM 用户点击顺序；嵌入式交付还要有 `target.mount_sequence`；
- 同路径存在 Verified 样式知识时自动登记匹配；新路径必须先询问用户是否拉取原产品样式，并在用户确认样式后记录 `style_context.status=source-confirmed`、`user_confirmed=true` 和 evidence；
- Excel 约束只在本轮需求实际出现 Excel/XLS/XLSX 或其他批量条目解析时触发。触发后 `requirements.data_preview` 必须选择 `table` 或原产品 `native-grid`，并明确列清单和解析、滚动、逐行校验反馈；默认推荐原产品网格。未涉及解析的扩展保持 `required=false`、`mode=none`，无需配置列或交互。

脚本通过后才把迭代置为 `Implementation`。不得手工绕过失败项。
