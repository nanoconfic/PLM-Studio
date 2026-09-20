---
id: "KNOW-EXT002-IC96-COLOR-EXCEL-TABLE"
status: Candidate
category: component-pattern
applicability:
  workspace_id: "plm-studio"
  product: "InforCenter"
  version: "9.6"
  profiles: ["DEV"]
  source_fingerprint: "4596E69E5060DC5F448C4DB4F3E661DEA25C82EAD007A5F6E4062B65AAA1416B"
  navigation_path: "系统导航 > 产品数据管理 > 颜色件管理"
evidence:
  - "extensions/EXT-002/evidence/deployment-record-20260918-162248.json"
  - "extensions/EXT-002/integration/package/InforCenter/PDM/Change/Pages/ColorPartManagementImport.js"
environment_snapshot: null
verified_at: null
supersedes: "KNOW-EXT002-IC96-PDM-COLOR-NAV-EMBEDDED"
---
# 颜色件 Excel 解析结果表格模式

Excel 文件选择与解析分离：选择文件只显示文件名；点击“解析 Excel”后才在导入对话框的独立 `table` 中展示结果。结果区应具备：

- 明确列头、固定表头和独立横纵滚动；
- 空状态、解析数量、Excel 行号和逐行校验提示；
- 不完整行红色提示、重复行黄色提示；
- 通过校验的记录才回写当前页面内存主表；
- 不上传 Excel，不用卡片列表展示多列条目。

该交互已由远程浏览器验证，但尚未收到用户最终验收，保持 Candidate。
