# 从这里开始

在 PLM-Studio 中输入：

```text
/start
```

如果当前 CLI 不支持斜杠命令，运行：

```powershell
powershell -NoProfile -File .\start.ps1
```

入口会按“项目 → 产品版本 → profile → 扩展”展示状态，并引导你：

1. 新建扩展；
2. 修改任意历史扩展；
3. 继续未完成的扩展；
4. 查看工作区状态。

扩展始终是长期可迭代的容器。完成只表示当前迭代已经验收，不会让扩展退出可选列表。
