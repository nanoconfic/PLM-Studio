# PLM-Studio 工作区行为规范

## 基本概念

- `PLM-Studio` 根目录是一个工作区。`workspace.yaml` 是 profile 注册表；每个 profile 描述项目、产品版本和具体环境信息。工作区不存在全局活动 profile。
- 每个新原型设计都是一个扩展，位于 `extensions/EXT-nnn`。使用 `extension-init` 新建扩展，不再创建嵌套工作区。
- 用户输入 `/start`、表示开始使用 PLM-Studio，或没有明确指定新建扩展/修改哪个扩展时，必须先运行 `skills/studio-guide/run.ps1`，不能直接开始分析。
- 所有 `lifecycle.status=Active` 的扩展始终可选。状态仅表示当前迭代所处流程，不能因为 Completed 或 Accepted 拒绝继续修改扩展。
- 开始工作时读取 `workspace.yaml`、目标扩展的 `extension.yaml`、`knowledge/_index.md` 和所需 Skill。历史归档只在用户明确要求时读取。
- 每个扩展必须明确交付模式：`static`、`static-demo`、`embedded-static` 或 `backend`。校验和追问应根据交付模式调整。

## 标准用户流程

每次会话开始先确定分支。用户尚未选择扩展时，不能直接分析或实现。

1. 询问用户是新增扩展，还是修改现有扩展。用户已经明确时不重复询问。
2. **修改现有扩展**：列出所有 Active 扩展供选择。调用 `skills/extension-iterate/run.ps1 -Extension EXT-nnn -Action Auto`。当前迭代为 Accepted/Completed 时，归档并开始下一迭代；处于 Draft、Requirements、Implementation、ChangesRequested 或 PendingUserReview 时，继续当前迭代。读取扩展绑定的 profile，不重复询问已有环境信息。
3. **新增扩展**：先让用户明确选择“使用现有 profile”或“新增 profile”。新增 profile 必须沿用引导式交互：依次收集 profile ID/名称、项目、产品和版本，再让用户选择复用哪个现有 profile 的环境信息或逐项补充新环境；最后展示完整摘要并取得确认。在 profile 决策和必要信息完整前，不得创建扩展目录。随后调用 `skills/extension-init/run.ps1`。自动化工具必须显式传入 `-Profile`，或使用 `-CreateProfile` 参数写入已经由用户交互确认的数据；不得绕过初始化器直接建立 `EXT-nnn`。
4. profile 选择完成后才创建扩展，并把 profile ID 写入扩展的 `extension.yaml.profile`。禁止通过全局状态切换 profile。
5. 两个分支都必须在开始实现前补齐本轮原型需求：目标、用户场景、输入和数据来源、目标模块/菜单/页面、交付模式、页面与交互要求、验收标准、约束和不在范围。需要嵌入原系统时，还要取得本扩展的原系统文件修改授权。
6. 需求范围明确后、制定设计或编写代码前，运行 `skills/knowledge-context/run.ps1`，按本轮场景把适用知识的完整内容注入当前上下文。只读取 `knowledge/_index.md` 不算完成知识注入。页面和交互至少读取 `Style`；嵌入原系统读取 `Integration`；业务规则读取 `Business`；数据、接口或写入读取 `Data,Business`；环境、源码或部署分析读取 `Environment`。多个场景同时发生时合并 facet。
7. 工作期间同步沉淀证据和可复用知识。证据充分的技术事实可立即记录；需要用户验收的业务结论保持 Candidate，不要把知识积累推迟到用户验收之后。
8. 交付前按本轮全部 facet 再次加载知识并核对产物。运行 `skills/extension-deliver/run.ps1`，将当前迭代置为 `PendingUserReview` 并输出验收清单。收到用户结果后运行 `skills/extension-review/run.ps1` 回写 `validation`，再根据证据晋升知识。Accepted 只关闭当前迭代，扩展 lifecycle 仍保持 Active。

如果用户没有返回验收结果，已经具备客观证据的知识仍正常保存；只有依赖用户结论的内容保持 Candidate。

## Profile 与初始化

- `workspace.yaml.profiles.<id>` 保存 profile 的具体信息。扩展通过 `extension.yaml.profile` 绑定 profile。
- 新建扩展前必须完成 profile 选择和验证。不得先创建未绑定 profile 的扩展，再让用户补配置。
- 交互使用 `extension-init` 时可以省略 `-Profile`，脚本会列出现有 profile 和“新增 profile”。
- CLI、Harness 和其他非交互工具应传入 `-NonInteractive -Profile <id>`。缺少 profile 时，初始化必须失败且不能留下半成品目录。
- 新 profile 必须通过对话交互完成信息收集与最终确认。可以用 `-CopyEnvironmentFrom <id>` 复用环境，或用 `-ProfileConfigPath <file>` 导入完整环境配置；无复用来源时必须收集核心环境信息。自动化执行只能写入已经确认的数据，并显式传入 `-ProfileSetupConfirmed`，该参数不能代替实际确认。
- 读取或写入 `workspace.yaml`、`extension.yaml` 以及其他配置文件时，必须调用 `scripts/Common.ps1` 中的 `Read-Config` 和 `Write-Config`，严格使用 UTF-8。禁止依赖 PowerShell 默认编码，也禁止用未指定编码的 `Get-Content`、`Set-Content` 或 `Out-File` 修改配置。
- `Read-Config` 必须拒绝无效 UTF-8；`Write-Config` 统一输出无 BOM 的 UTF-8。写入后应重新读取并确认 profile ID、项目、产品版本和关键环境字段没有乱码或丢失。

## PowerShell 与文本编码

- 工作区维护的一方 `.ps1` 脚本统一保存为带 BOM 的 UTF-8，以同时兼容 Windows PowerShell 5.1 和 PowerShell 7。新增或修改脚本后必须检查严格 UTF-8 解码、BOM 和 PowerShell 语法。
- `archive` 中的历史脚本不参与当前运行规范；`node_modules` 等第三方脚本保持供应商原始内容，不进行编码重写。
- 脚本生成的配置、JSON、Markdown、源码片段和记录文件统一使用 `Read-Utf8Text`、`Write-Utf8Text`、`Add-Utf8Text`、`Read-Config` 或 `Write-Config`，写为无 BOM UTF-8。不得使用依赖 PowerShell 版本默认行为的 `Get-Content`、`Set-Content`、`Add-Content`、`Out-File` 或重定向符进行文本读写。
- 二进制文件使用 `ReadAllBytes` / `WriteAllBytes`。修改原系统已有文本文件时，应严格验证其编码并保留原文件的 BOM 状态，避免无关格式变化。
- 每次脚本编码相关修改都必须验证 Windows PowerShell 5.1 和 PowerShell 7 的入口行为，并运行工作区自测。

## 原型和演示数据

- profile 默认偏好记录在 `workspace.yaml.profiles.<id>.prototype_defaults`；扩展的实际决定记录在 `extension.yaml.delivery`。不要根据目录是否存在推断。
- 自动生成的演示数据标记为 `generated`，默认仅进入原型 HTML、JSON 或 JS，不写入 PLM 数据库。用户提供的数据标记为 `user-provided` 并记录来源。
- 新扩展初始只创建 `extension.yaml` 和 `brief.md`。`prototype`、`integration`、`backend`、`evidence` 按实际需要创建。

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
- 输出中适用范围和源码指纹均匹配的 Verified 知识是默认设计约束。模型必须在方案中依据这些知识，不能重新发明相冲突的样式或机制。
- Candidate、指纹未确认或适用范围不完整的知识只能用于提问和验证，不能当成事实。Deprecated 和范围不匹配的知识禁止采用。
- 用户明确要求偏离 Verified 知识时，用户要求优先；必须指出偏离项、影响和验证方式，并把新证据纳入本轮知识积累，不能静默忽略旧知识。
- 切换扩展/profile、开始新迭代，或模块、页面、交付模式、主题、角色、产品版本、源码指纹、用户反馈发生变化时，必须重新注入相关知识。
- 仅维护工作区目录、查看列表、清理缓存或维护不涉及产品决策的通用工具时，不需要加载扩展知识。

- 知识状态使用 `Candidate / Verified / Deprecated`，必须包含 applicability、category、evidence、最近验收、来源指纹和验证时间。
- `page-style`、`mount-point`、`menu-mechanism` 等可复现且可追溯的技术事实，在证据充分后可在对应产品版本范围内直接晋升为 Verified。
- `business-flow`、`write-operation` 等业务路径、权限和写入时机必须等待业务验收和回写证据。
- 每次工作更新 `knowledge/_index.md` 和 `knowledge/changelog.md`。冲突写入 `knowledge/contradictions`；旧记录保留并标记 Deprecated，不直接删除。
- 跨产品和版本的知识只作为候选参考。源码或环境变化时必须重新验证受影响知识。

## 归档原则

- 迁移、重构和目录清理前归档关键配置、扩展、知识和证据。缓存、构建产物、重复下载、临时报告、无引用生成物和空目录可以删除。
- `archive` 保存历史，不作为当前默认知识入口。
