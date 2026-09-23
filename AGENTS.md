# PLM-Studio 工作区行为规范

页面原型设计还须遵循根目录 `SYSTEM.md` 定义的顾问身份、页面内容与样式约束，以及完成标准。

## 基本概念

- `PLM-Studio` 根目录是一个工作区。`workspace.yaml` 是 profile 注册表；每个 profile 描述产品版本和具体部署环境，不保存项目字段或原型默认值。工作区不存在全局活动 profile。
- 每个新原型设计都是一个扩展，位于 `extensions/EXT-nnn`。使用 `extension-init` 新建扩展，不再创建嵌套工作区。
- 用户输入 `/start`、表示开始使用 PLM-Studio，或没有明确指定新建扩展/修改哪个扩展时，必须先运行 `skills/studio-guide/run.ps1`，不能直接开始分析。
- 所有 `lifecycle.status=Active` 的扩展始终可选。状态仅表示当前迭代所处流程，不能因为 Completed 或 Accepted 拒绝继续修改扩展。
- 开始工作时读取 `workspace.yaml`、目标扩展的 `extension.yaml`、`knowledge/_index.md` 和所需 Skill。历史归档只在用户明确要求时读取。
- 每个扩展必须明确交付模式：`static`、`static-demo`、`embedded-static` 或 `backend`。校验和追问应根据交付模式调整。
- 仅优化 PLM-Studio 工作区自身的规范、脚本、Skill、模板或知识治理时，默认不得迁移、回填或修改任何既有 `extensions/EXT-nnn` 的配置、状态和产物；既有扩展只能作为只读案例或证据。只有用户明确指定修改某个扩展时，才进入该扩展的迭代流程。工作区优化也不得因此修改原 PLM 产品或部署环境。

## 标准用户流程

每次会话开始先确定分支。用户尚未选择扩展时，不能直接分析或实现。

1. `/start` 首屏只列出所有 Active 扩展的 ID 和名称，不展示 profile/环境列表；随后提示用户选择“新增扩展”或“修改现有扩展”，也允许直接输入扩展 ID。用户已经明确分支或扩展时不重复询问。只有进入新增扩展分支后，才提示选择“使用现有 profile/环境”或“新增 profile/环境”。
2. **修改现有扩展**：列出所有 Active 扩展供选择。调用 `skills/extension-iterate/run.ps1 -Extension EXT-nnn -Action Auto`。当前迭代为 Accepted/Completed 时，归档并开始下一迭代；处于 Draft、Requirements、Implementation、ChangesRequested 或 PendingUserReview 时，继续当前迭代。读取扩展绑定的 profile，不重复询问已有环境信息。
3. **新增扩展**：先让用户明确选择“使用现有 profile”或“新增 profile”。新增 profile 不收集项目，也不收集原型默认值。选择环境信息来源时，不直接展示 profile 列表；应展示所有 Active 扩展的 ID、名称、绑定环境、产品和部署模式，让用户选择复用某个历史扩展所绑定的环境，或选择逐项补充新环境。选中扩展后由系统解析其 `extension.yaml.profile`，不得让用户再次选择 profile。逐项补充新环境时采用分组式多轮引导，不要求用户填写整张表，也不得每次只问一个字段：每轮合并 2–5 个相近条目，优先让用户用一行自然语言回答；提供简短示例、候选项和推荐默认值，允许用户只回答与默认值不同的部分。建议顺序为“环境标识与产品”“部署与访问”“应用服务器与数据库”；数据库选择使用时，再补问数据库版本/产品、地址和名称。Agent 必须解析用户已经给出的信息、自动跳过不适用字段，且不得重复询问已确认内容；只有存在歧义或缺少条件必填项时才针对该组补问。字段范围包括 profile ID/环境名称、产品/版本、部署模式（`virtual-machine`、`local`、`remote-server`）、条件必填的主机地址、PLM 软件本地文件路径、可选的 Agent 可访问路径、Web 地址、应用服务器类型/版本，以及数据库是否使用、数据库版本/产品、地址和名称。数据库不单设类型字段，`database.version` 直接保存 `SQL Server 2019`、`Oracle 11g` 一类值。全部收集后展示完整摘要并取得一次确认。在 profile 决策和必要信息完整前，不得创建扩展目录。随后调用 `skills/extension-init/run.ps1`。自动化工具必须显式传入 `-Profile`，或使用 `-CreateProfile` 参数写入已经由用户交互确认的数据；不得绕过初始化器直接建立 `EXT-nnn`。
4. profile 选择完成后才创建扩展，并把 profile ID 写入扩展的 `extension.yaml.profile`。禁止通过全局状态切换 profile。
5. 两个分支在交付模式明确后都必须停留在需求阶段，主动提示用户输入本轮原型设计需求；不能因为交付模式、环境或旧扩展已经存在就直接分析页面或实现。需求必须覆盖目标、用户场景、输入和数据来源、目标模块/菜单/页面、PLM 用户点击顺序路径、技术嵌入解析顺序、页面与交互、批量数据展示方式、验收标准、约束和不在范围。需要嵌入原系统时，还要取得本扩展的原系统文件修改授权。
6. 收到需求后先写入 `extension.yaml.requirements`，只在用户明确确认摘要后设置 `workflow.requirements_confirmed=true`。随后按实际场景运行 `skills/knowledge-context/run.ps1` 注入完整知识，并运行 `skills/prototype-preflight/run.ps1 -Extension EXT-nnn`。门禁通过前不得制定原型视觉、创建页面或编写实现代码。
7. 页面和交互至少读取 `Style`；嵌入原系统读取 `Integration`；业务规则读取 `Business`；数据、接口或写入读取 `Data,Business`；环境、源码或部署分析读取 `Environment`。只读取 `knowledge/_index.md` 不算完成知识注入。多个场景同时发生时合并 facet。
8. 工作期间同步沉淀证据和可复用知识。证据充分的技术事实可立即记录；需要用户验收的业务结论保持 Candidate，不要把知识积累推迟到用户验收之后。
9. 交付前按本轮全部 facet 再次加载知识并核对产物。运行 `skills/extension-deliver/run.ps1`，将当前迭代置为 `PendingUserReview` 并输出验收清单。收到用户结果后运行 `skills/extension-review/run.ps1` 回写 `validation`，再根据证据晋升知识。Accepted 只关闭当前迭代，扩展 lifecycle 仍保持 Active。

如果用户没有返回验收结果，已经具备客观证据的知识仍正常保存；只有依赖用户结论的内容保持 Candidate。

## Profile 与初始化

- `workspace.yaml.profiles.<id>` 保存 profile 的具体信息。扩展通过 `extension.yaml.profile` 绑定 profile。
- 新建扩展前必须完成 profile 选择和验证。不得先创建未绑定 profile 的扩展，再让用户补配置。
- 交互使用 `extension-init` 时可以省略 `-Profile`，脚本会列出现有 profile 和“新增 profile”。
- CLI、Harness 和其他非交互工具应传入 `-NonInteractive -Profile <id>`。缺少 profile 时，初始化必须失败且不能留下半成品目录。
- 新 profile 必须通过对话交互完成信息收集与最终确认。可以用 `-CopyEnvironmentFrom <id>` 复用环境，或用 `-ProfileConfigPath <file>` 导入完整环境配置；无复用来源时必须收集核心环境信息。自动化执行只能写入已经确认的数据，并显式传入 `-ProfileSetupConfirmed`，该参数不能代替实际确认。
- 读取或写入 `workspace.yaml`、`extension.yaml` 以及其他配置文件时，必须调用 `scripts/Common.ps1` 中的 `Read-Config` 和 `Write-Config`，严格使用 UTF-8。禁止依赖 PowerShell 默认编码，也禁止用未指定编码的 `Get-Content`、`Set-Content` 或 `Out-File` 修改配置。
- `Read-Config` 必须拒绝无效 UTF-8；`Write-Config` 统一输出无 BOM 的 UTF-8。写入后应重新读取并确认 profile ID、环境名称、产品版本、部署模式和关键环境字段没有乱码或丢失。

## PowerShell 与文本编码

- 工作区维护的一方 `.ps1` 脚本统一保存为带 BOM 的 UTF-8，以同时兼容 Windows PowerShell 5.1 和 PowerShell 7。新增或修改脚本后必须检查严格 UTF-8 解码、BOM 和 PowerShell 语法。
- `archive` 中的历史脚本不参与当前运行规范；`node_modules` 等第三方脚本保持供应商原始内容，不进行编码重写。
- 脚本生成的配置、JSON、Markdown、源码片段和记录文件统一使用 `Read-Utf8Text`、`Write-Utf8Text`、`Add-Utf8Text`、`Read-Config` 或 `Write-Config`，写为无 BOM UTF-8。不得使用依赖 PowerShell 版本默认行为的 `Get-Content`、`Set-Content`、`Add-Content`、`Out-File` 或重定向符进行文本读写。
- 二进制文件使用 `ReadAllBytes` / `WriteAllBytes`。修改原系统已有文本文件时，应严格验证其编码并保留原文件的 BOM 状态，避免无关格式变化。
- 每次脚本编码相关修改都必须验证 Windows PowerShell 5.1 和 PowerShell 7 的入口行为，并运行工作区自测。

## 原型和演示数据

- 交付模式、演示数据来源、集成要求和原系统修改授权都在扩展需求阶段确认，并分别记录在 `extension.yaml.delivery` 与 `extension.yaml.original_system_change`；不得写入 profile。
- 自动生成的演示数据标记为 `generated`，默认仅进入原型 HTML、JSON 或 JS，不写入 PLM 数据库。用户提供的数据标记为 `user-provided` 并记录来源。
- 新扩展初始只创建 `extension.yaml` 和 `brief.md`。`prototype`、`integration`、`backend`、`evidence` 按实际需要创建。

### 原型开工、路径和样式门禁

- `target.navigation_path` 保存 PLM 产品中的用户点击顺序，例如 `系统导航 → 产品数据管理 → BOM管理 → Design`。`target.mount_sequence` 保存从导航/菜单定义、页面注册、脚本处理、容器/Iframe 到最终页面资源的技术定位顺序。两者不是文件系统路径。
- 所有原型页面必须从 knowledge 获取样式上下文。`page-style`、`design-token`、`layout`、`component` 和 `interaction` 记录必须包含 `navigation_path`；只有 workspace、产品、版本、profile 适用且点击路径精确相同的 Verified 样式可直接复用。
- 新点击路径、缺少路径或只有其他路径知识时，必须先提示用户确认是否从原产品拉取样式信息。用户同意后只读检查运行时页面或当前 manifest 内的 CSS/页面资源，提供可核对的样式摘要或预览；用户确认样式后，记录 `style_context.status=source-confirmed`、确认依据与 evidence，并新增该路径的样式 knowledge。
- 相同路径的 Verified 样式由 `prototype-preflight` 自动登记为 `knowledge-matched`。不得通过手工设置状态绕过路径核对。
- Excel 展示门禁是按需约束，不是每个扩展的必填能力。只有本轮需求实际包含 Excel/XLS/XLSX 或其他批量条目解析时，解析结果才必须优先使用原产品原生网格；无法复用时使用语义化 `table`，并明确列、固定表头、独立滚动区、空状态、逐行校验/重复状态和导入结果摘要。多列条目不得使用卡片列表，对应选择写入 `requirements.data_preview`。未涉及解析时保持 `required=false`、`mode=none`，不要求配置列或交互。

## 原系统文件修改授权

- 每个扩展都必须单独授权。工作区默认值不能代替扩展授权，一个扩展的授权也不能复用到另一个扩展。
- 修改原系统文件前，目标扩展的 `extension.yaml.original_system_change` 必须为 `status=authorized`、`snapshot_confirmed=true`，且目标位于 `approved_paths` 和 `scope` 内。
- 授权在该扩展批准范围内持续有效，不需要对每个文件重复确认。修改前记录 SHA-256 和备份；修改后记录差异、验证和回滚方式。
- 超出范围、涉及数据库、后端或接口写入时，必须暂停并重新取得确认。
- InforCenter 项目如需重启 IIS、应用程序池、业务 Windows 服务，应先说明影响、验证和回滚方式，由用户手动执行。不得自动执行 `iisreset`、应用池回收、`Restart-Service` 或修改远程服务配置。

## 源文件和浏览器工具

- `source-sync` 只把远程源复制到 `sources/mirror/<profile>`，支持按目录或文件范围同步。不得写入或删除源文件，也不得执行源目录中的命令。
- `sources/manifests/<EXT-nnn>` 保存扩展的同步范围、哈希和源指纹。没有对应扩展当前 manifest 的镜像内容不能作为当前证据。
- 浏览器检查是工作区共享工具，位于 `tools/browser`，由所有扩展复用，不为每个扩展重复下载。

## 知识治理

### 知识上下文门禁

- 进入具体扩展的需求分析、设计、实现、缺陷修复或交付检查时，必须运行 `skills/knowledge-context/run.ps1 -Extension EXT-nnn -Facet <范围>` 并完整读取输出。新增扩展和进入迭代的标准脚本会先自动执行 `Auto`；需求明确后必须按实际场景再次执行精确 facet。
- `Style` 适用于样式、布局、字体、颜色、密度、组件、按钮、菜单、弹窗、图标和交互；`Integration` 适用于菜单机制、挂载点、页面注册、文件引用和资源加载；`Business` 适用于流程、权限、状态和校验；`Data` 适用于演示数据、对象属性、数据库、接口和写入；`Environment` 适用于 profile、浏览器、源码、部署和运行环境。
- 输出中适用范围匹配的 Verified 知识是默认设计约束。Style 知识还必须与 `target.navigation_path` 精确匹配；非 Style 技术知识继续核对源码指纹。模型必须在方案中依据这些知识，不能重新发明相冲突的样式或机制。
- Candidate、指纹未确认或适用范围不完整的知识只能用于提问和验证，不能当成事实。Deprecated 和范围不匹配的知识禁止采用。
- 用户明确要求偏离 Verified 知识时，用户要求优先；必须指出偏离项、影响和验证方式，并把新证据纳入本轮知识积累，不能静默忽略旧知识。
- 切换扩展/profile、开始新迭代，或模块、页面、交付模式、主题、角色、产品版本、源码指纹、用户反馈发生变化时，必须重新注入相关知识。
- 仅维护工作区目录、查看列表、清理缓存或维护不涉及产品决策的通用工具时，不需要加载扩展知识。

- 知识状态使用 `Candidate / Verified / Deprecated`，必须包含 applicability、category、evidence、最近验收、来源指纹和验证时间。样式知识还必须包含 `navigation_path`；集成知识必须在正文或元数据中包含 `mount_sequence`。
- `page-style`、`mount-point`、`menu-mechanism` 等可复现且可追溯的技术事实，在证据充分后可在对应产品版本范围内直接晋升为 Verified。
- `business-flow`、`write-operation` 等业务路径、权限和写入时机必须等待业务验收和回写证据。
- 每次工作更新 `knowledge/_index.md` 和 `knowledge/changelog.md`。冲突写入 `knowledge/contradictions`；旧记录保留并标记 Deprecated，不直接删除。
- 跨产品和版本的知识只作为候选参考。源码或环境变化时必须重新验证受影响知识。

## 归档原则

- 迁移、重构和目录清理前归档关键配置、扩展、知识和证据。缓存、构建产物、重复下载、临时报告、无引用生成物和空目录可以删除。
- `archive` 保存历史，不作为当前默认知识入口。
