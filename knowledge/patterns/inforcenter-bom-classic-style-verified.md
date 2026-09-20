---
id: "KNOW-EXT001-IC96-BOM-CLASSIC-STYLE"
status: Verified
category: page-style
applicability:
  workspace_id: "plm-studio"
  product: "InforCenter"
  version: "9.6"
  profiles: ["DEV"]
  source_fingerprint: "9285FAED8B19556A5BEC48887BDF48FC046240C7964074C49D56997AB422D78D"
  navigation_path: "系统导航 > 产品数据管理 > BOM管理 > Design"
  constraints:
    - "Verified for the current DEV blue theme and current verified user role only."
    - "Verified on the BOM management work area and the loaded Design view for the specified sample object."
    - "Revalidate after source, theme, profile, role, or product-version changes."
evidence:
  - "knowledge/evidence/20260915-ext001-bom-page-style-summary.md"
  - "knowledge/evidence/20260915-ext001-bom-design-view-summary.md"
  - "knowledge/evidence/20260915-ext001-pse-bom-menu-source-summary.md"
  - "extensions/EXT-001/deployment-report-20260916-082850.md"
environment_snapshot: "knowledge/environment-snapshots/20260916-090431-276-b6a159.yaml"
verified_at: "2026-09-16"
supersedes: null
---
# InforCenter 9.6 BOM 管理经典页面样式

## Verified 结论

在当前工作区的 DEV、InforCenter 9.6 蓝色主题和当前已验证角色下，BOM 管理使用高信息密度的经典桌面工作区样式：

- 左侧 Accordion 导航；
- 工作区页签/面板与可拖拽分栏；
- 12px `微软雅黑, "Lucida Grande", "Lucida Sans", Arial, sans-serif` 基础字体；
- 浅灰分隔线与树/网格结构区；
- 紧凑分组菜单栏；重点蓝色按钮约 25px 高，运行时计算背景为 `rgb(21, 126, 198)`；
- BOM 操作入口应保持工具栏/下拉菜单的紧凑样式，不应改造成独立的现代卡片式页面。

在该限定范围内，扩展页面、弹窗和操作入口应复用上述字体、密度、边界、网格与菜单层级，优先维持原系统一致性。

## 运行时复现

1. 登录 DEV。
2. 产品数据管理 → BOM管理。
3. 加载根节点，使用已验证流程切换到 Design 视图。
4. 检查左导航、工作区、分组菜单、树/网格和紧凑按钮样式。

## 证据与验证理由

- 运行时页面和计算样式摘要：`knowledge/evidence/20260915-ext001-bom-page-style-summary.md`。
- 已加载 Design BOM 运行时证据：`knowledge/evidence/20260915-ext001-bom-design-view-summary.md`。
- 当前源码清单中的 ProductBOM、工具栏、CSS/JS 装载关系：`knowledge/evidence/20260915-ext001-pse-bom-menu-source-summary.md`。
- 已部署菜单演示通过用户检查：`extensions/EXT-001/deployment-report-20260916-082850.md`。

## 适用限制

仅适用于新大洲本田 InforCenter 9.6 的当前 DEV 蓝色主题和当前已验证角色。其他主题、profile、角色、分辨率或产品版本均必须重新验证；跨 workspace 不继承 Verified。
