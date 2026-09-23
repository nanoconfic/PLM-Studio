# PLM-Studio

PLM-Studio 根目录就是一个工作区。每个任务是一个可长期迭代的 `EXT-nnn` 扩展，可选择只做原型、只嵌入已有静态页，或原型验收后再嵌入 PLM。

## 快速开始

1. 在代码仓库页面选择 **Code → Download ZIP**。
2. 将下载的压缩包解压到本地目录。
3. 使用本地 Agent 工具（如 Pi、Codex 或 Harness）打开解压后的 `PLM-Studio` 工作区。
4. 直接用自然语言描述任务，例如“做一个颜色件查询原型”“把这个 HTML 页面嵌入 BOM 菜单”，或“先做原型，确认后嵌入”。Agent 会读取 Controller 状态并只追问缺失信息。


## 目录

```text
PLM-Studio/
├─ workspace.yaml              Git 提交的空工作区壳，不含环境配置
├─ workspace.local.yaml        本机 profile 配置，Git 忽略
├─ extensions/                 每个原型设计及其交付、授权、部署历史
├─ knowledge/                  已验证知识、证据、冲突和环境快照
├─ sources/                    源码同步范围与 manifest
├─ agents/                     自然语言入口和 Agent 职责
├─ controller/                 状态机、动作与门禁
├─ skills/                     工作流说明及兼容入口
├─ tools/                      命令、配置、源码、浏览器与所属模板
├─ scripts/                    旧入口和浏览器依赖
└─ AGENTS.md                   工作区使用规则
```

`controller/` 中的 `run.ps1`、`state-machine.ps1`、`guards.ps1`、`actions.ps1` 分别承担查询入口、状态判定、执行门禁和动作清单。实际执行脚本按职责放在 `tools/{workspace,extension,config,source,prototype,knowledge,validation,delivery,browser}/`。`skills/<name>/SKILL.md` 保留每项工作的操作规范，原 `run.ps1` 作为兼容入口转发到 `tools/`。

现有 `runtime/` 与浏览器依赖目录暂沿用原路径，避免中断正在使用的扩展和浏览器安装；新增结构没有迁移或回填既有 `extensions/EXT-nnn`。

## 本地环境配置

仓库中的 `workspace.yaml` 只保存 `workspace_id` 和空 `profiles`。本机完整环境配置保存在 `workspace.local.yaml`，该文件已被 Git 忽略。`Get-Workspace` 自动把本地配置覆盖到仓库壳上，因此 `git pull`、分支切换和同步不会删除或覆盖本机环境信息。


## 标准会话流程

自然语言请求由 Agent 解析为扩展和能力模式。`controller/run.ps1 -Json` 返回三个入口模式和 Active 扩展；选定扩展后返回 `capability_mode`、`stage`、`phase`、`allowed`、`blocked` 与 `missing`。`-Action implement` 等检查动作并在拒绝时返回非零退出码。现有 `skills/<name>/run.ps1` 保留为兼容入口，实际 PowerShell 实现位于 `tools/`。

```text
用户 → PLM Agent → Workspace Controller → Skill → Tool
                           ↓
                 Extension 状态 / Knowledge 事实
```

| 模式 | 需求与门禁 | 完成条件 |
| --- | --- | --- |
| `prototype` | 确认数据来源、后端需求、页面交互及样式路径；运行 `prototype-preflight` | 静态 HTML 验收通过 |
| `integration` | 指定已有 HTML、PLM 点击路径、挂载顺序、环境和修改范围；运行 `integration-preflight` | 嵌入证据与原产品操作验收通过 |
| `linked` | 先完成原型阶段；原型验收后自动进入嵌入需求阶段 | 两个阶段分别验收通过 |

原型设计始终加载适用的 `Style` 知识；嵌入原产品加载 `Integration,Environment,Business`。修改原系统文件时记录快照、哈希、差异、验证和回滚。旧扩展继续按 `legacy` 流程解释，无需迁移。


## 每扩展一次的原系统修改授权

每个扩展的授权保存在自己的 `extension.yaml.original_system_change`。只有以下条件全部满足才能修改原系统文件：

1. `status` 为 `authorized`；
2. `snapshot_confirmed` 为 `true`；
3. 修改目标位于 `approved_paths` 和 `scope` 内。

授权仅对该扩展有效。批准范围内不再逐文件确认；超出范围、数据库写入、后端或接口写入仍需重新确认。修改前必须保存哈希和备份。InforCenter 的 IIS、应用池及业务服务由用户手工重启。


## 知识

通用页面风格、挂载点和菜单机制在证据充分时可直接晋升 `Verified`。业务流程、写入、数据库和接口行为仍需完整验证。所有记录都要明确产品版本、profile、证据、源指纹和适用限制。
