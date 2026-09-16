---
name: knowledge-context
description: 为指定扩展按 profile、产品版本和任务类型加载适用知识，在原型设计、集成、业务、数据或环境决策前注入模型上下文。
---
# 知识上下文注入

当扩展工作涉及页面样式、交互、原系统集成、业务规则、数据、接口、环境分析或交付检查时，先运行本技能。它读取扩展绑定的 profile、知识索引和适用的知识记录，把筛选后的内容直接输出到当前模型上下文。

```powershell
powershell -NoProfile -File skills/knowledge-context/run.ps1 `
  -Extension EXT-001 -Facet Style,Integration
```

`-Facet Auto` 会根据扩展的目标、交付模式和数据设置选择范围。需求明确后应传入精确范围：`Style`、`Integration`、`Business`、`Data`、`Environment` 或 `All`。

必须完整读取脚本输出后再制定设计或实现方案。输出中的“Applicable Verified constraints”是当前任务的默认约束；`Candidate` 和指纹未确认记录只能用于提问和验证；`Deprecated` 不得采用。用户明确要求偏离 Verified 知识时，应说明偏离项并记录新的证据，不能静默覆盖。

任务场景与 facet 的映射见 [references/scenarios.md](references/scenarios.md)。

以下情况必须重新运行：切换扩展或 profile；开始新迭代；目标模块、菜单、页面或交付模式变化；主题、角色、产品版本或源码指纹变化；用户反馈改变了页面、流程、数据或集成方案。

本技能只读，不修改扩展、知识库或原系统。
