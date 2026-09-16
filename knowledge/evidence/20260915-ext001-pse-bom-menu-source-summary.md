# EXT-001 PSE BOM 菜单源码证据摘要

- **证据 ID**：`EVID-20260915-EXT001-PSE-BOM-MENU-SOURCE`
- **状态**：Candidate（与运行时标签存在待解释差异）
- **采集时间**：2026-09-15
- **环境 profile**：DEV
- **来源**：只读本地镜像 `sources/mirror/DEV`；仅引用 `sources/manifests/source-manifest-DEV.yaml` 中的当前文件。
- **源指纹**：`AD2ADDB08E41EE0125DCCFB864474F17B62ADBB99DBE1806B4EEABB709CDAA6B`
- **清单规模**：21,871 文件；镜像同步复制 21,871 文件；未回写或删除共享目录文件。

## 已复现的菜单 → 页面 → 文件链

```text
ProductBOM.page
  └─ ProductBOMMenuContainer / ToolbarCtrl
      └─ InforCenter_PSE_ProductBOM_LoadPage(...)
          └─ InforCenter_Platform_MenuCtrl_LoadMenus(menuPage, bompagePara, "PseBomMenu")
              └─ PSEBom.menurelation: ProductBOM → PseBomMenu
                  └─ PseBomMenu.menu
                      └─ BOMCommon（父级菜单）
                          ├─ ObjectPermission
                          ├─ BatchObjectPermission
                          ├─ SendToOtherUser
                          └─ ItemObjectMessage
```

## 当前代码事实

| 作用 | 当前清单内路径 | SHA-256 | 事实 |
|---|---|---|---|
| ProductBOM 页面布局 | `InforCenter/PSE/Bom/Config/Pages/ProductBOM.page` | `86EA95BA2F17FEB431173F6BD0AB59E5C0BCCC33C28368BE279DEFBC0711944F` | 顶部通过 `ProductBOMMenuContainer` 承载工具栏。 |
| 菜单关系 | `InforCenter/PSE/Bom/Config/UIConfig/PSEBom.menurelation` | `080AEC091972217FC717621722E3BB03ABC2181C01EEF2AC3037E6D006547AD6` | `ProductBOM` 绑定 `PseBomMenu`。 |
| 菜单动作定义 | `InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.menu` | `3C7B1F243930A900BE54643D141292DFE6B21CDB070FDAE4DFA6028A6D677831` | `BOMCommon` 是顺序 5000 的顶层动作；对象授权、批量授权、发送给其他用户、消息订阅使用 `ParentWebAtionName="BOMCommon"`。 |
| 菜单字典 | `InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.dic` | `D0D5B258E0BD06833FAB7FFCE3EE82D255476ED57135BE8FBD90E0055C3DA3FA` | 标准源将 `BOMCommon` 的中文标签定义为“通用操作”。 |
| 菜单加载 JS | `InforCenter/PSE/Bom/Js/ProductBOM.js` | `8B4E506344D3A5D4B84F8BA5D0B347C84314563E3A17D0610EDA458A4AE1A041` | OnCreate 调用 `InforCenter_Platform_MenuCtrl_LoadMenus(..., "PseBomMenu")`。 |
| BOM 操作 JS | `InforCenter/PSE/Bom/Js/OperateInBom.js` | `505BB4D5B281B9DB6B454FD1F15F6AE41326A25E1A26B448BE151133E4632E1A` | 展示标准的菜单 action→JS→服务调用与 `InnerReceiveServerData` 回传模式。 |
| 前端加载清单 | `InforCenter/PSE/Bom/Config/PSEBomFileRef.fileref` | `7A2EDBE29236421805BB85DCEC4ED85E3AC5BCBEC3C71803AC2AC4131084D103` | 已注册 `ProductBOM.js`、`OperateInBom.js` 和 `Bom.css`。 |
| BOM 服务注册 | `InforCenter/PSE/Bom/Config/PSEBomService.service` | 当前清单内 | 服务为二进制 DLL `Hoteam.InforCenter.PSEBom.Service.dll`；没有发现“试制转量产”现成服务。 |

## 与运行时证据的关系

- DEV 运行时已经验证：指定 BOM 的工具栏存在“其他操作”，其子操作为对象授权、批量授权、发送给其他用户、消息订阅、收藏。
- 源码证明这些现有子操作的父级为 `BOMCommon`，因此将新 action 以 `ParentWebAtionName="BOMCommon"` 归入同一运行时分组是有证据支撑的。
- 但标准字典把 `BOMCommon` 译为“通用操作”，与 DEV 运行时“其他操作”不一致；见冲突记录，不能断言当前运行时标签直接来自该 `.dic`。

## 可复用实现模式（未实施）

- `WebAction` 使用 `ParentWebAtionName="BOMCommon"`、确定的 `Order`、图标与 ActionChecker。
- 现有 action 可传递当前树行的 `TreeList_Current_ECODE`、`TreeList_Current_ENAME`、`TreeList_Current_MASTERID$`、`TreeList_Current_PSEITEMVIEWEID`、`TreeList_Current_PSEITEMVIEWVIEWTYPE` 和 `TREELISTID`。
- 本需求演示仅需要只读扫描/导出与弹窗；不应复用 `BatchUpdateBom` 或 CAPP `UpdateBom` 的写入服务。它们含检出、更新/替换、异步服务及进度条逻辑，超出用户已确认的演示边界。

## 限制

- 不存在现成的“试制转量产”实现；需要新增客户化 action、字典和 JS（至少），具体注册/部署机制待确认。
- 当前镜像没有可读的 PSE BOM 服务端源实现，仅有 `.service` 到 DLL 的注册，不能据此设计或调用写入服务。
- 镜像为逻辑只读事实来源；任何原厂修改必须在用户确认可审查差异后才可执行。
