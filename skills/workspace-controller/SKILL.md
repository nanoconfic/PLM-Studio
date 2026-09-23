---
name: workspace-controller
description: 根据扩展长期状态计算当前允许的动作，并在 Skill 执行前拒绝越阶段操作。
---
# Workspace Controller

Agent 从自然语言判断三个能力模式和目标扩展；未明确目标时先运行 `controller/run.ps1 -Json`。选定扩展后运行 `controller/run.ps1 -Extension EXT-nnn -Json` 查看状态、允许动作和缺失项，再以 `-Action <动作>` 检查准备执行的动作。`skills/workspace-controller/run.ps1` 保留兼容入口。退出码 `2` 表示拒绝；不得以直接调用 Tool 或手工改写 `workflow.phase` 绕过拒绝。

```powershell
powershell -NoProfile -File controller/run.ps1 -Extension EXT-001 -Json
powershell -NoProfile -File controller/run.ps1 -Extension EXT-001 -Action implement
```

Controller 从 `extension.yaml` 计算允许动作，不维护第二份状态。`Requirements` 且 `requirements_confirmed=false` 时可更新需求、检查环境；确认交付模式后可确认需求。用户明确确认需求摘要后，Agent 用 `Read-Config` / `Write-Config` 写入确认标志；随后运行 `prototype-preflight`。只有开工门禁通过、阶段进入 `Implementation` 后才能实现或交付。`PendingUserReview` 只允许记录验收结果；`Completed` 可开始下一轮。

`inspect_environment` 仅指只读检查原环境及向工作区镜像同步源码；不授权修改原系统。原系统文件修改继续遵守 `original_system_change` 的路径、范围、快照和备份约束。Skill 入口仍须独立执行自身更细的验证，Controller 的通过不代替知识注入、样式确认或原系统修改授权。
