---
id: "KNOW-EXT001-IC96-BOM-MENU-INTEGRATION"
status: Verified
category: menu-mechanism
applicability:
  workspace_id: "xindazhou-honda-inforcenter-9.6"
  project: "新大洲本田"
  product: "inforcenter"
  version: "9.6"
  profiles: ["DEV"]
  source_fingerprint: "9285FAED8B19556A5BEC48887BDF48FC046240C7964074C49D56997AB422D78D"
  constraints:
    - "Verified for ProductBOM / PseBomMenu in the current DEV source and deployed runtime."
    - "The runtime label is 其他操作; the technical parent ID is BOMCommon."
    - "Do not assume the same menu relation for ProductBOMTree, baseline BOM, other menus, profiles, themes, roles, or product versions."
evidence:
  - "knowledge/evidence/20260915-ext001-bom-design-view-summary.md"
  - "knowledge/evidence/20260915-ext001-pse-bom-menu-source-summary.md"
  - "extensions/EXT-001/deployment-report-20260916-082850.md"
  - "knowledge/contradictions/20260915-bomcommon-label-runtime-vs-source.md"
environment_snapshot: "knowledge/environment-snapshots/20260916-090431-276-b6a159.yaml"
verified_at: "2026-09-16"
supersedes: null
---
# InforCenter 9.6 ProductBOM 菜单操作集成点

## Verified 结论

在当前 DEV 的 BOM 管理 `ProductBOM` 页面中，菜单集成链如下：

```text
ProductBOM.page
  → PSEBom.menurelation
    → PseBomMenu
      → BOMCommon（运行时显示：其他操作）
        → 同级 WebAction
```

将新的 BOM 页面操作放入运行时“其他操作”分组时，应在：

```text
InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.menu
```

新增同级 `WebAction`，并设置：

```xml
ParentWebAtionName="BOMCommon"
```

需为 action 提供唯一 `Name`、顺序 `Order`、本地化 `LabelName`、图标、选择范围和前端/页面处理方式；JS 资源通过：

```text
InforCenter/PSE/Bom/Config/PSEBomFileRef.fileref
```

登记。页面到菜单的关系由：

```text
InforCenter/PSE/Bom/Config/UIConfig/PSEBom.menurelation
```

维护，`ProductBOM` 对应 `PseBomMenu`。

## 已验证的最小演示模式

EXT-001 已部署并通过用户验收的 action：

```text
Name: TrialToMassProductionDemo
ParentWebAtionName: BOMCommon
Order: 2600
JS: InforCenter_Custom_TrialToMassProduction_OpenDemo
```

它传递当前树节点的物料编码、名称、主 ID、视图 ID、视图类型和树列表 ID，仅进行车型正则校验与只读演示页打开，不调用 BOM 写入服务。

## 选择上下文参数

当前 `PseBomMenu` action 已验证可使用：

```text
[TreeList_Current_ECODE]
[TreeList_Current_ENAME]
[TreeList_Current_MASTERID$]
[TreeList_Current_PSEITEMVIEWEID]
[TreeList_Current_PSEITEMVIEWVIEWTYPE]
[TREELISTID]
```

新动作应按业务需要使用最少参数；涉及写入时仍必须独立确认权限、检出、事务、审计、接口和补偿方案。

## 标签差异与限制

技术父级为 `BOMCommon` 已验证；当前 DEV 运行时显示“其他操作”，而镜像标准字典将 `BOMCommon` 写作“通用操作”。该标签来源差异保留在冲突记录中，新增 action 不得修改父菜单标签或假定该字典值就是当前运行时显示。

本知识仅适用于当前 workspace、DEV、InforCenter 9.6 和 `ProductBOM`；其他菜单（如 `ProductBOMTree`）、基线、工作空间、其他 profile/角色/版本需要重新验证。
