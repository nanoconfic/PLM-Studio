---
name: extension-deliver
description: 将当前迭代提交用户验收，并在交付前核对适用知识约束。
---
# 扩展交付

实现和可独立成立的知识记录完成后再交付。脚本将当前迭代置为 `PendingUserReview`，输出需求摘要与交付物路径，再提示用户验收。扩展生命周期保持 Active。

交付脚本会再次执行原型就绪校验。未确认需求、缺少 PLM 点击/嵌入路径、样式来源未解决，或 Excel 解析结果未采用 `table`/原生网格时，交付必须失败；不得在交付阶段补写或假定这些结论。

交付前必须用本轮涉及的全部 facet 重新运行 `knowledge-context`，核对产物是否满足适用 Verified 约束。偏离项必须在交付摘要或证据中说明依据、影响和验证结果；不能在没有核对知识的情况下进入用户验收。

```powershell
powershell -NoProfile -File skills/extension-deliver/run.ps1 -Extension EXT-001 -Summary "本轮完成内容" -Artifact "prototype/index.html"
```
