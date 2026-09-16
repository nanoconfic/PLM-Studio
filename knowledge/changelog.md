# 知识变更记录

记录时间、记录 ID、原状态、新状态、原因、证据和环境快照。

| 时间 | 记录 ID | 原状态 | 新状态 | 原因 | 证据 | 环境快照 |
|---|---|---|---|---|---|---|
| 2026-09-15 | KNOW-EXT001-IC96-BOM-CLASSIC-STYLE | 无 | Candidate | 在当前 DEV 运行时登录并复现“产品数据管理 → BOM管理”，采集到经典蓝色主题、紧凑工具栏、树/网格工作区及样式计算值；初始未覆盖有数据 BOM。 | `knowledge/evidence/20260915-ext001-bom-page-style-summary.md` | `knowledge/environment-snapshots/20260915-154808-643-499c63.yaml` |
| 2026-09-15 | KNOW-EXT001-IC96-BOM-CLASSIC-STYLE | Candidate | Candidate | 以唯一编号加载气缸体总成，并从 Process1 切换至 Design；确认结构管理器标题、3 行结构数据及用户指定的“其他操作 → 试制转量产”位置。未确认原厂 Command/Action 或源码映射。 | `knowledge/evidence/20260915-ext001-bom-design-view-summary.md` | EXT-001 最新分析会话快照 |
| 2026-09-15 | KNOW-EXT001-IC96-BOM-CLASSIC-STYLE | Candidate | Candidate | 已同步当前 DEV 源码并定位 `ProductBOM → PseBomMenu → BOMCommon`；运行时与源码共同支撑菜单父级定位，但标签差异与原厂 action 实现仍待确认。 | `knowledge/evidence/20260915-ext001-pse-bom-menu-source-summary.md` | `knowledge/environment-snapshots/20260915-160421-497-1a9bfa.yaml` |
| 2026-09-16 | KNOW-EXT001-IC96-BOM-CLASSIC-STYLE | Candidate | Verified | 当前 DEV 蓝色主题的 BOM 样式与布局已由运行时页面、计算样式、Design BOM、部署后源清单及用户验收共同验证；范围严格限定为当前 DEV、蓝色主题和已验证角色。 | `knowledge/evidence/20260915-ext001-bom-page-style-summary.md`、`knowledge/evidence/20260915-ext001-bom-design-view-summary.md`、`extensions/EXT-001/deployment-report-20260916-082850.md` | `knowledge/environment-snapshots/20260916-090431-276-b6a159.yaml` |
| 2026-09-16 | KNOW-EXT001-IC96-BOM-MENU-INTEGRATION | 无 | Verified | `ProductBOM → PseBomMenu → BOMCommon` 菜单链已由当前源码、部署 action、部署后源清单和用户验收共同验证；明确可复用的“其他操作”同级 action 集成点与资源注册模式。 | `knowledge/evidence/20260915-ext001-pse-bom-menu-source-summary.md`、`extensions/EXT-001/deployment-report-20260916-082850.md` | `knowledge/environment-snapshots/20260916-090431-276-b6a159.yaml` |
