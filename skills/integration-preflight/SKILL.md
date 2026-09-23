---
name: integration-preflight
description: 嵌入原 PLM 系统前核对静态页面、点击路径、挂载顺序、环境及文件修改范围。
---
# integration-preflight

仅在 `workflow.stage=integration`、用户确认嵌入需求后运行。先按 `Integration,Environment,Business` 注入知识，核对页面来源、原产品点击路径、菜单到页面资源的挂载顺序、环境、快照和批准范围。运行 `skills/integration-preflight/run.ps1 -Extension EXT-nnn`；门禁通过后才可改原系统文件。

修改前记录 SHA-256 和备份，修改后将变更路径、验证和回滚方式写入 `integration_evidence`。超出批准范围、数据库或后端写入须重新确认；InforCenter 服务重启由用户手动执行。
