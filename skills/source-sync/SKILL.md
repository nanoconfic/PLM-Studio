---
name: source-sync
description: 发现共享源码并按指定目录或文件范围建立只读增量镜像。
---
# source-sync

先阅读 `../../AGENTS.md` 和 `../../workspace.yaml`。

必须传入 `-Extension`，工具从扩展读取绑定的 profile。优先使用 `-Scope` 同步本次扩展需要的目录或文件，避免全量扫描。各扩展的清单分别保存在 `sources/manifests/<EXT-nnn>`，并行会话不会覆盖彼此的证据清单。

## 可执行入口

`powershell -NoProfile -File skills/source-sync/run.ps1 -Extension EXT-001 -Scope 'InforCenter/PSE/Bom'`
