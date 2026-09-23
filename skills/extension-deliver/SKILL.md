---
name: extension-deliver
description: 将当前迭代提交用户验收，并在交付前核对适用知识约束。
---
# 扩展交付

实现和可独立成立的知识记录完成后再交付。脚本将当前迭代置为 `PendingUserReview`，输出需求摘要与交付物路径，再提示用户验收。扩展生命周期保持 Active。

交付脚本按当前 stage 再次执行就绪校验。原型交付必须提供存在的 HTML 文件并满足适用样式及数据展示约束；嵌入交付的 `integration_evidence.changes` 必须逐文件记录路径、备份、修改前后 SHA-256 和差异，并记录验证与回滚。联动模式的原型交付验收后才进入嵌入需求阶段。

交付前必须用本轮涉及的全部 facet 重新运行 `knowledge-context`，核对产物是否满足适用 Verified 约束。偏离项必须在交付摘要或证据中说明依据、影响和验证结果；不能在没有核对知识的情况下进入用户验收。

```powershell
powershell -NoProfile -File skills/extension-deliver/run.ps1 -Extension EXT-001 -Summary "本轮完成内容" -Artifact "prototype/index.html"
```
