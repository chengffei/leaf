# Development

Leaf 的定位是**快捷打开的纯阅读器**：双击打开 → 读 → 关窗即退出。不做书架、不做导入、不复制文件。新功能请先对照这一条。

## 构建

需要 Xcode 26 与 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。工程文件由 `project.yml` 生成，改配置请改 yml，不要改 pbxproj。

```sh
xcodegen generate
./scripts/install.sh   # Release 构建 → /Applications/Leaf.app（Leaf 正在运行时会拒绝）
./scripts/make-dmg.sh  # 打 DMG，默认输出到 ~/Downloads/Leaf-<版本>.dmg
```

只编译调试版：

```sh
xcodebuild -project Leaf.xcodeproj -scheme Leaf -configuration Debug \
  -derivedDataPath .build/DerivedData build
```

若 `xcode-select` 指向的是 Command Line Tools，命令前加 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`（两个脚本已自带）。

## 架构

| 层 | 文件 | 职责 |
|---|---|---|
| 文档 | `BookDocument.swift` | `DocumentGroup(viewing:)` 只读；整本读入内存，SHA-256 作为书的身份 |
| 桥 | `BookSchemeHandler.swift` | `leaf://app/*` 读 bundle 里的 `Web/`；`leaf://app/book` 给出当前书的字节（必须与页面同源，跨 host 会被 fetch 拦截） |
| 窗口 | `BookWindow.swift` `ReaderModel.swift` | `NavigationSplitView`：左侧原生目录侧栏（目录由 JS 压平回传，选中态 = 当前章节，点选 = 跳转），侧栏头部显示书名与作者；`WindowChrome` 隐藏窗口标题，红绿灯与工具栏仅在目录打开、Aa 面板打开或鼠标停在顶部时淡入；主题的浅 / 深色靠 `.preferredColorScheme` 改窗口外观 |
| 视图 | `ReaderView.swift` | `WKWebView`（`ReaderWebView` 子类接管右键菜单：保留系统的拷贝 / 查询 / 翻译，加翻页、目录、查找、设置）；接收 JS 消息：relocate 存进度、外链交给浏览器；只放行 leaf / blob / about / data |
| 设置 | `ReaderSettings.swift` `SettingsView.swift` `TypographyPanel.swift` | 全局设置，`ReaderPrefs` 整包 JSON 推给页面。`SettingsView` 是「设置… ⌘,」窗口（全部选项）；`TypographyPanel` 是工具栏 Aa 弹层（只有字号和主题）。字号 = 书页根字号 `html { font-size: N% }`（作用于 em / rem / % 字号，写死 px 的书不受影响）；行距三档以 `!important` 覆盖书本；页边距三档 = foliate 的 `gap` / `margin` 属性（数值在 app.js `MARGINS`）；字体 原书 / 黑体 / 宋体 / 任意已安装家族（`NSFontManager`）；版心宽度四档 + 分栏三档 = foliate 的 `max-inline-size` / `max-column-count`；主题四档 |
| 状态 | `ReadingPosition.swift` | 阅读位置：`UserDefaults["position.<sha256>"] = CFI`。另有两项小状态存在 WebView 的 localStorage（`leaf.progressMode` 进度指示模式、`leaf.readingSpeed` 阅读速度样本），所有书共用 |
| 渲染 | `Web/app.js` + `Web/foliate/` | [foliate-js](https://github.com/johnfactotum/foliate-js) 内置（版本见 `Web/foliate/VERSION`，移除了 PDF / OPDS / 示例）。**本地补丁只有一处**：`paginator.js` 把 `max-column-count-portrait` 开放为属性（上游写死竖窗 1 栏），升级时要重打 |
| 图标 | `Leaf/Leaf.icon` | Icon Composer 格式，两层手写 SVG |
| 介绍页 | `scripts/site/index.template.html` `scripts/site/build.py` | **改模板，不要直接改 `docs/*.html`**。`python3 scripts/site/build.py` 生成 `docs/index.html`（英文）与 `docs/zh/index.html`（中文），每页只保留本语言；版本号取自 `project.yml`，FAQ 结构化数据从页面 FAQ 解析。`docs/llms.txt`、`docs/sitemap.xml` 手工维护 |
| 安装包 | `scripts/make-dmg.sh` `scripts/dmg/background.swift` | 背景图由脚本绘制；窗口 640×460，图标中心 (170,150) / (470,150) 与背景箭头对齐，挪图标须同步改箭头坐标 |

调试：Debug 构建开启了 `isInspectable`，可在 Safari ›「开发」菜单里检查 Leaf 的页面。JS 端的报错与 `console.error/warn` 会转发到系统日志（subsystem `com.chengffei.leaf`）。

## 踩过的坑

- **沙盒里的 WKWebView 需要 `com.apple.security.network.client`**，否则 WebContent 进程直接崩溃、页面全空。书始终只从本地读取。
- **foliate 的 `goTo` 失败只打日志不抛错**，页面会静默留白。`app.js` 已兜底：初始化后未渲染则退回第一节。
- **不要用 `WKWebView.pageZoom` 调字号**：非 100% 时 foliate 分页混用缩放前后的尺寸，右侧会露出半截下一栏。
- **章首空白栏**：书的 CSS 常给章节标题加 `page-break-before: always`，WebKit 多栏把它当断栏，每章前多出一整栏空白。`app.js` 只对每段开头那串元素取消断开。
- **侧栏遮挡**：正文视图若 `ignoresSafeArea()` 全部边，会铺到浮动侧栏下面；只忽略顶部。
- **脚注弹窗**：用 foliate 自带的 `FootnoteHandler` 识别（epub:type、role、上标三种）。注释视图必须在 `before-render` 时就挂进页面，iframe 不在文档里没有 `contentDocument`；主视图的 `foliate-view` 定位规则要限定 `body >`，否则会套到卡片里。
- **返回**：foliate 每次 `goTo` 压一条历史，翻页只改写当前那条，`history.back()` 回到跳走前实际读到的位置。「返回」提示按用户亲手翻页计数收起，别用 relocate 计数（一次跳转会触发好几次）。
- **标题字号上限**：转换书常把标题设成正文 2.5 倍，`capHeadings` 把超过 1.8 倍的压到 1.8 倍（rem 写法，调字号仍等比）；标题行高统一 1.35。
- **目录折叠**：JS 回传压平的目录，`ReaderModel.setTOC` 按深度补父子关系。超过 50 条且有层级时默认只展开当前那一支；当前章节被折叠时高亮最近的可见祖先，不强行展开。
- **深色模式黑字**：很多书在行内写死 `color:rgb(0,0,0)`，深底上看不见。`app.js` 的 `markDarkText` 在每节加载时给深灰到纯黑的元素打 `data-leaf-dark`，`bookCSS` 只在深色模式把它们改成 `CanvasText`；有色相的字（红、蓝强调）不动。
- **深色模式白底**：Gutenberg 等书写死 `body { background: white }`，配上上面改白的字就整页看不见。深色（跟随系统或强制）时 `THEME_CSS.dark` 把 `html` 底色压成深灰、`body` 透明；米黄同理染色。
- **主题切换**：浅 / 深靠 SwiftUI `.preferredColorScheme` 改窗口外观，WebView 的 `prefers-color-scheme` 跟着变。直接改 `NSWindow.appearance` 会被 SwiftUI 覆盖回去，别走那条路。
- **分栏**：foliate 的栏数 = `min(max-column-count, ceil(宽度 / max-inline-size))`，竖窗另有上限 `--_max-column-count-portrait`（上游写死 1，已补丁为属性）。「双栏」把每栏上限压到半个窗口并在 resize 时重算。
- **右键菜单**：`WKWebView.willOpenMenu` 里按 identifier 后缀（`Copy` / `LookUp` / `Translate`）筛系统项，其余换成自己的；系统会再追加「服务」子菜单，拦不掉。打开设置窗口只能用 SwiftUI 环境里的 `openSettings`（`BookWindow` 塞进 `ReaderModel`），`NSApp.sendAction(showSettingsWindow:)` 在 macOS 15 上无效。
- **进度指示**：foliate 的 `relocate` 带 `location`（1 位置 = 1500 字节）和 `time`（按固定 1600 字节/分钟算）。Leaf 把 `time` 换回剩余字节，再除以本人速度：每次亲手翻页（`turn()`）记时刻与字节位置，下一次 relocate 时把间隔（2 秒到 5 分钟之内才算）和推进字节累计进样本；样本不足 3 分钟显示「测算中」，超过 120 分钟按半衰减淡出旧样本。
- **查找**：`view.search()` 是异步生成器，整本逐节扫；第一处命中立刻跳转，计数边扫边更新；换关键词时用 run 计数器作废旧搜索。
- **标题与工具栏**：别用 `.toolbar(removing: .title)`，工具栏会向左收拢、Aa 挤到目录按钮旁；改用 `titleVisibility = .hidden` 加 `ToolbarSpacer(.flexible)`。窗口标题不能露出来：书页自带白底（如封面）会铺到标题下，深色模式的浅色标题字被盖住。
- **SF Symbol 会随系统语言本地化**（`textformat.size` 在中文下显示「大小」），工具栏按钮固定用英文变体。
- **放大快捷键绑 `=`**：绑 `+` 时 `⌘=` 不触发。
- **构建目录里的 .app 会被 LaunchServices 登记**，Finder 可能打开旧版；`install.sh` 会注销它们并刷新图标缓存。
- **GUI 自动化测试**（`scripts/ax.swift`）会真实点击窗口：启动时加 `--args -ApplePersistenceIgnoreState YES` 避免恢复你正在读的书，脚本只对标题以 `alice` / `hongloumeng` 开头的窗口动手。
- 下载的测试书可能不完整：先 `unzip -t`（EPUB）或检查 PDB 末记录偏移（MOBI/AZW3），再怀疑代码。

## 测试书

`TestBooks/` 收录 Project Gutenberg 的公有领域书籍：《爱丽丝梦游仙境》的 EPUB / AZW3 / MOBI 三种格式，以及《紅樓夢》EPUB（中文排版）。
