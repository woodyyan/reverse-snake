# Snake Feast · iOS 版（Swift）

网页版 `../index.html`（v1.6）的原生 iOS 移植，iOS 版游戏名为 **Snake Feast**。完整保留玩法、流程、视觉、音效与存档规则，纯 Swift + SwiftUI + Core Graphics 实现，**无第三方依赖、无 Storyboard**，自带 `Assets.xcassets`（AppIcon + 左上角 Logo），可直接打开工程编译运行。

> 命名说明：只改了用户可见的游戏名（主屏 App 显示名 `CFBundleDisplayName`、顶栏品牌文字、本文档标题）。工程目录、Xcode 工程 / scheme / target / product 名、Bundle ID、`UserDefaults` key 等内部标识一律保留，避免破坏构建、仓库一致性和已保存的最高分。

- 目标设备：iPhone + iPad（`TARGETED_DEVICE_FAMILY = 1,2`）
- 最低系统：iOS 16.0
- 多语言：简体中文 / 繁体中文 / 英文（美国），跟随系统自动切换
- 方向：iPhone 竖屏 / 横屏，iPad 四方向；支持旋转、分屏（Split View）与安全区
- Bundle ID：`com.woodystudio.reversesnake`，版本号 1.6（与网页版一致）

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
    ├── Theme.swift                  # 调色板 + LayoutMetrics + 动态网格计算
    ├── GameEngine.swift             # 状态机 / 蛇 AI / BFS / flood fill / 计分 / 粒子 / 存档
    ├── SoundEngine.swift            # AVAudioEngine 波形合成（WebAudio 等价）
    ├── Haptics.swift                # UIFeedbackGenerator 震动反馈（按事件分级）
    ├── GameBoardView.swift          # UIView + CGContext 渲染、CADisplayLink、触控
    ├── HUDView.swift                # 5 项深色能量仪表 HUD
    ├── OverlayViews.swift           # 深色能量弹框（开局 / 暂停 / 结算）+ 毛玻璃遮罩 + 高亮操作提示
    ├── ControlsView.swift           # 左上角 Logo + 深色能量图标按钮（暂停 / 音效 / 重开）
    └── ContentView.swift            # 满屏棋盘布局、动态网格、抖动动画、前后台暂停
```

调参入口：`GameEngine.swift` 顶部常量（`playerMS / snakeBase / snakeMin / planSteps / grow / dashCD / dirs`），与网页版 `config` 区一一对应。

**动态网格**：`LayoutMetrics.gridDimensions(available:)` 按舞台实际宽高比计算列/行，总格数维持约 468（与网页版 18×26 / 26×18 同为 468），因此棋盘几乎铺满整屏而难度不变。iPhone 竖屏实测 16×29、iPad 竖屏 19×25。旋转或分屏导致网格形状变化时按网页版 `relayout()` 行为重开一局。

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

- 文案全部收进 `*.lproj/Localizable.strings`，共 42 个 key，与 `Localization.swift` 的 `L10n.K` 常量一一对应；`en` 与 `en-US` 内容一致。
- SwiftUI 侧统一用 `L10n.t(key)`（`LocalizedStringKey`）；Core Graphics 绘制的 `GRID` 铭牌、`GO`、倒计时提示用 `L10n.s(key)`（按 `Locale.preferredLanguages` 逐级匹配 `xxx-YY → xxx`，带表缓存）。
- `LocalizationCenter` 监听 `NSLocale.currentLocaleDidChangeNotification`，通过 `.environment(\.locale, ...)` 注入新 Locale，语言变化后无需重建视图树、也不会重置对局状态；系统若选择重启 App 则照常重启。
- `GameEngine` 只存 key（`stateKey` / `overReasonKey`），由视图在渲染时解析，避免语言切换后残留旧文案。
- **不翻译**：品牌名 `SNAKE FEAST`、主屏 App 名 `Snake Feast`、数字 / 百分比 / 倒计时数字、Bundle ID 与工程内部标识。

新增文案流程：在 4 份 `.strings` 里加同名的 `"key" = "value";` → 在 `L10n.K` 加常量 → 视图用 `L10n.t(...)` / `L10n.s(...)`。`project.pbxproj` 用 `PBXVariantGroup` 管理这 4 份文件，新增语言需同步加 child 与 `knownRegions`。

## 功能对照（网页版 → iOS 等效实现）

| 网页版 | iOS 版 | 说明 |
|---|---|---|
| Canvas 2D `render()` | `UIView.draw(_:)` + `CGContext` | 深空渐变、精密网格、扫描带、四角准星、GRID 铭牌、蛇能量脊节/蛇头、玩家信标、晶体锁定环、粒子、逼近红色边缘光、3 秒倒计时，逐项 1:1 移植 |
| `requestAnimationFrame` | `CADisplayLink` | 同一 90ms dt 上限 |
| WebAudio `OscillatorNode` | `AVAudioEngine` + `AVAudioPlayerNode` PCM buffer | sine / triangle / sawtooth，指数衰减包络；开始 520、得分 660、冲刺 300、断尾 230、死亡 150Hz |
| — | `UIFeedbackGenerator`（iOS 原生增强） | 按事件分级震动，详见下方「震动反馈」 |
| `localStorage` | `UserDefaults` | `reverse-snake-best`（最高分）、`reverse-snake-sound`（音效开关，iOS 额外持久化） |
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
- 新增 `Haptics.swift` 并接入 9 类事件节点；`xcodebuild build` 成功、模拟器启动无崩溃、无 haptic 运行时错误。模拟器不产生真实触觉，手感需真机体验。
- 开局 / 暂停 / 结算三面板重做为深色能量卡片，iPhone 三状态截图 + iPad 开局截图验证：铭牌完整、操作芯片醒目、分数与 KPI 清晰、无裁切与重叠。
- 顶栏 3 个文字按钮改为深色能量图标按钮（SF Symbols），iPhone / iPad 截图验证与 HUD / Logo 视觉统一、无布局重叠；5 个符号名称经系统校验有效。
- 修复 Xcode AVAudioSession Hang Risk 诊断：音频会话初始化移出主线程（iOS 27+ 异步 activate，旧系统串行队列），冷启动日志确认 `AVAudioEngine` 正常 `start`、无主线程卡顿诊断。
- 修复项：Core Graphics 径向渐变默认不绘制起始半径内区域，导致棋盘中心出现黑洞；已改用 `.drawsBeforeStartLocation` + `.drawsAfterEndLocation`，与 Canvas 2D 行为一致。
- 工程曾被 Xcode 自动升级写入 `IPHONEOS_DEPLOYMENT_TARGET = 27.0`（导致装不进 iOS 18.6 模拟器），已恢复为 16.0；Bundle ID 保持 `com.woodystudio.reversesnake`。
- 改名 Snake Feast：`xcodebuild build` → **BUILD SUCCEEDED**，产物 `Info.plist` 的 `CFBundleDisplayName = "Snake Feast"`，`CFBundleIdentifier` / `MinimumOSVersion` 未变；iPhone 16 Pro 与 iPad Pro 11 英寸截图验证顶栏显示 `SNAKE FEAST`（双色）无截断、无重叠，主屏图标名显示 `Snake Feast`，界面内无旧名残留。
- 多语言：`plutil -lint` 校验 `project.pbxproj` 与 4 份 `.strings` 均 OK；静态校验 4 份文案各 42 个 key，与 `L10n.K` 常量零差异；产物含 `en / en-US / zh-Hans / zh-Hant` 四个 `.lproj`。用 `-AppleLanguages` 分别启动，iPhone 16 Pro 上验证简体 / 繁体 / 英文（美国）的开局、暂停、结算面板与倒计时 CG 文案，iPad Pro 11 英寸验证英文 / 简体 HUD 主副标签；三种语言均无残留、无截断重叠。英文开局文案经缩短后保持 3 行，不撑高面板。

## 备注

- 震动无独立开关（跟随系统 Taptic 能力），与音效开关解耦；如需可控，可加第 4 个顶栏按钮或跟随 `soundOn`。
- Logo / AppIcon 由 `Design/generate_icon.swift`（macOS Core Graphics 脚本，无依赖）生成：`icon` 模式输出 1024×1024 完整构图 AppIcon，`mark` 模式输出紧凑方形 Logo（去掉准星 / 晶体 / 密网格，放大两要素以适配 26pt）。重新生成：
  ```bash
  swiftc -O Design/generate_icon.swift -o /tmp/rs-icon-gen
  /tmp/rs-icon-gen <output.png> icon   # 或 mark
  ```
- `Assets.xcassets` 已加入 Resources Build Phase，`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`；LaunchScreen 由 `UILaunchScreen_Generation` 自动生成。
- `GENERATE_INFOPLIST_FILE = YES` 时 `CFBundleName` 由 `PRODUCT_NAME` 固定生成（`ReverseSnake`），`INFOPLIST_KEY_CFBundleName` build setting 不生效；用户可见名称由 `CFBundleDisplayName` 决定，改游戏名只需改这一项 + 顶栏文案。
- 真机部署需在 Target → Signing & Capabilities 里选择自己的 Development Team（工程已开启 Automatic 签名）。
