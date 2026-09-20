---
id: "KNOW-EXT002-IC96-PDM-COLOR-STYLE"
status: Candidate
category: page-style
applicability:
  workspace_id: "plm-studio"
  product: "InforCenter"
  version: "9.6"
  profiles: ["DEV"]
  source_fingerprint: "4596E69E5060DC5F448C4DB4F3E661DEA25C82EAD007A5F6E4062B65AAA1416B"
  navigation_path: "系统导航 > 产品数据管理 > 颜色件管理"
evidence:
  - "Base/Css/BasePage.css"
  - "InforCenter/PSE/Bom/Css/Bom.css"
  - "extensions/EXT-002/evidence/deployment-record-20260918-162952.json"
  - "extensions/EXT-002/prototype-design.md"
environment_snapshot: null
verified_at: null
supersedes: "KNOW-EXT002-IC96-PDM-COLOR-NAV-EMBEDDED"
---
# 颜色件管理路径下的经典桌面样式

适用路径：`系统导航 → 产品数据管理 → 颜色件管理`。

当前页面直接依赖原产品 `/Base/Css/BasePage.css`，并根据 DEV 当前 BOM CSS 与 EXT-001 已验证样式证据采用：

- 12px 微软雅黑基础字体与高信息密度布局；
- `#157EC6`、25px 高的蓝色主按钮；
- 方角控件、浅灰工具条、细边框和网格，不使用现代卡片或大阴影；
- 主记录区独立横向滚动，表头固定，工具栏、筛选和弹窗不随表格横向移动；
- 对话框沿用紧凑桌面边界，解析结果在独立网格区域呈现。

样式已完成远程浏览器计算值和布局验证，仍待用户最终样式验收，因此保持 Candidate。
