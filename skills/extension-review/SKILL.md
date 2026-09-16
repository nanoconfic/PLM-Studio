---
name: extension-review
description: 将用户对扩展交付物的验收结果写入当前迭代，并处理相关知识变化。
---
# 扩展验收回写

用户验收交付物后运行。`Accepted` 关闭当前迭代但保持扩展 Active；下次修改自动开始新迭代。`ChangesRequested` 返回当前迭代修改流程。只记录用户明确给出的反馈，不替用户推断结论。

验收反馈改变样式、交互、业务、数据或集成方案时，继续修改前必须重新加载对应知识 facet。将有证据支持的新结论加入知识积累；与既有 Verified 知识冲突时记录 contradiction，再决定晋升、保留或废弃。

```powershell
powershell -NoProfile -File skills/extension-review/run.ps1 -Extension EXT-001 -Result Accepted -Feedback "验收通过"
```
