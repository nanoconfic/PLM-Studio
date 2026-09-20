---
id: "KNOW-EXT002-IC96-PDM-COLOR-MOUNT"
status: Candidate
category: mount-point
applicability:
  workspace_id: "plm-studio"
  product: "InforCenter"
  version: "9.6"
  profiles: ["DEV"]
  source_fingerprint: "4596E69E5060DC5F448C4DB4F3E661DEA25C82EAD007A5F6E4062B65AAA1416B"
  navigation_path: "系统导航 > 产品数据管理 > 颜色件管理"
  mount_sequence: "PDM/Change/Config/WorkGroup.nav > ColorPartManagement.page > PDM/Change/Js/ColorPartManagement.js > Iframe LoadPage > PDM/Change/Pages/ColorPartManagement.html"
evidence:
  - "sources/manifests/EXT-002/source-manifest-DEV.yaml"
  - "extensions/EXT-002/evidence/deployment-record-20260918-155848.json"
  - "extensions/EXT-002/integration-report.md"
environment_snapshot: null
verified_at: null
supersedes: "KNOW-EXT002-IC96-PDM-COLOR-NAV-EMBEDDED"
---
# 颜色件管理点击路径与嵌入顺序

用户点击顺序为：`系统导航 → 产品数据管理 → 颜色件管理`。

当前技术嵌入顺序：

```text
InforCenter/PDM/Change/Config/WorkGroup.nav
  → PageName: ColorPartManagement
  → Config/Pages/ColorPartManagement.page
  → ChangeFileRef.fileref 注册 Js/ColorPartManagement.js
  → Iframe 控件 LoadPage
  → Pages/ColorPartManagement.html
```

导航、字典、页面注册、脚本和静态资源已完成源码哈希与 HTTP 验证。由于已登录运行时菜单仍未获得用户最终验收，本记录保持 Candidate。
