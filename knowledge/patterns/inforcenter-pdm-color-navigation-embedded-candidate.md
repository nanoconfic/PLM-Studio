---
id: "KNOW-EXT002-IC96-PDM-COLOR-NAV-EMBEDDED"
status: Candidate
category: menu-mechanism
applicability:
  workspace_id: "plm-studio"
  product: "InforCenter"
  version: "9.6"
  profiles: ["DEV"]
  source_fingerprint: "4596E69E5060DC5F448C4DB4F3E661DEA25C82EAD007A5F6E4062B65AAA1416B"
  constraints:
    - "Source configuration, direct HTTP resources and headless-browser page workflow have completed; authenticated system-navigation visibility still needs user acceptance."
    - "The pattern is limited to the currently loaded PDM/Change module under ProductDataManagement."
evidence:
  - "sources/manifests/EXT-002/source-manifest-DEV.yaml"
  - "extensions/EXT-002/evidence/deployment-record-20260918-155848.json"
  - "extensions/EXT-002/evidence/deployment-record-20260918-160446.json"
  - "extensions/EXT-002/evidence/deployment-record-20260918-161459.json"
  - "extensions/EXT-002/evidence/deployment-record-20260918-162248.json"
  - "extensions/EXT-002/evidence/deployment-record-20260918-162952.json"
  - "extensions/EXT-002/integration-report.md"
environment_snapshot: null
verified_at: null
supersedes: null
---
# InforCenter 9.6 产品数据管理的已加载模块导航模式

当前 DEV 中，`InforCenter/PDM/Change/Config/WorkGroup.nav` 已在 `ProductDataManagement` 父导航下加载“变更库”。将 `ColorPartManagement` 作为同一文件、同一父级下排序 `042` 的子项，并在对应 `.dic` 和 `ChangeFileRef.fileref` 注册字典、页面创建脚本，可使颜色件页面进入已加载模块的导航配置链。

页面注册使用 Iframe 控件加载 `PDM/Change/Pages/ColorPartManagement.html`。静态页面引用原系统 `BasePage.css`，并在页面自身样式中覆盖其全局 `form` 绝对定位规则，避免筛选表单覆盖工具栏。

Excel 处理使用部署在同目录的浏览器脚本和本地 SheetJS 资源；文件不传输到服务端，合格记录只写入当前页面内存。已完成直接资源 HTTP 与无登录态浏览器导入/重复/必填校验测试，但系统导航是否在已登录 DEV 会话中可见仍需用户验收，故不得作为跨环境既定方案。

当页面嵌入宽度小于表格所需宽度时，页面主体必须不设置固定最小宽度；横向溢出仅由 `.table-wrap` 承担。当前九列表格以 1050px 最小宽度和固定列宽展示，在 800px 视口中页面主体保持 800px，而记录区独立提供横向滚动。

记录区域表头使用 `position: sticky; top: 0` 固定在区域顶部。Excel 文件选择与解析必须分离：选择事件仅重置并显示文件名，只有显式的解析按钮能读取文件并创建导入对话框内的结果表格。

用户指定采用 EXT-001 的经典 BOM 工作区样式作为视觉参考；由于该知识记录的工作区指纹不匹配，不能自动继承为既定约束。本轮以当前 DEV `BasePage.css` 和 `PSE/Bom/Css/Bom.css` 作直接证据：页面保持 12px 微软雅黑、紧凑灰色边界/网格，并将 `#157EC6`、25px 高主按钮应用于本页面。
