# Reverse Snake · iOS 版（Swift）

网页版 `../index.html`（v1.6 反向贪吃蛇）的原生 iOS 移植。完整保留玩法、流程、视觉、音效与存档规则，纯 Swift + SwiftUI + Core Graphics 实现，**无第三方依赖、无 Storyboard**，自带 `Assets.xcassets`（AppIcon + 左上角 Logo），可直接打开工程编译运行。

- 目标设备：iPhone + iPad（`TARGETED_DEVICE_FAMILY = 1,2`）
- 最低系统：iOS 16.0
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
    ├── ReverseSnakeApp.swift        # @main App 入口（含音频预热）
    ├── Theme.swift                  # 调色板 + LayoutMetrics + 动态网格计算
    ├── GameEngine.swift             # 状态机 / 蛇 AI / BFS / flood fill / 计分 / 粒子 / 存档
    ├── SoundEngine.swift            # AVAudioEngine 波形合成（WebAudio 等价）
    ├── GameBoardView.swift          # UIView + CGContext 渲染、CADisplayLink、触控
    ├── HUDView.swift                # 5 项深色能量仪表 HUD
    ├── OverlayViews.swift           # 开始 / 暂停 / 结算面板 + 毛玻璃遮罩（全部提示在这里）
    ├── ControlsView.swift           # 左上角 Logo + 顶部按钮（暂停 / 音效 / 重开）
    └── ContentView.swift            # 满屏棋盘布局、动态网格、抖动动画、前后台暂停
```

调参入口：`GameEngine.swift` 顶部常量（`playerMS / snakeBase / snakeMin / planSteps / grow / dashCD / dirs`），与网页版 `config` 区一一对应。

**动态网格**：`LayoutMetrics.gridDimensions(available:)` 按舞台实际宽高比计算列/行，总格数维持约 468（与网页版 18×26 / 26×18 同为 468），因此棋盘几乎铺满整屏而难度不变。iPhone 竖屏实测 16×29、iPad 竖屏 19×25。旋转或分屏导致网格形状变化时按网页版 `relayout()` 行为重开一局。

## 操作

| 触控 | 作用 |
|---|---|
| 棋盘上滑动 | 设定持续移动方向，可连续拐弯 |
| 点按棋盘 | 冲刺 2 格（CD 2.6s） |
| 顶部按钮 | 暂停 / 继续、音效开关、重开 |

开始前提示面板只保留一句话玩法说明与「棋盘上滑动转向 · 点按冲刺」，游戏中不占任何屏幕空间。暂停、重开、音效都走顶部按钮。App 退到后台自动暂停。

> 虚拟方向键、外接键盘支持、底部手势提示 / 玩法说明、角落版本号、`P` / `R` / `Return` 等键盘文案均已移除，只保留滑动玩法。

## 功能对照（网页版 → iOS 等效实现）

| 网页版 | iOS 版 | 说明 |
|---|---|---|
| Canvas 2D `render()` | `UIView.draw(_:)` + `CGContext` | 深空渐变、精密网格、扫描带、四角准星、GRID 铭牌、蛇能量脊节/蛇头、玩家信标、晶体锁定环、粒子、逼近红色边缘光、3 秒倒计时，逐项 1:1 移植 |
| `requestAnimationFrame` | `CADisplayLink` | 同一 90ms dt 上限 |
| WebAudio `OscillatorNode` | `AVAudioEngine` + `AVAudioPlayerNode` PCM buffer | sine / triangle / sawtooth，指数衰减包络；开始 520、得分 660、冲刺 300、断尾 230、死亡 150Hz |
| `localStorage` | `UserDefaults` | `reverse-snake-best`（最高分）、`reverse-snake-sound`（音效开关，iOS 额外持久化） |
| `touchstart/move/end` | `touchesBegan/Moved/Ended` | 16pt 阈值、连续转向、点按冲刺、`touchesCancelled` 兜底 |
| CSS `@keyframes shake` / 脉冲 / `scorePop` | `GeometryEffect` + SwiftUI `withAnimation` | 死亡抖动、LIVE 呼吸灯、得分数字放大高亮 |
| `backdrop-filter: blur(3px)` | `UIVisualEffectView(.dark)` | 面板下的棋盘仍隐约可见 |
| CSS 媒体查询 / `env(safe-area-inset)` / `visualViewport.resize` | `GeometryReader` + `LayoutMetrics` + SwiftUI safe area | 动态网格铺满屏幕；旋转 / 分屏自动重排并重开一局；刘海与 Home Indicator 避让 |

**音频会话**：`AVAudioSession.setCategory` / `setActive` 是同步 IPC，主线程调用会触发 Xcode 的 AVAudioSession Hang Risk 诊断（"This method can lead to UI unresponsiveness..."）。所有会话与引擎初始化都在串行队列 `sessionQueue` 执行；iOS 27+ 走 `activate(options:completionHandler:)` 异步激活，iOS 16–26 走队列内同步激活兜底。`ReverseSnakeApp.init()` 预热 `SoundEngine.shared`，避免首次音效因懒加载丢失。

## 玩法规则（与网页版一致）

- 吃掉青绿晶体 +1 分；蛇立刻 +2 节，追击速度同步提升（235ms → 108ms/格，玩家固定 112ms/格）。
- 撞上任意一节蛇身（含头、尾）或被蛇头抓到即结束；墙只挡路，不致死。
- 蛇用 BFS 追击，每 2 步才重算方向（转向惯性，急转弯可甩开）；追不到时用 flood fill 保空间；自锁时断尾脱困。
- 晶体生成在玩家可达、且与蛇头保持 8–13 格动态距离的区域。
- HUD：SCORE / BEST / LENGTH / SPACE（flood fill 实时计算，<30% 变红）/ THREAT，含状态灯、贯穿式追击能量条。

## 验证记录（本机 Xcode 27.2 / iOS Simulator）

- `xcodebuild ... clean build` → **BUILD SUCCEEDED**（无任何额外命令行参数），产物 `MinimumOSVersion = 16.0`。
- iPhone 16 Pro（iOS 18.6，动态网格 16×29）、iPad Pro 11-inch（M4，19×25）均安装、启动、运行无崩溃。
- 实测截图覆盖：开始页（精简提示）、游戏进行中（棋盘/蛇/玩家/晶体/HUD）、结算页、暂停页；棋盘上下左右留白极小，两种设备均无裁切、无溢出。
- AppIcon 与 Logo 已验证：主屏幕显示深空网格 / 橙点 / 青色能量蛇 / 青绿晶体图标；iPhone / iPad 顶栏 Logo 与标题、三个按钮无重叠。
- 修复 Xcode AVAudioSession Hang Risk 诊断：音频会话初始化移出主线程（iOS 27+ 异步 activate，旧系统串行队列），冷启动日志确认 `AVAudioEngine` 正常 `start`、无主线程卡顿诊断。
- 修复项：Core Graphics 径向渐变默认不绘制起始半径内区域，导致棋盘中心出现黑洞；已改用 `.drawsBeforeStartLocation` + `.drawsAfterEndLocation`，与 Canvas 2D 行为一致。
- 工程曾被 Xcode 自动升级写入 `IPHONEOS_DEPLOYMENT_TARGET = 27.0`（导致装不进 iOS 18.6 模拟器），已恢复为 16.0；Bundle ID 保持 `com.woodystudio.reversesnake`。

## 备注

- Logo / AppIcon 由 `Design/generate_icon.swift`（macOS Core Graphics 脚本，无依赖）生成：`icon` 模式输出 1024×1024 完整构图 AppIcon，`mark` 模式输出紧凑方形 Logo（去掉准星 / 晶体 / 密网格，放大两要素以适配 26pt）。重新生成：
  ```bash
  swiftc -O Design/generate_icon.swift -o /tmp/rs-icon-gen
  /tmp/rs-icon-gen <output.png> icon   # 或 mark
  ```
- `Assets.xcassets` 已加入 Resources Build Phase，`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`；LaunchScreen 由 `UILaunchScreen_Generation` 自动生成。
- 真机部署需在 Target → Signing & Capabilities 里选择自己的 Development Team（工程已开启 Automatic 签名）。
