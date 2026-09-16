# PLM-Studio

PLM-Studio 根目录就是一个工作区。每个新的原型设计是一个独立扩展，以 `EXT-nnn` 编号保存。

## 唯一入口

在对话中输入 `/start`。如果 CLI 不支持斜杠命令，运行：

```powershell
powershell -NoProfile -File .\start.ps1
```

入口按项目、产品版本、profile 和扩展展示状态。所有 Active 扩展始终可以选择；状态只决定继续当前迭代还是开启下一轮。

## 目录

```text
PLM-Studio/
├─ workspace.yaml              profile 注册表；每个 profile 保存产品版本、环境和默认策略
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

## 新扩展初始化

```powershell
powershell -NoProfile -File .\skills\extension-init\run.ps1 `
  -Title "新原型" -Profile DEV -Mode static-demo -DemoData generated
```

交付模式：

- `static`：纯静态原型，不要求 IIS、源码或数据库。
- `static-demo`：静态原型和演示数据；数据来源为 `user-provided` 或 `generated`。
- `embedded-static`：嵌入现有系统的前端原型，需要目标页面、Web 和源码环境。
- `backend`：包含后端实现，需要明确批准及数据库信息。

若尚未选择 profile，可以先省略 `-Profile`；脚本会列出已配置 profile，随后由用户选择或补充新环境。扩展一旦绑定 profile，后续检查、源码、浏览器和快照都使用该绑定，不存在会影响其他会话的全局环境切换。若没有传入模式，脚本使用绑定 profile 的 `prototype_defaults`。

## 标准会话流程

1. 先选择迭代某个现有扩展，或新增扩展。
2. 现有扩展：全部可以选择。已验收的开启下一轮，未完成的继续当前轮；读取绑定 profile，不重复询问环境。
3. 新增扩展：调用 `skills/extension-init/run.ps1`；随后选择已有 profile 或补充新 profile，再完成同一组需求问题。
4. 工作中同步保存证据和知识，满足条件时立即晋升，不等用户最终验收。
5. 交付后提示用户检查并反馈；反馈反写到扩展 `validation`，作为下一轮迭代和依赖验收的知识依据。

现有扩展开启新一轮迭代：

```powershell
powershell -NoProfile -File .\skills\extension-iterate\run.ps1 -Extension EXT-001
```

用户检查后反写结果：

```powershell
powershell -NoProfile -File .\skills\extension-review\run.ps1 `
  -Extension EXT-001 -Result Accepted -Feedback "检查通过"
```

交付并进入用户检查：

```powershell
powershell -NoProfile -File .\skills\extension-deliver\run.ps1 `
  -Extension EXT-001 -Summary "本轮已完成" -Artifact "prototype/index.html"
```

## 每扩展一次的原系统修改授权

每个扩展的授权保存在自己的 `extension.yaml.original_system_change`。只有以下条件全部满足才能修改原系统文件：

1. `status` 为 `authorized`；
2. `snapshot_confirmed` 为 `true`；
3. 修改目标位于 `approved_paths` 和 `scope` 内。

授权仅对该扩展有效。批准范围内不再逐文件确认；超出范围、数据库写入、后端或接口写入仍需重新确认。修改前必须保存哈希和备份。InforCenter 的 IIS、应用池及业务服务由用户手工重启。

## 环境检查

```powershell
# 只检查工作区基本信息
powershell -NoProfile -File .\skills\workspace-doctor\run.ps1

# 按扩展交付模式检查
powershell -NoProfile -File .\skills\workspace-doctor\run.ps1 -Extension EXT-001
```

静态模式不会要求后端、数据库、IIS、源码或浏览器。嵌入和后端模式才检查对应环境。

## 范围化源码同步

```powershell
powershell -NoProfile -File .\skills\source-sync\run.ps1 -Extension EXT-001 -DiscoverOnly
powershell -NoProfile -File .\skills\source-sync\run.ps1 `
  -Extension EXT-001 -Scope 'InforCenter/PSE/Bom','Base/Ctrls/MenuToolbar'
```

同步只读取 `workspace.yaml` 中的源目录，写入 `sources/mirror/<profile>`，不回写、不删除远程文件。manifest 会记录同步范围；未进入当前 manifest 的镜像文件不能作为当前证据。

## 共享浏览器

Chromium 位于：

```text
tools/browser/chromium/chrome-win64/chrome.exe
```

原始压缩包保存在 `tools/browser/media/chrome-win64.zip`。所有扩展共用这一份浏览器：

```powershell
powershell -NoProfile -File .\skills\browser-inspect\run.ps1 -Extension EXT-001 -Initialize
powershell -NoProfile -File .\skills\browser-inspect\run.ps1 -Extension EXT-001 -Run
```

`-Initialize` 只准备工作区级依赖和解压本地介质，不再调用 Playwright 下载 Chromium。

## 知识

通用页面风格、挂载点和菜单机制在证据充分时可直接晋升 `Verified`。业务流程、写入、数据库和接口行为仍需完整验证。所有记录都要明确产品版本、profile、证据、源指纹和适用限制。

## 自检

```powershell
powershell -NoProfile -File .\scripts\self-test.ps1
```

自检在临时目录运行，不访问真实 PLM 或共享目录。
