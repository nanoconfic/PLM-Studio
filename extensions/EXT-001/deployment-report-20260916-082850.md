# EXT-001 试制转量产演示部署报告

- **部署时间**：2026-09-16T00:28:50.3828282Z
- **环境**：DEV
- **部署根目录**：`\\192.168.40.76\1_Server`
- **部署前源指纹**：`AD2ADDB08E41EE0125DCCFB864474F17B62ADBB99DBE1806B4EEABB709CDAA6B`
- **部署后源指纹**：`9285FAED8B19556A5BEC48887BDF48FC046240C7964074C49D56997AB422D78D`（部署后已重新执行只读同步；当前清单 21,874 文件，7 个文件变更/新增）。
- **部署状态**：已部署；用户已检查效果正常。
- **服务重启**：未执行。对于 InforCenter 项目，后续如需 IIS/业务服务重启或应用池回收，按 Studio 行为模式挂起并交由用户手工操作。
- **本地回退备份**：`extensions/EXT-001/deployment-backup/20260916-082850`
- **部署记录**：`extensions/EXT-001/deployment-backup/20260916-082850/deployment-record.json`

## 已部署内容

### 原厂最小增量

1. `InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.menu`
   - 新增 `TrialToMassProductionDemo` action；
   - `ParentWebAtionName="BOMCommon"`，即运行时“其他操作”分组；
   - 顺序 `2600`，与对象授权、批量授权、发送给其他用户、消息订阅、收藏同级。
2. `InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.dic`
   - 新增“试制转量产”和“仅可对车型进行转量产！！”标签。
3. `InforCenter/PSE/Bom/Config/PSEBomFileRef.fileref`
   - 注册 `TrialToMassProductionDemo.js`。

### 新增文件

- `InforCenter/PSE/Bom/Js/TrialToMassProductionDemo.js`
- `InforCenter/PSE/Bom/Config/Pages/TrialToMassProductionDemo.page`
- `InforCenter/PSE/Bom/Config/Pages/TrialToMassProductionDemo.dic`

## 部署后验证

| 检查项 | 结果 |
|---|---|
| 部署前三个原厂文件 SHA-256 与源清单一致 | 通过 |
| 三个新文件部署前不存在 | 通过 |
| 原厂菜单、字典、资源清单与新增 page/dic 的 XML 解析 | 通过 |
| 新 action 父级 `BOMCommon`、顺序 `2600` | 通过 |
| 新文件远程 SHA-256 与部署包一致 | 通过 |
| 新 JS 经 IIS URL 返回 HTTP 200 | 通过 |
| 新 JS 静态扫描（无 DataService、PseBomService、检出/检入、批量更新调用） | 通过 |
| 登录后 BOM 菜单显示“试制转量产” | 用户已检查效果正常 |
| IIS / 服务重启 | 未执行；若后续需要，交由用户手工操作 |
| 部署后重新同步的 6 个目标文件哈希 | 通过；另有 1 个部署记录/相关文件变动计入同步 |

## 验收与后续规则

- HTTP 首页健康：`200`，首字节约 5–8ms；服务本身正常。
- 用户已检查本次部署效果正常；该结论来自用户验收反馈。
- 本次未执行 IIS、IIS 应用池或业务服务重启/回收。
- 后续 InforCenter 部署如需刷新 IIS/业务服务：AI 说明原因、建议对象、影响、验证与回退后挂起，交由用户手工操作；用户反馈完成后再继续验证。
