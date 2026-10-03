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
| 窗口 | `BookWindow.swift` `ReaderModel.swift` | `NavigationSplitView`：左侧原生目录侧栏（目录由 JS 压平回传，选中态 = 当前章节，点选 = 跳转） |
| 视图 | `ReaderView.swift` | `WKWebView`；接收 JS 消息：relocate 存进度、外链交给浏览器；只放行 leaf / blob / about / data |
| 排版 | `ReaderSettings.swift` `TypographyPanel.swift` | 全局设置：字号 = 书页根字号 `html { font-size: N% }`（作用于 em / rem / % 字号，写死 px 的书不受影响）；行距三档以 `!important` 覆盖书本；字体 原书 / 黑体 / 宋体 |
| 状态 | `ReadingPosition.swift` | 唯一的持久化：`UserDefaults["position.<sha256>"] = CFI` |
| 渲染 | `Web/app.js` + `Web/foliate/` | [foliate-js](https://github.com/johnfactotum/foliate-js) 原样内置（版本见 `Web/foliate/VERSION`，移除了 PDF / OPDS / 示例） |
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
- **SF Symbol 会随系统语言本地化**（`textformat.size` 在中文下显示「大小」），工具栏按钮固定用英文变体。
- **放大快捷键绑 `=`**：绑 `+` 时 `⌘=` 不触发。
- **构建目录里的 .app 会被 LaunchServices 登记**，Finder 可能打开旧版；`install.sh` 会注销它们并刷新图标缓存。
- **GUI 自动化测试**（`scripts/ax.swift`）会真实点击窗口：启动时加 `--args -ApplePersistenceIgnoreState YES` 避免恢复你正在读的书，脚本只对标题以 `alice` / `hongloumeng` 开头的窗口动手。
- 下载的测试书可能不完整：先 `unzip -t`（EPUB）或检查 PDB 末记录偏移（MOBI/AZW3），再怀疑代码。

## 测试书

`TestBooks/` 收录 Project Gutenberg 的公有领域书籍：《爱丽丝梦游仙境》的 EPUB / AZW3 / MOBI 三种格式，以及《紅樓夢》EPUB（中文排版）。
