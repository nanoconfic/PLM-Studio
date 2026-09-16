# 环境快照

- 分析会话：2026-09-15
- 当前环境快照：`analysis/environment-snapshots/20260915-160421-497-1a9bfa.yaml`
- 当前 profile：DEV
- 当前源码清单：`vendor/source-manifest-DEV.yaml`
- 部署前源指纹：`AD2ADDB08E41EE0125DCCFB864474F17B62ADBB99DBE1806B4EEABB709CDAA6B`
- 当前部署后源指纹：`9285FAED8B19556A5BEC48887BDF48FC046240C7964074C49D56997AB422D78D`
- 首次同步：从用户选定的 `\\192.168.40.76\1_Server` 只读增量镜像 21,871 个文件；部署后再次同步，更新 7 个文件、其余 21,867 个未变；不执行源目录指令或命令。

## 菜单 → 页面 → Command/Action → 代码 → 样式

| 链路 | 证据状态 | 结论 |
|---|---|---|
| 导航菜单 | 运行时已验证 | `产品数据管理 → BOM管理`。 |
| BOM 页面 | 运行时 + 源码已验证 | 运行时以 `12100-2CB -A401` 打开气缸体总成，首次为 Process1，切换后为 `结构管理器：气缸体总成/12100-2CB -A401/A.001(Design)(最新版本)`；`ProductBOM.page` 是对应页面定义。 |
| 菜单关系 | 源码已验证 | `InforCenter/PSE/Bom/Config/UIConfig/PSEBom.menurelation` 将 `ProductBOM` 关联到 `PseBomMenu`。 |
| 菜单加载 | 源码已验证 | `InforCenter/PSE/Bom/Js/ProductBOM.js` 的 `InforCenter_PSE_ProductBOM_LoadPage` 调用 `InforCenter_Platform_MenuCtrl_LoadMenus(menuPage, bompagePara, "PseBomMenu")`。 |
| 目标父菜单 | 运行时 + 源码已验证 | 运行时标签为“其他操作”；源码技术 ID 为 `BOMCommon`，`PseBomMenu.menu` 中对象授权、批量授权、发送给其他用户、消息订阅均以 `ParentWebAtionName="BOMCommon"` 加入该父菜单。 |
| 菜单配置 | 源码已验证 | `InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.menu` 是目标原厂菜单文件；其 `BOMCommon` 顶层 action 顺序为 5000。 |
| 标签字典 | 源码已验证但有冲突 | `PseBomMenu.dic` 将 `BOMCommon` 译为“通用操作”，与 DEV 运行时的“其他操作”不一致；见 `analysis/contradictions/20260915-bomcommon-label-runtime-vs-source.md`。 |
| JS/CSS 装载 | 源码已验证 | `PSEBomFileRef.fileref` 已装载 `ProductBOM.js`、`OperateInBom.js`、`Bom.css`；新增 BOM JS 需纳入此清单或使用部署机制注册。 |
| 后端服务 | 源码边界已验证 | `PSEBomService.service` 只注册二进制 DLL 服务；当前镜像中未发现“试制转量产”现成功能或可读服务端实现。 |

## 目标动作的已确认演示规则

- 菜单位置：`其他操作 → 试制转量产`；技术父级为 `BOMCommon`。
- 仅支持车型级物料，正则：`^\w*-(?:1|2)-\w*$`；不符合提示：`仅可对车型进行转量产！！`。
- 演示映射：
  - `8125A-2CDB-A505 → 8125A-2CD -A500`
  - `81300-2CDB-A600 → 81300-2CD -A600`
  - `82100-2CDB-A617-M1_TYPE1 → 82100-2CD -A610-M1_TYPE1`
- 匹配物料必须全量转码；不允许逐项取消。
- 中间层级不匹配时，排除该中间层级以下整个分支。
- 导出仅含：原物料编码、原物料名称。
- 本轮只做交互和规则演示：不创建基线、不另存/替换物料、不写颜色表、不调用 SAP。

## 已确认的相关实现模式

- `PseBomMenu.menu` 中已有 action 以 `ParentWebAtionName="BOMCommon"`、`Order`、`Image`、`ActionChecker` 和 `JSMethod` 声明。
- 当前树节点参数可供 action 使用：`[TreeList_Current_ECODE]`、`[TreeList_Current_ENAME]`、`[TreeList_Current_MASTERID$]`、`[TreeList_Current_PSEITEMVIEWEID]`、`[TreeList_Current_PSEITEMVIEWVIEWTYPE]`、`[TREELISTID]`。
- `OperateInBom.js` 使用 `HoteamUI.UIManager.Popup`、`HoteamUI.DataService` 和 `InforCenter_Platform_MenuCtrl_InnerReceiveServerData` 作为标准前端动作模式。
- CAPP `UpdateBom` 与 PSE `BatchUpdateBom` 均含写入、检出、异步服务和进度控制，不能用于当前“只演示”的需求。

## 未知项与限制

1. 当前镜像未发现“试制转量产”的既有 action、页面、JS 或服务；必须新增客户化实现。
2. 正式物料创建、BOM 替换、基线、颜色表和 SAP 仍未批准，且不在本次演示范围。
3. 标准源字典“通用操作”和 DEV 运行时“其他操作”存在冲突；不修改父菜单标签，新增 action 仅使用技术 ID `BOMCommon`。
4. 原厂菜单文件、字典和 file reference 的修改属于原厂修改；用户已确认有限演示范围，部署已完成且用户已检查效果正常。后续 InforCenter 项目如需要 IIS、应用池或业务服务刷新/重启，AI 必须挂起并交由用户手工操作后再继续验证。

## 证据

- `analysis/evidence/20260915-ext001-bom-page-style-summary.md`
- `analysis/evidence/20260915-ext001-bom-design-view-summary.md`
- `analysis/evidence/20260915-ext001-pse-bom-menu-source-summary.md`
- `analysis/contradictions/20260915-bomcommon-label-runtime-vs-source.md`

## Analysis session 2026-09-16T09:04:31.3132013+08:00
Environment snapshot: D:\workspace\PLM-Studio\workspaces\xindazhou-honda-inforcenter-9.6\analysis\environment-snapshots\20260916-090431-276-b6a159.yaml
Status: evidence collection pending; not Verified.

