---
name: extension-init
description: 在当前 PLM-Studio 工作区初始化新的原型扩展，先绑定或创建 profile，再自动分配 EXT 编号并注入适用知识。
---
# 新扩展初始化

先读取 `../../AGENTS.md`、`../../workspace.yaml` 和 `../../knowledge/_index.md`。每个新原型都是独立扩展，入口为 `skills/extension-init/run.ps1`。

## Profile 是创建前置条件

创建任何目录前，必须让用户明确选择使用现有且配置完整的 profile，或新增 profile。不得猜测 profile，也不得先创建未绑定 profile 的扩展。

新增 profile 必须执行完整交互：

1. 收集 profile ID 和显示名称；
2. 收集项目 ID、项目名称、产品名称和产品版本；
3. 让用户选择复用现有 profile 环境，或录入新的核心环境；
4. 展示项目、产品、应用服务器、Web 地址、源文件位置等摘要；
5. 用户确认后才写入 `workspace.yaml` 并创建扩展。

自动化工具必须显式传入 `-Profile`；创建 profile 时只能写入已经由用户确认的数据，并传入 `-ProfileSetupConfirmed`。所有配置通过 `Read-Config` 和 `Write-Config` 严格按 UTF-8 读写。

初始化时还要确认交付模式、演示数据来源、系统嵌入目标和原系统文件修改授权状态。新扩展初始只创建 `extension.yaml` 和 `brief.md`。

## 知识上下文门禁

扩展创建后，初始化脚本自动运行 `knowledge-context -Facet Auto`，把当前 profile、产品版本和源码指纹适用的知识注入上下文。需求明确后、开始设计前，必须根据实际内容再次加载精确 facet。页面或交互设计至少加载 `Style`；只看到知识索引而没有读取筛选后的完整记录，不能开始设计。

```powershell
powershell -NoProfile -File skills/extension-init/run.ps1 -Title "新原型" -Profile DEV -Mode static-demo -DemoData generated -NonInteractive
```
