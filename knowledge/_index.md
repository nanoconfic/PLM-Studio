# 知识索引

仅登记带 applicability、status、evidence 的记录。

## Verified

- `KNOW-EXT001-IC96-BOM-CLASSIC-STYLE` — 当前 DEV 蓝色主题下 InforCenter 9.6 BOM 管理的经典桌面样式、布局密度、树/网格与紧凑菜单/按钮模式。  
  记录：`knowledge/patterns/inforcenter-bom-classic-style-verified.md`  
  证据：运行时样式、Design BOM 页面、当前源码清单及 EXT-001 用户验收。  
  环境快照：`knowledge/environment-snapshots/20260916-090431-276-b6a159.yaml`

- `KNOW-EXT001-IC96-BOM-MENU-INTEGRATION` — 当前 DEV 的 `ProductBOM → PseBomMenu → BOMCommon` 操作集成链；运行时“其他操作”下新增同级菜单 action 的文件、父级 ID、前端资源注册与参数模式。  
  记录：`knowledge/patterns/inforcenter-bom-menu-integration-verified.md`  
  证据：运行时 Design BOM、当前源码清单、部署哈希与 EXT-001 用户验收。  
  环境快照：`knowledge/environment-snapshots/20260916-090431-276-b6a159.yaml`

## Candidate / 需重新验证

- `KNOW-EXT002-IC96-PDM-COLOR-MOUNT` — 路径 `系统导航 → 产品数据管理 → 颜色件管理` 的导航、页面注册、JS、Iframe 与静态页嵌入顺序；源码和 HTTP 已验证，待已登录菜单验收。
  记录：`knowledge/patterns/inforcenter-pdm-color-mount-candidate.md`

- `KNOW-EXT002-IC96-PDM-COLOR-STYLE` — 同一点击路径下的经典 PLM 桌面样式：12px 字体、`#157EC6` 紧凑主按钮、浅灰网格、固定表头和局部滚动；待用户最终样式验收。
  记录：`knowledge/patterns/inforcenter-pdm-color-style-candidate.md`

- `KNOW-EXT002-IC96-COLOR-EXCEL-TABLE` — 同一路径下 Excel 显式解析与 table 结果展示模式；已完成浏览器验证，待用户最终验收。
  记录：`knowledge/patterns/inforcenter-color-excel-table-candidate.md`

- `BOMCommon` 的运行时标签“其他操作”与镜像标准字典标签“通用操作”存在来源差异；技术父级关系已验证，但标签覆盖来源未查明。  
  冲突记录：`knowledge/contradictions/20260915-bomcommon-label-runtime-vs-source.md`

## Deprecated

- `KNOW-EXT002-IC96-PDM-COLOR-NAV-EMBEDDED` — 原记录混合了集成、样式和 Excel 展示，已由上述三个 path-scoped 记录替代；仅保留追溯。
