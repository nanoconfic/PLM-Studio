# 原厂接入差异方案（用户已确认范围；待部署，不执行）

## 结论

当前 DEV 源码中，BOM 菜单的真实技术挂载链已确认：

```text
ProductBOM.page → PSEBom.menurelation → PseBomMenu.menu → BOMCommon
```

因此，用户要求的运行时位置“**其他操作 → 试制转量产**”应通过给 `PseBomMenu.menu` 增加一个 `ParentWebAtionName="BOMCommon"` 的 action 实现。运行时标签“其他操作”与源码字典中 `BOMCommon` 的“通用操作”存在冲突，**本方案不修改父菜单标签**。

本方案仅接入**演示菜单与只读规则清单**：不创建基线、不创建/另存/替换物料、不写颜色表、不调 SAP、不修改 BOM 数据。

## 证据基线

- profile：DEV
- 源清单：`vendor/source-manifest-DEV.yaml`
- 源指纹：`AD2ADDB08E41EE0125DCCFB864474F17B62ADBB99DBE1806B4EEABB709CDAA6B`
- 运行时标题：`结构管理器：气缸体总成/12100-2CB -A401/A.001(Design)(最新版本)`
- 详细证据：`analysis/evidence/20260915-ext001-pse-bom-menu-source-summary.md`
- 标签冲突：`analysis/contradictions/20260915-bomcommon-label-runtime-vs-source.md`

## 预计变更范围

> 下列原厂路径仅为拟修改对象；当前均未修改。新增文件应先在 `extensions/EXT-001/frontend/` 开发、审查和验证，再按获准部署方式发布。

| 类型 | 拟议路径 | 操作 | 用途 |
|---|---|---|---|
| 原厂菜单配置 | `InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.menu` | 最小增量 | 新增 `TrialToMassProductionDemo`，归入 `BOMCommon`。 |
| 原厂字典 | `InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.dic` | 最小增量 | 增加菜单标签和前端演示提示标签。 |
| 客户化 JS | 建议 `InforCenter/Custom/TrialToMassProduction/Js/TrialToMassProductionDemo.js` | 新增 | 读取当前选择节点，执行正则校验，打开演示页。 |
| 客户化页面 | 建议 `InforCenter/Custom/TrialToMassProduction/Config/Pages/TrialToMassProductionDemo.page` | 新增 | 展示待转码清单、全量规则、两列导出和演示确认。 |
| 客户化字典 | 建议 `InforCenter/Custom/TrialToMassProduction/Config/TrialToMassProductionDemo.dic` | 新增 | 演示页文字和提示。 |
| 前端注册 | `InforCenter/PSE/Bom/Config/PSEBomFileRef.fileref` **或** 经确认的客户化文件注册机制 | 待确认 | 令 BOM 页面加载新增 JS；不可猜测最终注册/安装方式。 |

## 拟议原厂菜单最小差异

目标文件：`InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.menu`

在 `ItemObjectMessage`（Order=2500）后，增加以下 action；保留所有现有 action、顺序和标签不变：

```xml
<WebAction Name="TrialToMassProductionDemo"
           MultiMenu="false"
           ModuleName="PSE"
           LabelName="TrialToMassProductionDemo.Menu"
           Image="s_common_operations"
           ParentWebAtionName="BOMCommon"
           RefreshType=""
           RefreshedSelect="false"
           RefreshedHiddentObjectInspectorPage="false"
           DropDownItemIsHideCustom="false"
           IsHidden="false"
           IsTemplate="false"
           Order="2600"
           IsMainConfig="false">
  <ActionChecker SelectID="[TreeList_Current_MASTERID$]"
                 SelectMode="SINGLE"
                 Action=""
                 ActionType="PSEITEM"
                 SelectType="[{'ObjectType':'PSEITEM','InfoList':[]},{'ObjectType':'PSEITEM$','InfoList':[]}]" />
  <JSMethod Name="InforCenter_Custom_TrialToMassProduction_OpenDemo"
            SelectID="[TreeList_Current_MASTERID$]"
            IsLoopExec="false">
    <Para Name="ItemCode" Value="[TreeList_Current_ECODE]" />
    <Para Name="ItemName" Value="[TreeList_Current_ENAME]" />
    <Para Name="ItemMasterID" Value="[TreeList_Current_MASTERID$]" />
    <Para Name="ViewID" Value="[TreeList_Current_PSEITEMVIEWEID]" />
    <Para Name="ViewType" Value="[TreeList_Current_PSEITEMVIEWVIEWTYPE]" />
    <Para Name="TreeListID" Value="[TREELISTID]" />
  </JSMethod>
</WebAction>
```

### 需在确认后验证的 XML 细节

- `SelectType` 的 XML 转义与现有 action 一致时应使用 `&quot;`；上例只用于审查可读性。
- `Order="2600"` 依据现有 2200–2500 子项推定；运行时“收藏”没有在当前镜像中定位到同一 action 定义，最终排序应在实际 DEV 菜单中复验。
- 图标 `s_common_operations` 仅是复用父菜单图标的保守占位。若需要专用图标，请由用户指定或在客户化图标包中提供。

## 新增 JS 的演示职责

建议函数：`InforCenter_Custom_TrialToMassProduction_OpenDemo(para)`。

只允许：

1. 读取 action 传入的 `ItemCode`、`ItemName`、`ViewType` 与当前选中上下文；
2. 用 `^\w*-(?:1|2)-\w*$` 校验车型级物料；失败显示：`仅可对车型进行转量产！！`；
3. 打开客户化演示页，传入上述只读上下文；
4. 演示页展示已确认的三组编码映射、全量规则、层级排除规则与两列导出；
5. 关闭/确认时用 `InforCenter_Platform_MenuCtrl_InnerReceiveServerData(..., { confirm: "OK" })` 返回，不触发刷新、写入或服务调用。

禁止：

- `HoteamUI.DataService.Call/AsyncCall` 调用写入服务；
- 自动检出、检入、保存、另存、替换、基线、颜色表 SQL、SAP 调用；
- 修改 `PSEBomService` 或调用 `BatchUpdateBom`、CAPP `UpdateBom` 等现有写入模式。

## 演示页内容

- 标题：试制转量产（演示）
- 上下文：当前物料编码、名称、视图类型
- 清单列：原物料编码、原物料名称、演示量产编码、判定说明
- 导出：只导出 **原物料编码、原物料名称** 两列
- 已确认规则：
  - 所有匹配物料全量转码，不允许逐项取消；
  - 不匹配中间层级时，排除该中间层级以下整个分支；
  - 映射样例：
    - `8125A-2CDB-A505 → 8125A-2CD -A500`
    - `81300-2CDB-A600 → 81300-2CD -A600`
    - `82100-2CDB-A617-M1_TYPE1 → 82100-2CD -A610-M1_TYPE1`
- 明示边界：不创建基线、不创建或替换物料、不写颜色表、不调用 SAP。

## 用户确认记录

用户已确认以下有限范围：

1. 将“试制转量产”挂到运行时“其他操作”下，与对象授权、收藏等平级；技术实现使用 `ParentWebAtionName="BOMCommon"`。
2. 同意原厂菜单/字典最小增量、前端文件注册及新增只读演示 JS、页面、字典。
3. 后端、数据库、颜色表和 SAP 仍不纳入本次演示。
4. 若部署验证实际需要，可视情况重启服务；当前尚未配置 IIS 物理路径、应用池或服务名，部署前须明确具体对象、影响与回退方式。

## 已交付待部署包

- 目录：`deployment-package/`
- ZIP：`TrialToMassProductionDemo-deployment-package.zip`
- 完整性清单：`deployment-package/SHA256SUMS.txt`
- 三份原厂补丁已在临时副本成功应用并完成 XML、JS 语法、菜单归属与“无写入服务调用”检查。

部署前不得猜测 VM 工作目录、IIS 物理路径或应用池/服务名称。
