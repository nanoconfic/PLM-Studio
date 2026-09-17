# PLM-Studio

PLM-Studio 根目录就是一个工作区。每个新的原型设计是一个独立扩展，以 `EXT-nnn` 编号保存。

## 快速开始

1. 在代码仓库页面选择 **Code → Download ZIP**。
2. 将下载的压缩包解压到本地目录。
3. 使用本地 Agent 工具（如 Pi、Codex 或 Harness）打开解压后的 `PLM-Studio` 工作区。
4. 在 Agent 对话中输入 `/start`，按引导新增扩展或选择已有扩展。

首次使用时 `workspace.yaml` 可以保持空 profile 注册表；`/start` 会引导你在新增扩展时补充自己的环境信息。请不要把包含真实环境、账号、源码镜像或知识快照的工作区直接分享给他人。


## 目录

```text
PLM-Studio/
├─ workspace.yaml              profile 注册表；每个 profile 保存产品版本和部署环境
├─ extensions/                 每个原型设计及其交付、授权、部署历史
├─ knowledge/                  已验证知识、证据、冲突和环境快照
├─ sources/                    只读源码镜像和范围化 manifest
├─ runtime/                    浏览器截图等可重新生成的运行产物
├─ tools/browser/              所有扩展共享的 Chromium 介质与运行时
├─ skills/                     工作流入口
├─ scripts/                    公共实现与自检
├─ templates/                  新扩展和知识记录模板
└─ archive/                    迁移和重置归档，不作为当前入口
```


## 标准会话流程

1. 先选择迭代某个现有扩展，或新增扩展。
2. 现有扩展：全部可以选择。已验收的开启下一轮，未完成的继续当前轮；读取绑定 profile，不重复询问环境。
3. 新增扩展：调用 `skills/extension-init/run.ps1`；随后选择已有 profile 或补充新 profile，再完成同一组需求问题。
4. 工作中同步保存证据和知识，满足条件时立即晋升，不等用户最终验收。
5. 交付后提示用户检查并反馈；反馈反写到扩展 `validation`，作为下一轮迭代和依赖验收的知识依据。


## 每扩展一次的原系统修改授权

每个扩展的授权保存在自己的 `extension.yaml.original_system_change`。只有以下条件全部满足才能修改原系统文件：

1. `status` 为 `authorized`；
2. `snapshot_confirmed` 为 `true`；
3. 修改目标位于 `approved_paths` 和 `scope` 内。

授权仅对该扩展有效。批准范围内不再逐文件确认；超出范围、数据库写入、后端或接口写入仍需重新确认。修改前必须保存哈希和备份。InforCenter 的 IIS、应用池及业务服务由用户手工重启。


## 知识

通用页面风格、挂载点和菜单机制在证据充分时可直接晋升 `Verified`。业务流程、写入、数据库和接口行为仍需完整验证。所有记录都要明确产品版本、profile、证据、源指纹和适用限制。


