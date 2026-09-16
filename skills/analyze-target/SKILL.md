---
name: analyze-target
description: 按扩展交付模式检查目标环境、入口和源码，并先注入环境与集成知识。
---
# 目标分析

读取交付模式、扩展绑定的 profile 和适用知识。纯静态模式只验证原型自身信息；嵌入或后端模式再检查目标环境、入口和源码。分析结论及证据写入扩展的 `evidence.md`。环境和源码取证按需执行，不是每个扩展的强制步骤。

脚本在环境分析前自动注入 `Environment`；存在模块、菜单、页面目标或嵌入/后端交付时，同时注入 `Integration`。适用范围或源码指纹不匹配的旧记录不能作为分析结论。

```powershell
powershell -NoProfile -File skills/analyze-target/run.ps1 -Extension EXT-001
```
