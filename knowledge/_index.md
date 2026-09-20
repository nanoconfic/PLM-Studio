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

- `KNOW-EXT002-IC96-PDM-COLOR-NAV-EMBEDDED` — DEV 中在已加载的 `PDM/Change` 模块内向 `ProductDataManagement` 追加“颜色件管理”同级导航项，并以 Iframe 加载本地静态页面；Excel 仅在浏览器内解析、校验并回写当前页面内存。已完成源码/哈希/HTTP/无登录态浏览器验证，尚待已登录运行时菜单验收。  
  记录：`knowledge/patterns/inforcenter-pdm-color-navigation-embedded-candidate.md`  
  证据：EXT-002 当前源码清单、部署哈希和 HTTP 200。  

- `BOMCommon` 的运行时标签“其他操作”与镜像标准字典标签“通用操作”存在来源差异；技术父级关系已验证，但标签覆盖来源未查明。  
  冲突记录：`knowledge/contradictions/20260915-bomcommon-label-runtime-vs-source.md`
