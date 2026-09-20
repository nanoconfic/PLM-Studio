---
name: extension-init
description: 在当前 PLM-Studio 工作区初始化新的原型扩展，先绑定或创建 profile，再自动分配 EXT 编号并注入适用知识。
---
# 新扩展初始化

先读取 `../../AGENTS.md`、`../../workspace.yaml` 和 `../../knowledge/_index.md`。每个新原型都是独立扩展，入口为 `skills/extension-init/run.ps1`。

## Profile 是创建前置条件

创建任何目录前，必须让用户明确选择使用现有且配置完整的 profile，或新增 profile。不得猜测 profile，也不得先创建未绑定 profile 的扩展。

新增 profile 必须执行完整交互：

1. 不收集项目，也不收集原型默认值；这些信息不属于 profile。
2. 环境信息来源必须按历史扩展展示，而不是直接列出 profile：列出所有 Active 扩展的 ID、名称、绑定环境、产品和部署模式，让用户选择一个扩展并复用其绑定环境，或录入新环境。
3. 新环境采用分组式多轮引导，不展示整张表，也不逐字段单独追问。每轮合并 2–5 个相近条目，给出简短示例、候选项和推荐默认值，允许用户用一句自然语言同时回答，并只说明与默认值不同的部分。
4. 推荐分组为：① 环境 ID、环境名称、产品和版本；② 部署模式、条件必填的主机地址、PLM 软件本地文件路径、可选的 Agent 可访问路径和 Web 地址；③ 应用服务器类型/版本及是否使用数据库。只有数据库选择使用时，才增加一轮收集数据库版本/产品、地址和名称。
5. Agent 必须从用户自由表达中提取字段，保留已确认信息，跳过不适用字段，不得重复询问。只有当前分组存在歧义或缺少条件必填项时才补问；用户提供的信息超出当前分组时也应直接记录，后续不再询问。
6. `local` 自动使用 `localhost`；`virtual-machine` 和 `remote-server` 的主机地址必填。数据库不单设类型字段，版本/产品字段直接填写 `SQL Server 2019`、`Oracle 11g` 一类值。
7. VM 或远程服务器中的 PLM 本地路径不等于 Agent 可访问路径。`source.access_path` 在首次创建时可留空；用户已知 UNC 共享路径时可一并填写。
8. 全部收集后展示产品、部署模式、主机、PLM 软件本地文件路径、应用服务器、Web 和数据库摘要，只进行一次最终确认；确认后才写入 `workspace.yaml` 并创建扩展。

自动化工具必须显式传入 `-Profile`；创建 profile 时只能写入已经由用户确认的数据，并传入 `-ProfileSetupConfirmed`。所有配置通过 `Read-Config` 和 `Write-Config` 严格按 UTF-8 读写。

用户选中历史扩展后，读取该扩展的 `extension.yaml.profile`，将对应 profile 作为 `-CopyEnvironmentFrom` 的值；不要再向用户展示或询问 profile ID。交付模式、演示数据、集成要求和原系统修改授权在扩展需求阶段写入 `extension.yaml`，不得从 profile 推断。

初始化时还要确认交付模式、演示数据来源、系统嵌入目标和原系统文件修改授权状态。新扩展初始只创建 `extension.yaml` 和 `brief.md`。

## 交付模式之后必须停在需求阶段

交付模式明确后，只能创建扩展骨架并进入 `Requirements`。必须提示用户提供本轮原型设计需求，记录目标、场景、输入、PLM 点击顺序路径、技术嵌入顺序、页面与交互、批量数据展示方式、验收标准、约束和不做范围。收到并确认这些需求之前，不得开始页面结构、视觉设计或代码实现。

需求确认后运行 `skills/prototype-preflight/run.ps1 -Extension EXT-nnn`。门禁未通过时继续补齐需求或样式来源，不得绕过。

## 知识上下文门禁

扩展创建后，初始化脚本自动运行 `knowledge-context -Facet Auto`，此时仅用于发现已有知识，不能替代需求确认。需求明确后、开始设计前，必须根据实际内容再次加载精确 facet。页面或交互设计至少加载 `Style`；只看到知识索引而没有读取筛选后的完整记录，不能开始设计。

`target.navigation_path` 保存用户在 PLM 中的点击顺序；`target.mount_sequence` 保存菜单、页面注册、脚本、Iframe/容器和目标页面的技术解析顺序。样式知识只有在 `navigation_path` 精确相同时才能直接复用；新路径必须先询问用户是否从原产品拉取样式，获得确认后把证据写入 `style_context` 和 knowledge。

```powershell
powershell -NoProfile -File skills/extension-init/run.ps1 -Title "新原型" -Profile DEV -Mode static-demo -DemoData generated -NonInteractive
```
