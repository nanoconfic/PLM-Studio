# EXT-001 试制转量产演示部署包

## 类型

只读前端演示包。不会调用服务端写入、不会修改 BOM、物料、基线、颜色表或 SAP。

## 新增文件（部署目标相对于 InforCenter Web 根目录）

- `InforCenter/PSE/Bom/Js/TrialToMassProductionDemo.js`
- `InforCenter/PSE/Bom/Config/Pages/TrialToMassProductionDemo.page`
- `InforCenter/PSE/Bom/Config/Pages/TrialToMassProductionDemo.dic`

## 原厂补丁（在批准的目标目录应用）

- `patches/001-pse-bom-menu-trial-to-mass-demo.patch`
- `patches/002-pse-bom-menu-dictionary.patch`
- `patches/003-pse-bom-file-reference.patch

## 变更行为

- 菜单位置：`其他操作`（技术父级 `BOMCommon`）下，与对象授权、批量授权、发送给其他用户、消息订阅和收藏平级。
- 新 action 顺序：2600；在镜像已定义的消息订阅（2500）之后。
- 仅车型级编码满足 `^\w*-(?:1|2)-\w*$` 时打开演示页；否则提示“仅可对车型进行转量产！！”。
- 演示页展示 3 组已确认映射，导出仅含“原物料编码、原物料名称”。

## 不含内容

- 任何服务端 DLL、数据库 SQL、配置数据库更新；
- 自动检出/检入、创建基线、物料另存或替换；
- 颜色表、SAP 接口和服务重启。

## 部署前提

VM 工作目录、IIS 站点物理路径、客户化配置导入机制和服务/应用池名称尚未配置。部署前必须补充并确认；若需要重启，先记录具体对象、影响范围和回退方式。

## 完整性校验

部署前在包根目录按 `SHA256SUMS.txt` 校验文件；补丁以文本模式应用于与 DEV 源指纹一致的基线。若目标文件哈希不同，停止应用并重新同步/审查差异。
