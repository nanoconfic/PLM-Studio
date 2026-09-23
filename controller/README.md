# Workspace Controller

`run.ps1` 是自然语言 Agent 的统一状态入口；无扩展参数时列出 `prototype`、`integration`、`linked` 三种能力和 Active 扩展。`actions.ps1` 列出受控动作，`requirements.ps1` 生成当前阶段的缺失问题，`state-machine.ps1` 计算允许与阻止的动作，`guards.ps1` 为执行脚本提供拒绝门禁。

Controller 只读取 `extensions/EXT-nnn/extension.yaml`，不保存第二份状态。`capability_mode` 决定本轮能力组合，`stage` 决定当前处理原型还是嵌入，`phase` 决定需求、实现与验收门禁。联动模式的原型验收通过后转入嵌入需求阶段。各 Skill 的兼容入口位于 `skills/<name>/run.ps1`，实际执行脚本位于 `tools/`。所有直接修改扩展产物的动作须先经过 Controller，并继续满足对应 Skill 的细节检查。
