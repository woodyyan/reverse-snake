# Snake Feast · iOS 版（Swift）

网页版 `../index.html`（v1.6）的原生 iOS 移植，iOS 版游戏名为 **Snake Feast**。完整保留玩法、流程、视觉、音效与存档规则，纯 Swift + SwiftUI + Core Graphics 实现，**无第三方依赖、无 Storyboard**，自带 `Assets.xcassets`（AppIcon + 左上角 Logo），可直接打开工程编译运行。

> 命名说明：只改了用户可见的游戏名（主屏 App 显示名 `CFBundleDisplayName`、顶栏品牌文字、本文档标题）。工程目录、Xcode 工程 / scheme / target / product 名、Bundle ID、`UserDefaults` key 等内部标识一律保留，避免破坏构建、仓库一致性和已保存的最高分。

- 目标设备：iPhone + iPad（`TARGETED_DEVICE_FAMILY = 1,2`）
- 最低系统：iOS 16.0
- 多语言：简体中文 / 繁体中文 / 英文（美国），跟随系统自动切换
- 方向：iPhone 竖屏 / 横屏，iPad 四方向；支持旋转、分屏（Split View）与安全区
- iPhone Duo：外屏 1398×2034 与内屏 2007×2853 均已在 iOS 27.2 模拟器实测；外屏无顶部安全区（状态栏在侧栏）时顶部自动加 10pt 留白；折叠 / 展开对局不丢失（自动暂停）
- 隐私清单：`ReverseSnake/PrivacyInfo.xcprivacy`（不追踪、不收集数据；UserDefaults 理由 CA92.1），Info.plist 声明 `ITSAppUsesNonExemptEncryption = NO`
- Bundle ID：`com.woodystudio.reversesnake`，版本号 1.6（与网页版一致）
- 外观：浅色「晨纸 Daylight」/ 深色「夜行 Nocturne」双主题，默认跟随系统，可在主页或暂停面板切换

## UI v2 设计（2026-11）

设计稿：`Design/ui-v2-proposal/index.html`。本版只改视觉与布局，玩法、手感参数、Game Center、多语言逻辑不变。

| 模块 | v2 方案 |
|---|---|
| 主题 | `Palette.night`（#07090E 底 · 冷蓝蛇 #5CC8FF · 橙点 #FF7A2F · 金种 #FFC83D）/ `Palette.daylight`（#F3EFE6 纸底 · 墨绿蛇 #1F6B52 · 珊瑚点 #FF5A47 · 金种 #E9A410）；一种颜色一个语义 |
| 外观切换 | `AppearanceStore`：跟随系统 / 浅色 / 深色，存 `UserDefaults`，以 window `overrideUserInterfaceStyle` 生效（SwiftUI、CG 棋盘、状态栏同步切换）|
| 主页 | 独立页：品牌 + 动态棋盘预览 + 规则 + 三元素图例（你 / 金种 / 蛇）+ 开始 + 排行榜 / 音效 / 外观 |
| 游戏中 | 顶栏只留暂停；得分居中 + 最高分；3 个迷你指标（蛇长 / 空间 / 追击，带微型进度条）|
| 棋盘元素 | 交点点阵替代网格线；连续圆管蛇（尾细暗 → 头粗亮，带双眼）；金色种子替代青绿晶体；玩家外环 = 冲刺冷却；吃到金环 + “+1”；冲刺残影；逼近红色暗角；死亡蛇身转红 |
| 暂停 | 底部抽屉：继续 / 重新开始 / 音效开关 / 外观分段 / 排行榜 |
| 结算 | 卡片弹入：原因 + 滚动大分数 + 新纪录 + 3 项数据 + 名次条 + 再来一局 / 返回主页 |
| 排行榜 | 全屏页：分段 Tab + 前三领奖台 + 列表 + 底部固定「我」|
| 图标 | I3「S 进化」：扁平 S 形蛇 + 橙色光点；含 iOS 18 深色 / 着色变体 |

DEBUG 截图布景：`-SFDebugState running|paused|over|countdown`（冻结一帧代表性局面），配合 `-GCMock ranked|none`、`-GCShowBoard YES`。

## 运行

方式一（Xcode GUI）：

```bash
open ReverseSnake.xcodeproj
```

选择 `ReverseSnake` scheme → 任选 iPhone / iPad 模拟器或真机 → `⌘R`。真机需在 Target → Signing & Capabilities 里选择 Development Team。

方式二（命令行）：

```bash
xcodebuild -project ReverseSnake.xcodeproj \
  -scheme ReverseSnake \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

产物：`/tmp/.../Build/Products/Debug-iphonesimulator/ReverseSnake.app`（或用 `-derivedDataPath` 指定）。安装到已启动的模拟器：

```bash
xcrun simctl install booted <path>/ReverseSnake.app
xcrun simctl launch booted com.woodystudio.reversesnake
```

> 工程里预设了 `OTHER_SWIFT_FLAGS = "-Xfrontend -disable-sandbox"`。本机 Xcode 27 的 SwiftUI 宏插件（`swift-plugin-server`）在命令行构建时会因嵌套沙箱被拒绝而报 `StateMacro could not be found`；该标志仅关闭**编译期**宏沙箱，不影响产物，Xcode GUI 构建不受影响。其他机器可按需移除。

## 结构

```
ReverseSnake-iOS/
├── ReverseSnake.xcodeproj/          # 工程 + 共享 scheme
├── Design/
│   └── generate_icon.swift          # macOS Core Graphics 脚本：生成 AppIcon / Logo PNG
└── ReverseSnake/
    ├── Assets.xcassets/             # AppIcon.appiconset + Logo.imageset
    ├── en.lproj/Localizable.strings        # 英文（开发语言 / 其他英语地区兜底）
    ├── en-US.lproj/Localizable.strings     # 英文（美国）
    ├── zh-Hans.lproj/Localizable.strings   # 简体中文
    ├── zh-Hant.lproj/Localizable.strings   # 繁体中文
    ├── Localization.swift           # L10n 键定义 / 查表 / 语言切换中心
    ├── ReverseSnakeApp.swift        # @main App 入口（含音频预热 + locale 注入）
    ├── Theme.swift                  # 双主题 Palette + 外观切换 AppearanceStore + LayoutMetrics
    ├── GameEngine.swift             # 状态机 / 蛇 AI / BFS / flood fill / 计分 / 粒子 / 存档
    ├── SoundEngine.swift            # AVAudioEngine 波形合成（WebAudio 等价）
    ├── Haptics.swift                # UIFeedbackGenerator 震动反馈（按事件分级）
    ├── GameBoardView.swift          # BoardScene + CG 渲染器、CADisplayLink、触控、主页棋盘预览
    ├── HUDView.swift                # 游戏顶栏：暂停 / 得分 / 最高 + 3 个迷你指标
    ├── OverlayViews.swift           # 主页 HomeView、暂停抽屉 PauseSheet、结算卡 GameOverCard
    ├── ControlsView.swift           # 共享组件：主 / 次按钮、圆形图标按钮、Pill、头像、元素图例
    ├── ContentView.swift            # 分层布局（游戏 / 结算 / 暂停 / 主页 / 排行榜）、动态网格、抖动、Game Center 事件桥接
    ├── GameCenterManager.swift      # Game Center 登录 / 提交 / 拉榜 / 离线补交 / 系统榜跳转（+ DEBUG mock）
    ├── LeaderboardView.swift        # 排行榜页（领奖台 / 列表 / 我的名次）、结算页名次条
    ├── ReverseSnake.entitlements    # com.apple.developer.game-center
    └── PrivacyInfo.xcprivacy        # 隐私清单（App Store 必需）
```

调参入口：`GameEngine.swift` 顶部常量（`playerMS / snakeBase / snakeMin / planSteps / grow / dashCD / dirs`），与网页版 `config` 区一一对应。

**动态网格**：`LayoutMetrics.gridDimensions(available:)` 按舞台实际宽高比计算列/行，总格数维持约 468（与网页版 18×26 / 26×18 同为 468），因此棋盘几乎铺满整屏而难度不变。iPhone 竖屏实测 16×29、iPad 竖屏 19×25。主页上网格随舞台尺寸即时更新；**对局中**（倒计时 / 进行中 / 暂停 / 结算）舞台尺寸变化（iPhone Duo 折叠 / 展开、旋转、分屏）**不再重开**：保留当前网格、按新舞台重算格子大小居中显示，并自动暂停，新网格从下一局生效（`GameEngine.applyGrid` + `pendingGrid`）。`BoardStage` 用 `onChange(of: GridSpec)` 的新值驱动，避免旋转 / 折叠过渡中闭包捕获到旧布局。

**等宽对齐**：顶部 Header / HUD 与深空舞台外框共用同一宽度，三者左右边界严格对齐。舞台外框填满可用宽度，棋盘格子保持正方形并居中——只是把原来的浅色侧边空隙变成深空底色，因此棋盘实际尺寸与位置不变，信息区也不被压缩。

## 操作

| 触控 | 作用 |
|---|---|
| 棋盘上滑动 | 设定持续移动方向，可连续拐弯 |
| 点按棋盘 | 冲刺 2 格（CD 2.6s） |
| 右上角 3 个图标按钮 | 暂停 / 继续、音效开关、重开 |

开始前提示面板保留三行规则与两个高亮操作芯片（滑动转向 / 点按冲刺），游戏中不占任何屏幕空间。暂停、重开、音效都走顶部按钮。App 退到后台自动暂停。

**顶栏控制**：3 个按钮统一为深色能量面板（HUD 同款 `hudTop → hudBottom` 渐变 + `hudBorder` 描边 + 青色发光图标），取代原白色文字按钮。图标为 `pause.fill` / `play.fill`（暂停 / 继续，暂停态橙色呼应 HUD 状态灯）、`speaker.wave.2.fill` / `speaker.slash.fill`（音效开 / 关，关闭时灰蓝）、`arrow.counterclockwise`（重开）；按压有缩放 + 高亮反馈，本地化语义保留在 `accessibilityLabel`。与左上角 Logo、下方深色 HUD 构成同一控制语言。

> 虚拟方向键、外接键盘支持、底部手势提示 / 玩法说明、角落版本号、`P` / `R` / `Return` 等键盘文案均已移除，只保留滑动玩法。

**弹框统一设计**：开局 / 暂停 / 结算三面板共用深色能量卡片（HUD 渐变、`hudBorder` 描边、顶部扫描线、四角准星、等宽状态铭牌 + 状态灯），取代原白色表单卡片。主按钮为青→蓝能量渐变 + 按压反馈；开局页用两个 `OperationChip` 高亮操作方式（图标 + 本地化动作 + 等宽说明），取代原来不起眼的一行灰字；结算页用分数铭牌 + 发光大分数 + 长度 / 最高分单元格替代长句。文字量未增加，操作信息更醒目。

## 多语言（跟随系统）

支持 **简体中文 / 繁体中文 / 英文（美国）**，无应用内语言开关：App 语言完全跟随系统首选语言（含 iOS「设置 → App → 首选语言」的按应用设置）。

| 系统语言 | 命中目录 |
|---|---|
| `zh-Hans*` | `zh-Hans.lproj` |
| `zh-Hant*` / `zh-HK` / `zh-TW` | `zh-Hant.lproj` |
| `en-US` | `en-US.lproj` |
| `en-GB` / `en-AU` / 其它 | `en.lproj`（英文兜底） |
| 其它未支持语言 | 回退开发语言 `en` |

- 文案全部收进 `*.lproj/Localizable.strings`，共 69 个 key，与 `Localization.swift` 的 `L10n.K` 常量一一对应；`en` 与 `en-US` 内容一致。
- SwiftUI 侧统一用 `L10n.t(key)`（`LocalizedStringKey`）；Core Graphics 绘制的 `GRID` 铭牌、`GO`、倒计时提示用 `L10n.s(key)`（按 `Locale.preferredLanguages` 逐级匹配 `xxx-YY → xxx`，带表缓存）。
- `LocalizationCenter` 监听 `NSLocale.currentLocaleDidChangeNotification`，通过 `.environment(\.locale, ...)` 注入新 Locale，语言变化后无需重建视图树、也不会重置对局状态；系统若选择重启 App 则照常重启。
- `GameEngine` 只存 key（`stateKey` / `overReasonKey`），由视图在渲染时解析，避免语言切换后残留旧文案。
- **不翻译**：品牌名 `SNAKE FEAST`、主屏 App 名 `Snake Feast`、数字 / 百分比 / 倒计时数字、Bundle ID 与工程内部标识。

新增文案流程：在 4 份 `.strings` 里加同名的 `"key" = "value";` → 在 `L10n.K` 加常量 → 视图用 `L10n.t(...)` / `L10n.s(...)`。`project.pbxproj` 用 `PBXVariantGroup` 管理这 4 份文件，新增语言需同步加 child 与 `knownRegions`。

## 全球排行榜（Game Center）

纯 Apple 托管：无后端、无账号体系、无名字登记（显示 Game Center 昵称）。Game Center 只是增强项，任何失败都降级为本机最高分，不阻塞、不打断对局。

| 项 | 实现 |
|---|---|
| 排行榜 | `snakefeast.best.alltime`（经典榜，永久）+ `snakefeast.best.weekly`（循环榜，每周重置） |
| 登录 | 启动后静默认证；系统给出登录页时**仅在开局面板**自动弹一次，对局中绝不弹 |
| 提交 | 每局结束 `score > 0` 时同时提交两个榜；失败存 `gc-pending-score`，回前台 / 下次登录自动补交 |
| 历史回填 | 登录成功后把 `reverse-snake-best` 提交到总榜（接入 Game Center 前的老纪录不丢） |
| 结算页 | 分数下方名次条：`全球 #128 ↑34 · 好友 #3` + 新纪录标签；未登录 / 提交中 / 离线各有状态；下方「查看排行榜」 |
| 开局页 | 主按钮下方「全球排行」次级按钮 |
| 排行榜面板 | 自绘深色能量卡片；全球 / 好友 / 本周三 Tab；前 50 名（前三金银铜）；底部固定「我」行（橙色）；下拉刷新；60s 缓存 |
| 系统界面 | 页脚「在 Game Center 中查看」：iOS 18+ 走 `GKAccessPoint.trigger`（iOS 26 打开「游戏」App 浮层），iOS 16–17 回退 `GKGameCenterViewController` |
| 未登录 | 面板显示登录引导 + 本机最高；本次启动尚可弹登录页时显示「登录 Game Center」按钮 |

**App Store Connect 配置（上线前必做，Xcode 侧已完成）**

1. Certificates, IDs & Profiles：App ID `com.woodystudio.reversesnake` 勾选 Game Center（自动签名一般会自动同步）。
2. App Store Connect → App → 功能 → Game Center → 新建排行榜：

| 参考名称 | 排行榜 ID | 类型 | 分数格式 | 排序 | 分数范围 |
|---|---|---|---|---|---|
| All-Time Best | `snakefeast.best.alltime` | 经典 | 整数 | 从高到低 | 0–999 |
| Weekly Best | `snakefeast.best.weekly` | 循环（每周，周一 00:00 开始） | 整数 | 从高到低 | 0–999 |

3. 两个榜各加本地化：简体中文「全球最高分 / 本周最高分」、繁体中文「全球最高分 / 本週最高分」、英文「All-Time Best / Weekly Best」，分数格式后缀「分 / points」。
4. 版本页 → 勾选 Game Center 并关联这两个排行榜（**不勾选会导致带 Game Center 权限的构建无法提交审核**）。
5. 分类：游戏 › 街机。中国大陆上架需游戏版号。
6. 排行榜一经上线**不可删除、ID 不可复用**；分数范围 0–999 用于挡掉明显作弊分。

**测试**：真机 / 模拟器在「设置 → Game Center」登录沙盒或真实账号；排行榜在 App Store Connect 创建后几分钟内生效，提交后名次有数秒延迟。

**DEBUG 调试参数**（仅 Debug 构建；模拟器 Game Center 无数据时用于验 UI）：

```bash
xcrun simctl launch booted com.woodystudio.reversesnake -GCMock ranked -GCShowBoard YES    # 已登录 + 50 条假数据，直接打开排行榜
xcrun simctl launch booted com.woodystudio.reversesnake -GCMock ranked -GCDebugOver YES    # 直接进入结算页看名次条
xcrun simctl launch booted com.woodystudio.reversesnake -GCMock signedout -GCShowBoard YES # 未登录态
```

## 功能对照（网页版 → iOS 等效实现）

| 网页版 | iOS 版 | 说明 |
|---|---|---|
| Canvas 2D `render()` | `UIView.draw(_:)` + `CGContext` | 深空渐变、精密网格、扫描带、四角准星、GRID 铭牌、蛇能量脊节/蛇头、玩家信标、晶体锁定环、粒子、逼近红色边缘光、3 秒倒计时，逐项 1:1 移植 |
| `requestAnimationFrame` | `CADisplayLink` | 同一 90ms dt 上限 |
| WebAudio `OscillatorNode` | `AVAudioEngine` + `AVAudioPlayerNode` PCM buffer | sine / triangle / sawtooth，指数衰减包络；开始 520、得分 660、冲刺 300、断尾 230、死亡 150Hz |
| — | `UIFeedbackGenerator`（iOS 原生增强） | 按事件分级震动，详见下方「震动反馈」 |
| `localStorage` | `UserDefaults` | `reverse-snake-best`（最高分）、`reverse-snake-sound`（音效开关，iOS 额外持久化）、`gc-pending-score`（待补交的 Game Center 成绩） |
| `touchstart/move/end` | `touchesBegan/Moved/Ended` | 16pt 阈值、连续转向、点按冲刺、`touchesCancelled` 兜底 |
| CSS `@keyframes shake` / 脉冲 / `scorePop` | `GeometryEffect` + SwiftUI `withAnimation` | 死亡抖动、LIVE 呼吸灯、得分数字放大高亮 |
| `backdrop-filter: blur(3px)` | `UIVisualEffectView(.dark)` | 面板下的棋盘仍隐约可见 |
| CSS 媒体查询 / `env(safe-area-inset)` / `visualViewport.resize` | `GeometryReader` + `LayoutMetrics` + SwiftUI safe area | 动态网格铺满屏幕；旋转 / 分屏自动重排并重开一局；刘海与 Home Indicator 避让 |

**音频会话**：`AVAudioSession.setCategory` / `setActive` 是同步 IPC，主线程调用会触发 Xcode 的 AVAudioSession Hang Risk 诊断（"This method can lead to UI unresponsiveness..."）。所有会话与引擎初始化都在串行队列 `sessionQueue` 执行；iOS 27+ 走 `activate(options:completionHandler:)` 异步激活，iOS 16–26 走队列内同步激活兜底。`ReverseSnakeApp.init()` 预热 `SoundEngine.shared`，避免首次音效因懒加载丢失。

**震动反馈**（iOS 原生增强，`Haptics.swift`）：按事件分级，刻意避开高频节点，避免震成一片。

| 节点 | 反馈 |
|---|---|
| 开始 / 重开 / 暂停 / 继续 / 音效开关 | `UISelectionFeedbackGenerator` |
| 倒计时 2 / 1 | `UIImpactFeedbackGenerator(.light)` |
| 倒计时结束起跑 | `.medium` |
| 点按冲刺 | `.rigid` |
| 吃到晶体 | `UISelectionFeedbackGenerator` |
| 蛇自锁断尾 | `.soft` |
| 撞蛇身 / 被追上 | `UINotificationFeedbackGenerator(.error)` |
| 滑动转向、蛇每步移动 | 不震动 |

所有触发保证在主线程；`prepare()` 在 App 启动时预热，每次触发后重新预热以降低延迟。震动无独立开关，与音效开关解耦。

## 玩法规则（与网页版一致）

- 吃掉青绿晶体 +1 分；蛇立刻 +2 节，追击速度同步提升（235ms → 108ms/格，玩家固定 112ms/格）。
- 撞上任意一节蛇身（含头、尾）或被蛇头抓到即结束；墙只挡路，不致死。
- 蛇用 BFS 追击，每 2 步才重算方向（转向惯性，急转弯可甩开）；追不到时用 flood fill 保空间；自锁时断尾脱困。
- 晶体生成在玩家可达、且与蛇头保持 8–13 格动态距离的区域。
- HUD：SCORE / BEST / LENGTH / SPACE（flood fill 实时计算，<30% 变红）/ THREAT，含状态灯、贯穿式追击能量条。

## 验证记录（本机 Xcode 27.2 / iOS Simulator）

- 等宽对齐：像素采样验证 iPhone（1206px 宽截图）上 HUD 与舞台左右边界同为 x24..1182；旧版舞台为 x60..1146（每侧窄约 11pt）。iPad 同样对齐，棋盘格子尺寸与位置未变。
- `xcodebuild ... clean build` → **BUILD SUCCEEDED**（无任何额外命令行参数），产物 `MinimumOSVersion = 16.0`。
- iPhone 16 Pro（iOS 18.6，动态网格 16×29）、iPad Pro 11-inch（M4，19×25）均安装、启动、运行无崩溃。
- 实测截图覆盖：开始页（精简提示）、游戏进行中（棋盘/蛇/玩家/晶体/HUD）、结算页、暂停页；棋盘上下左右留白极小，两种设备均无裁切、无溢出。
- AppIcon 与 Logo 已验证：主屏幕显示深空网格 / 橙点 / 青色能量蛇 / 青绿晶体图标；iPhone / iPad 顶栏 Logo 与标题、三个按钮无重叠。
- 图标重设计「S-Chase」（极简版）：`xcodebuild build` 成功；iPhone 16 Pro 卸载重装后主屏显示新图标（深海军蓝底 + S 形能量蛇 + 橙色玩家光球），顶栏 26pt Logo 清晰、与标题无重叠；AppIcon / Logo PNG 均为不透明（`hasAlpha: no`），满足 App Store 要求。
- 新增 `Haptics.swift` 并接入 9 类事件节点；`xcodebuild build` 成功、模拟器启动无崩溃、无 haptic 运行时错误。模拟器不产生真实触觉，手感需真机体验。
- 开局 / 暂停 / 结算三面板重做为深色能量卡片，iPhone 三状态截图 + iPad 开局截图验证：铭牌完整、操作芯片醒目、分数与 KPI 清晰、无裁切与重叠。
- 顶栏 3 个文字按钮改为深色能量图标按钮（SF Symbols），iPhone / iPad 截图验证与 HUD / Logo 视觉统一、无布局重叠；5 个符号名称经系统校验有效。
- 修复 Xcode AVAudioSession Hang Risk 诊断：音频会话初始化移出主线程（iOS 27+ 异步 activate，旧系统串行队列），冷启动日志确认 `AVAudioEngine` 正常 `start`、无主线程卡顿诊断。
- 修复项：Core Graphics 径向渐变默认不绘制起始半径内区域，导致棋盘中心出现黑洞；已改用 `.drawsBeforeStartLocation` + `.drawsAfterEndLocation`，与 Canvas 2D 行为一致。
- 工程曾被 Xcode 自动升级写入 `IPHONEOS_DEPLOYMENT_TARGET = 27.0`（导致装不进 iOS 18.6 模拟器），已恢复为 16.0；Bundle ID 保持 `com.woodystudio.reversesnake`。
- 改名 Snake Feast：`xcodebuild build` → **BUILD SUCCEEDED**，产物 `Info.plist` 的 `CFBundleDisplayName = "Snake Feast"`，`CFBundleIdentifier` / `MinimumOSVersion` 未变；iPhone 16 Pro 与 iPad Pro 11 英寸截图验证顶栏显示 `SNAKE FEAST`（双色）无截断、无重叠，主屏图标名显示 `Snake Feast`，界面内无旧名残留。
- 多语言：`plutil -lint` 校验 `project.pbxproj` 与 4 份 `.strings` 均 OK；静态校验 4 份文案各 42 个 key，与 `L10n.K` 常量零差异；产物含 `en / en-US / zh-Hans / zh-Hant` 四个 `.lproj`。用 `-AppleLanguages` 分别启动，iPhone 16 Pro 上验证简体 / 繁体 / 英文（美国）的开局、暂停、结算面板与倒计时 CG 文案，iPad Pro 11 英寸验证英文 / 简体 HUD 主副标签；三种语言均无残留、无截断重叠。英文开局文案经缩短后保持 3 行，不撑高面板。

- 全球排行榜（Game Center）：Debug / Release `xcodebuild build` 均 **BUILD SUCCEEDED**，无新增编译警告；4 份文案各 69 个 key，与 `L10n.K` 零差异。iPhone 16 Pro 截图验证开局面板「全球排行」按钮、结算页名次条与「查看排行榜」、排行榜面板（前三奖牌色 / 50 行列表 / 固定「我」行 / 页脚）、未登录态、英文版；iPad Pro 11 英寸验证排行榜面板居中 470pt。关闭按钮与页脚已避开四角准星。真实 Game Center 数据需在 App Store Connect 配置排行榜后用真机验证。

## 备注

- 震动无独立开关（跟随系统 Taptic 能力），与音效开关解耦；如需可控，可加第 4 个顶栏按钮或跟随 `soundOn`。
- AppIcon / Logo 由 `Design/generate_icon.swift`（macOS Core Graphics 脚本，无依赖）生成，v2 概念「S 进化」：扁平 S 形蛇（尾左下暗细 → 头右上亮粗，夜行色板，无外发光）+ 蛇头前方橙色玩家光点；`icon` / `dark` / `tinted` 三种模式对应 iOS 18 主屏默认 / 深色 / 着色外观，均为 1024×1024 不透明 PNG。主页品牌位 Logo 即默认图标缩放。重新生成：
  ```bash
  swiftc -O Design/generate_icon.swift -o /tmp/sf-icon-gen
  A=ReverseSnake/Assets.xcassets/AppIcon.appiconset; L=ReverseSnake/Assets.xcassets/Logo.imageset
  /tmp/sf-icon-gen $A/Icon-1024.png icon
  /tmp/sf-icon-gen $A/Icon-1024-Dark.png dark
  /tmp/sf-icon-gen $A/Icon-1024-Tinted.png tinted
  for z in 128:Logo 256:Logo@2x 384:Logo@3x; do sips -z ${z%%:*} ${z%%:*} $A/Icon-1024.png --out $L/${z#*:}.png; done
  ```
- `Assets.xcassets` 已加入 Resources Build Phase，`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`；LaunchScreen 由 `UILaunchScreen_Generation` 自动生成。
- `GENERATE_INFOPLIST_FILE = YES` 时 `CFBundleName` 由 `PRODUCT_NAME` 固定生成（`ReverseSnake`），`INFOPLIST_KEY_CFBundleName` build setting 不生效；用户可见名称由 `CFBundleDisplayName` 决定，改游戏名只需改这一项 + 顶栏文案。
- 真机部署需在 Target → Signing & Capabilities 里选择自己的 Development Team（工程已开启 Automatic 签名）。
## App Store 上架资料

- `AppStore/ASC-提交资料.html`：三语言元数据、合规答案、提交清单
- `AppStore/screenshots/<语言>/`：`iphone-6.3`（1206×2622，必传）、`iphone-duo-inner`（2007×2853）、`iphone-duo-outer`（1398×2034）、`ipad-13`（2064×2752）、`iphone-6.9`（可选）
- 隐私政策 / 技术支持页在仓库根目录 `privacy.html` / `support.html`（GitHub Pages）
