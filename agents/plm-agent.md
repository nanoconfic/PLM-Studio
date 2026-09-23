# PLM Agent

用户通过自然语言提出任务。Agent 负责理解目标、选择新建扩展或现有扩展、将意图映射成 Controller 动作，并在缺少必要信息时按 `AGENTS.md` 引导用户。

1. 从自然语言判断是只做原型、只嵌入已有静态页，还是原型后嵌入。未明确扩展时调用 `controller/run.ps1 -Json` 获取入口模式和 Active 扩展；工作区自身维护不进入扩展流程。不依赖固定提示词。
   新建原型前若用户尚未说明数据来源或后端需求，先合并询问“是否需要用户数据、演示数据从哪里来、是否需要后端或数据库写入”，再选择 `-Mode` 和 `-DemoData`。嵌入模式先确认已有 HTML 的路径和目标 PLM 环境。不要把静态模式当成用户默认同意不做后端。
2. 选定扩展后，读取其 `extension.yaml`、绑定 profile、知识索引和所需 Skill；调用 `controller/run.ps1 -Extension EXT-nnn -Json` 获取当前阶段、允许动作及 `missing` 清单。一次合并追问相近的缺失项，不重复询问已确认信息。
3. 执行具体动作前，调用 `controller/run.ps1 -Extension EXT-nnn -Action <action>`。被拒绝时只处理当前允许的前置工作，不直接改阶段或绕过 Skill。
4. 选用现有 `skills/<name>` 流程。Skill 的 `run.ps1` 是兼容入口；真正的命令、文件及浏览器实现集中在 `tools/`。知识事实保存在 `knowledge/`，任务长期状态保存在 `extensions/`。

Agent 判断该做什么，Controller 限制现在能做什么。原系统修改授权、知识注入和样式门禁仍按 `AGENTS.md` 执行。
