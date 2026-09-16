# 冲突：BOMCommon 父菜单运行时标签与镜像字典不一致

- **记录时间**：2026-09-15
- **状态**：Open
- **适用环境**：新大洲本田 / inforcenter 9.6 / DEV
- **环境快照**：EXT-001 最新分析会话

## 证据 A：DEV 运行时

通过“产品数据管理 → BOM管理”观察到顶层菜单显示为 **“其他操作”**；其可见子项包括：对象授权、批量授权、发送给其他用户、消息订阅、收藏。

证据：`knowledge/evidence/20260915-ext001-bom-design-view-summary.md`

## 证据 B：当前 DEV 共享镜像

`InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.menu`：

- 父 action 为 `BOMCommon`；
- 对象授权、批量授权、发送给其他用户、消息订阅都配置 `ParentWebAtionName="BOMCommon"`。

`InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.dic`：

```xml
<Label Name="BOMCommon">
  <LocalizedLabel LanguageRef="zhs">通用操作</LocalizedLabel>
</Label>
```

证据：`knowledge/evidence/20260915-ext001-pse-bom-menu-source-summary.md`

## 当前判断

父级结构可对应：运行时“其他操作”与源码 `BOMCommon` 的子项集合一致。

标签来源尚不能对应：可能存在数据库字典覆盖、客户化包覆盖、部署版本不一致或运行时缓存。尚未验证，不能以 `.dic` 的“通用操作”替换运行时“其他操作”结论。

## 处理原则

- 原型和需求继续按已验证的运行时标签 **“其他操作”** 描述。
- 原厂配置差异方案引用技术 ID `BOMCommon`，但不修改其既有中文标签。
- 在确认配置加载/客户化覆盖来源前，不将该候选知识晋升为 Verified。
