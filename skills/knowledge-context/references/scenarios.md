# 知识读取场景

| 环境或场景 | 必须读取的 facet | 主要知识类型 |
|---|---|---|
| 新扩展需求已经明确，准备做原型结构或视觉设计 | `Style,Business` | `page-style`、设计令牌、布局、组件、交互、业务流程、权限与校验 |
| 现有扩展开始新迭代或继续修改页面 | 本轮受影响的 facet；页面变化至少包含 `Style` | 上一轮可复用模式、当前产品版本约束、用户验收形成的 Verified 知识 |
| 页面样式、布局、字体、颜色、密度、按钮、菜单、弹窗、图标或交互 | `Style` | `page-style`、design-token、layout、component、interaction |
| 原系统菜单、挂载点、页面注册、文件引用、前端资源加载或嵌入 | `Integration` | `mount-point`、`menu-mechanism`、file-registration、source-structure、integration |
| 业务流程、角色权限、状态变化、操作条件或校验规则 | `Business` | `business-flow`、permission、workflow、validation-rule |
| 演示数据、对象属性、数据库、接口、写入操作或后端实现 | `Data,Business` | data-model、demo-data、interface、write-operation 以及相关业务约束 |
| 浏览器检查、源码分析、部署路径或环境差异 | `Environment`，涉及挂载时同时读取 `Integration` | environment、browser、deployment、source fingerprint |
| 缺陷修复或用户反馈要求改变既有设计 | 与缺陷相关的 facet | 已应用的 Verified 记录、Candidate 和相关冲突记录 |
| 交付前检查 | 本轮所有已使用 facet | 核对产物是否符合适用 Verified 约束，记录有证据的偏离 |

无需加载扩展知识的情况：仅整理工作区目录、查看扩展列表、归档缓存、维护通用工具且不作原型或产品决策。任务一旦进入具体扩展的设计、分析或实现，就必须经过知识上下文门禁。

适用性规则：

- Style 记录必须包含 `navigation_path`；workspace、产品、版本和 profile 全部匹配且路径精确相同时，Verified 样式才可直接复用。
- 非 Style 记录继续要求 workspace、产品、版本、profile 和适用的源码指纹匹配。
- 缺少当前源码指纹时，带指纹的记录降为“待确认”，先验证再采用。
- profile、主题、角色、产品版本或源码指纹不匹配的记录不能直接套用。
- Candidate 只用于提出问题、安排验证或避免重复调查。
- Deprecated 禁止采用，只能用于理解历史变化。

Excel、XLS、XLSX 或其他批量条目解析结果默认使用原产品原生网格；无法复用时使用语义化 `table`。结果区必须有明确列、固定表头、独立滚动区域、空状态和逐行校验状态，不使用卡片列表承载多列记录。
