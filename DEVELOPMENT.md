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
| 桥 | `BookSchemeHandler.swift` | `leaf://app/*` 读 bundle 里的 `Web/`；`leaf://app/book` 给出当前书的字节（必须与页面同源，跨 host 会被 fetch 拦截）；FB2、FBZ、CBZ 带扩展名请求（`book.cbz`），foliate 只能靠文件名认这三种 |
| 窗口 | `BookWindow.swift` `ReaderModel.swift` | `ZStack`：正文铺满，左侧浮动玻璃面板 `TOCPanel`（宽 300，`regularMaterial`，不推挤正文、不重排书页）有两页：目录（JS 压平回传，选中态 = 当前章节，点选 = 跳转并收起）和查找（`SearchPanel`：原生输入框，停 300 毫秒即搜，结果按章节分组，JS 以 `search` 消息流式回传）；`WindowChrome` 隐藏窗口标题，红绿灯与工具栏仅在目录打开、Aa 面板打开或鼠标停在顶部时淡入；主题的浅 / 深色靠 `.preferredColorScheme` 改窗口外观 |
| 视图 | `ReaderView.swift` | `WKWebView`（`ReaderWebView` 子类接管右键菜单：保留系统的拷贝 / 查询 / 翻译，加翻页、目录、查找、设置）；接收 JS 消息：relocate 存进度、外链交给浏览器；只放行 leaf / blob / about / data |
| 设置 | `ReaderSettings.swift` `SettingsView.swift` `TypographyPanel.swift` | 全局设置，`ReaderPrefs` 整包 JSON 推给页面。`SettingsView` 是「设置… ⌘,」窗口（全部选项）；`TypographyPanel` 是工具栏 Aa 弹层（只有字号和主题）。字号 = 书页根字号 `html { font-size: N% }`（作用于 em / rem / % 字号，写死 px 的书不受影响）；行距三档以 `!important` 覆盖书本；页边距三档 = foliate 的 `gap` / `margin` 属性（数值在 app.js `MARGINS`）；字体 原书 / 黑体 / 宋体 / 任意已安装家族（`NSFontManager`）；字重 0 到 4 = `-webkit-text-stroke` 描边（任何字体都生效，不抹平标题粗细）；对齐、段距、字距见 app.js `prefsCSS`；版心宽度四档 + 分栏三档 = foliate 的 `max-inline-size` / `max-column-count`；主题四档。`Preset` 是一套排版（不含主题），内置四套在 `Preset.builtins`，自定义存 `UserDefaults["presets"]` |
| 竖排 | `ReaderSettings.WritingMode` + app.js `WRITING_CSS` `isVertical` `pageLeft/pageRight` | foliate 按章节 body 的 computed writing-mode 决定竖排分页（paginator `getDirection`），所以强制竖排 / 横排只是注入 `html, body { writing-mode: … !important }`，但只在章节加载时生效：`setPrefs` 发现 writing 变了就 `post({ type: 'reopen' })`，Swift 用 `ReaderView.pageURL` 带当前位置重开。竖排时 `max-inline-size` 管的是文字高度，`applyLayout` 改成撑满、单栏；章节 `load` 后再调一次 `applyLayout`（原书竖排要等文档加载才知道）。翻页：从右往左的书（`book.dir === 'rtl'`）和竖排书左边是下一页，键盘、点击区、触控板横滑都走 `pageLeft/pageRight`，别用 foliate 的 goLeft/goRight（只看 book.dir，强制竖排的横排书会反）。日韩字体：`cjkFontCSS` 按 `html:lang(ja|ko)` 覆盖内置黑体 / 宋体 / Literata 栈。测试书 `TestBooks/neko-*.epub` |
| 状态 | `ReadingPosition.swift` | 阅读位置：`UserDefaults["position.<sha256>"] = CFI`。另有两项小状态存在 WebView 的 localStorage（`leaf.progressMode` 进度指示模式、`leaf.readingSpeed` 阅读速度样本），所有书共用。设置「通用 › 阅读记录」一键清除：删全部 `position.*`，清 localStorage，再通知开着的书 `leaf.resetSpeed()`（否则下次翻页把内存里的速度写回去）。窗口只记一份 `bookWindowFrame`（全局，不按书）；`askedDefaultEPUB` 记是否问过设为 EPUB 默认阅读器。标注不在这里，见「标注」行 |
| 标注 | `Annotations.swift` + app.js「标注」段 | 高亮、笔记、书签。按书的内容哈希存 `~/Library/Containers/com.chengffei.leaf/Data/Library/Application Support/Leaf/Annotations/<sha256>.json`（沙盒路径），书文件不动。JS 侧按 CFI 建 Map，foliate 的 `addAnnotation({ value: cfi })` 画层（`draw-annotation` 用 `Overlayer.highlight`，颜色四种），每节画层建好时（`create-overlay`）把属于该节的高亮补画；选区 `mouseup` 弹 `#sel` 小条（颜色点、笔记、拷贝、查词），点高亮（`show-annotation`）弹 `#annot` 卡片（改色、笔记、拷贝、删除）。书签 = 当页起点 CFI，`relocate` 时用 `compareBoundaryPoints` 判断当页是否有书签（`isPointInRange` 把页尾也算在内，上一页会误判），右上角 `#bookmark` 角标，工具栏浮现时让位（`leaf.setChromeVisible`）。JS 回报 `annotation`（add / update / remove）与 `order`（按 CFI 排序的 id 列表），Swift 侧 `ReaderModel.annotations` 存盘、面板第三页「标注」按章节分组。导出走 `NSSavePanel`：Markdown，或 Kindle 的 My Clippings.txt（BOM 加 CRLF，Readwise、Obsidian Kindle 插件按它解析）。查词：`lookup` 消息带选中词与选区左下角，`webView.showDefinition(for:at:)` 弹系统词典（⌃⌘D 或小条上的「查词」）。设置「通用 › 标注与高亮 › 删除…」整目录删掉并通知开着的书擦画层。PDF 窗口不给标注页签。**CFI 解析必须 await**：分块后 `book.resolveCFI` 返回 Promise，同步读 `.index` 会拿到 -1。性能基线（红楼梦 330 条，Debug 用 `-LeafDebugSeed N` 造数据，`perf()` 回报到日志）：解析全部 CFI 27ms，一节 46 条高亮画完 24ms，翻页不受影响 |
| PDF | `Leaf/PDFReader.swift` | PDF 不走 WebView，用 PDFKit 连续滚动：目录取 PDF 大纲，查找用 `beginFindString`（最多 500 条，150 ms 批量推给列表），缩放是每窗口「适合宽度」的 50–300%，主题由 `ThemedPage` 画完原页再用混合模式着色，进度存 `pdf:<页码>` |
| 渲染 | `Web/app.js` + `Web/foliate/` | [foliate-js](https://github.com/johnfactotum/foliate-js) 内置（版本见 `Web/foliate/VERSION`，移除了 PDF / OPDS / 示例）。**本地补丁只有一处**：`paginator.js` 把 `max-column-count-portrait` 开放为属性（上游写死竖窗 1 栏），升级时要重打。`Web/chunks.js` 在交给 foliate 前把 EPUB 里超过 128KB 的章节切成约 64KB 一块的虚拟章节（见下「大章节分块」） |
| 本地化 | `Leaf/Localizable.xcstrings` `Web/strings.js` | 源语言英文，另 7 种（zh-Hans、zh-Hant、ja、ko、fr、de、es）。Swift 侧：SwiftUI 的 `Text` / `Button` / `.help` 等直接写英文 key；枚举标签和 `NSMenuItem` 用 `String(localized:)`；自定义辅助函数的标题参数必须是 `LocalizedStringKey`，用 `String` 就不查表。网页侧：`ReaderPrefs.lang` 带上 app 实际用的本地化，`strings.js` 里 `t(key, ...args)` 按 `%@` 替换；两张表的 key 都是英文原文，加文案要两边都加。设置里的「语言」项写 `AppleLanguages`（跟随系统 = 删掉这个键），下次启动生效；「立即重新打开」用 `open -n` 带上当前打开的书再 `terminate` |
| 图标 | `Leaf/Leaf.icon` | Icon Composer 格式，两层手写 SVG |
| 介绍页 | `scripts/site/index.template.html` `scripts/site/build.py` | **改模板，不要直接改 `docs/*.html`**。`python3 scripts/site/build.py` 生成八种语言：英文在 `docs/index.html`，其余在 `docs/<zh|zh-hant|ja|ko|fr|de|es>/index.html`。模板只写英文和简中（`<span lang>`），其他六种在 `scripts/site/i18n/<lang>.json` 按英文原文查译文，缺一条就报错；各语言的标题、描述、日期格式在 build.py 的 `PAGES`，译文可以按本语言读者改重点（日文、繁中强调竖排，韩文提字体，法德西提断词）。导航语言菜单是 `<details>`，不靠 JS；hreflang 八种加 x-default，`docs/sitemap.xml` 也由脚本生成。版本号取自 `project.yml`，FAQ 结构化数据从页面 FAQ 解析。`docs/llms.txt` 手工维护 |
| 安装包 | `scripts/make-dmg.sh` `scripts/dmg/background.swift` | 背景图由脚本绘制；窗口 640×460，图标中心 (170,150) / (470,150) 与背景箭头对齐，挪图标须同步改箭头坐标 |

调试：Debug 构建开启了 `isInspectable`，可在 Safari ›「开发」菜单里检查 Leaf 的页面。JS 端的报错与 `console.error/warn` 会转发到系统日志（subsystem `com.chengffei.leaf`）。

## 踩过的坑

- 存储面板要 `com.apple.security.files.user-selected.read-write`：只有 read-only 时 `NSSavePanel` 静默不弹，日志里一句 `Unable to display save panel`（11-23 导出标注踩到）

- **沙盒里的 WKWebView 需要 `com.apple.security.network.client`**，否则 WebContent 进程直接崩溃、页面全空。书始终只从本地读取。
- **foliate 的 `goTo` 失败只打日志不抛错**，页面会静默留白。`app.js` 已兜底：初始化后未渲染则退回第一节。
- **不要用 `WKWebView.pageZoom` 调字号**：非 100% 时 foliate 分页混用缩放前后的尺寸，右侧会露出半截下一栏。
- **章首空白栏**：书的 CSS 常给章节标题加 `page-break-before: always`，WebKit 多栏把它当断栏，每章前多出一整栏空白。`app.js` 只对每段开头那串元素取消断开。
- **目录为什么浮动**：10-24 前是 `NavigationSplitView` 推挤式侧栏，打开目录会让书重新分页，读者刚看到的那页就变了。目录是瞬态工具（开、选、关），改成覆盖层；将来的标注、查找结果面板也走这条路。正文仍只忽略顶部安全区。
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
- **查找**：`view.search()` 是异步生成器，整本逐节扫；第一处命中立刻跳转，结果每 150 毫秒批量回传给面板，只推新增的那段（`offset` 起），跳到第几处只推序号；最多 500 处（与 PDF 一致），满了就停扫，计数显示「500+」。常用字一搜上万处，整表重推曾让每次回传卡住主线程约 0.5 秒。换关键词时用 run 计数器作废旧搜索。输入框是原生的（面板查找页），网页里不再有查找条。
- **大章节分块**：WebKit 多栏排版耗时随章节体积线性增长（1.2MB 单章开书约 3 秒）。`chunks.js` 只改书对象：`sections` 换成虚拟章节，`resolveHref` / `resolveCFI` 先按原章节解析再定位到块，foliate 不打补丁。块外节点不删，元素清空、去掉属性并挪到页面外，文本置空，所以 DOM 路径与原章节一致，CFI 照旧按原章节生成，老进度直接可用。占位别用 `display: none`（矩形在原点，会被 foliate 算进第一页的可见范围），也别用原位零高块（会被算进最后一页）；两种都会让章节名标错。目录片段落在块外时，占位里留同 id 的空 `span`，目录进度才能按文档顺序比较。代价：块边界强制换页，上一块末页可能半页留白。MOBI / AZW3 和固定版式不切
- **跳转**：`⌘L` 弹网页小条（右下角，避开左侧面板），数字不超过 100 当百分比，更大当位置号；状态行悬停出现 `<input type=range>` 滑杆，`change` 时 `goToFraction`。两者都压一条「返回」。
- **图片放大**：书页 `dblclick` 命中 `<img>` 或 `<svg><image>`（封面常用）就把 blob 地址放进宿主页的 `#lightbox`；网格单元高度不定，图片尺寸要用 `vw` / `vh` 限制。
- **GUI 测试与中文输入法**：`keystroke` 打英文会被拼音输入法截住（候选条一出，Enter / Esc 都归它）。给输入框赋值用 `scripts/ax.swift settext <文本>`，弹出菜单用 `popup <序号> <菜单项>`。
- **标题与工具栏**：别用 `.toolbar(removing: .title)`，工具栏会向左收拢、Aa 挤到目录按钮旁；改用 `titleVisibility = .hidden` 加 `ToolbarSpacer(.flexible)`。窗口标题不能露出来：书页自带白底（如封面）会铺到标题下，深色模式的浅色标题字被盖住。
- **SF Symbol 会随系统语言本地化**（`textformat.size` 在中文下显示「大小」），工具栏按钮固定用英文变体。
- **放大快捷键绑 `=`**：绑 `+` 时 `⌘=` 不触发。
- **构建目录里的 .app 会被 LaunchServices 登记**，Finder 可能打开旧版；`install.sh` 会注销它们并刷新图标缓存。
- **GUI 自动化测试**（`scripts/ax.swift`）会真实点击窗口：启动时加 `--args -ApplePersistenceIgnoreState YES` 避免恢复你正在读的书，脚本只对标题以 `alice` / `hongloumeng` 开头的窗口动手。
- **CBZ 和 EPUB 都是 zip，FB2 没有魔数**：foliate 按文件名区分。`BookDocument.format` 带进页面网址，`app.js` 再拿 `book.<ext>` 去取书；不带扩展名时 CBZ 会被当成 EPUB 打开失败。`.fb2.zip` 不登记，按扩展名系统只认得 `.zip`
- **DRM**：foliate 遇到不认识的加密只 `console.warn`，照样渲染出乱码或空白。`app.js` 开书前自查：MOBI / AZW3 看记录 0 第 12 字节的 PalmDOC 加密类型；EPUB 有 `rights.xml`（Adobe）、`sinf.xml`（Apple），或 `encryption.xml` 里有字体混淆以外的算法，就显示「这本书有 DRM 保护」。zip 里没有的文件 `loadText` 直接返回 `null`（不是 Promise），别链 `.catch`
- **窗口位置**：`WindowChrome` 挂上窗口时先同步读出 `bookWindowFrame`，下一轮主循环再套用并注册 didMove / didResize / didEndLiveResize 监听；先注册会把 SwiftUI 摆放时的默认尺寸存回去。已有书窗口时只沿用大小，位置交给系统错开
- **默认打开方式**：EPUB、PDF 登记的是 Alternate，装着「图书」「预览」的 Mac 上双击不进 Leaf。第一次在 Leaf 里读 EPUB 时底部提示一次（`DefaultReader`），点了调 `NSWorkspace.setDefaultApplication`，系统会弹确认。Debug 构建加启动参数 `-LeafForceDefaultPrompt YES` 可强制显示
- **GUI 测试会写真实数据**：Debug 版和正式版同一个 bundle id，共用偏好和 WebKit 数据。测清除阅读记录前要备份偏好（`defaults export <容器 plist>`）和 `Library/WebKit/WebsiteData`
- 下载的测试书可能不完整：先 `unzip -t`（EPUB）或检查 PDB 末记录偏移（MOBI/AZW3），再怀疑代码。

## 测试书

`TestBooks/` 收录 Project Gutenberg 的公有领域书籍：《爱丽丝梦游仙境》的 EPUB / AZW3 / MOBI 三种格式，以及《紅樓夢》EPUB（中文排版）。
