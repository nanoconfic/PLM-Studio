---
name: extension-iterate
description: 继续现有扩展或开始下一轮迭代，并在修改前注入适用知识上下文。
---
# 扩展迭代

确认用户要修改的 `EXT-nnn`。默认 `-Action Auto`：Accepted/Completed 的当前迭代先归档再开始新的 `ITER-nnn`；未完成或未验收的迭代原地继续。保留扩展绑定的 profile、lifecycle 和原系统修改授权。所有 Active 扩展都可选择。

进入迭代后脚本自动运行 `knowledge-context -Facet Auto`。补齐本轮需求后，必须按受影响范围重新运行精确 facet，再制定方案或修改原型：

- 页面、布局、组件和交互：`Style`
- 菜单、挂载和资源注册：`Integration`
- 流程、状态、权限和校验：`Business`
- 数据、接口、数据库和写入：`Data,Business`
- 环境、源码和部署：`Environment`

完整读取输出，并把适用 Verified 知识作为默认约束。Candidate 只用于提问或验证；范围不匹配和 Deprecated 记录不得采用。

不论继续当前迭代还是开始新迭代，只要用户提出新的页面或交互范围，就先更新并确认本轮原型需求。已有交付模式不等于可以立即实现。需求确认后运行 `skills/prototype-preflight/run.ps1 -Extension EXT-nnn`；门禁会核对点击路径、技术嵌入顺序、样式来源和批量数据展示方式。

相同 `target.navigation_path` 的 Verified 样式可直接复用。新路径不得套用其他页面风格；先询问用户是否从原产品拉取样式，取得用户对样式的确认并形成 evidence/knowledge 后再设计。

```powershell
powershell -NoProfile -File skills/extension-iterate/run.ps1 -Extension EXT-001 -Action Auto
```
