<p align="center">
  <img src="docs/images/icon.png" width="128" alt="Leaf">
</p>

<h1 align="center">Leaf</h1>

<p align="center">
  双击就读，关窗就走。<br>
  小巧的原生 Mac 电子书阅读器，免费开源。
</p>

<p align="center">
  <a href="https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg"><b>下载</b></a> ·
  <a href="https://chengffei.github.io/leaf/zh/">介绍页</a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <b>简体中文</b> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.es.md">Español</a>
</p>

<p align="center">
  <img src="docs/images/reading.png" width="760" alt="Leaf 阅读界面">
</p>

## 为什么是 Leaf

一本书，一个窗口。在访达里双击就开始读，关掉窗口，Leaf 就退出。

- **没有书库。** 不用导入，不复制文件，也不要账号。
- **接着上次读。** 文件改了名、换了位置也一样。
- **地道的 Mac 应用。** 系统菜单、快捷键、查询与翻译都在。约 5 MB。

## 为读书而设计

- **六种格式。** EPUB、MOBI、AZW3、PDF、FB2、CBZ 直接打开，不用转换。MOBI 和 AZW3 须无 DRM，PDF 保持原版式。
- **字随你调。** 任意字体，内置 Literata。字号 80% 到 200%，字重五级，行距、段距、字距、页边距、对齐都能调。
- **排版预设。** 紧凑、标准、大字、低视力、墨水屏，也能存自己的。
- **主题。** 纸白、米黄、墨水屏、深色，或跟随系统。
- **还剩多久。** 点右下角，切换百分比、位置、本章剩余和全书剩余时间，按你的阅读速度估算。
- **脚注就地看。** 点一下编号，注释就在原处弹出。跳转之后按 `⌘[` 回来。
- **查找与跳转。** `⌘F` 按章节列出结果，`⌘L` 跳到任意百分比或位置。
- **浮动目录。** `⌘T` 打开，浮在书页上，正文不重排。
- **版式。** 版心宽度可调，单栏或双栏，点页面两侧翻页。
- **看图。** 双击图片看大图。
- **高亮与笔记。** 选中文字，选一种颜色就是高亮，可以附笔记。`⌘D` 给当前页加书签。「标注」面板（`⇧⌘N`）按章节列出全部。
- **导出。** 存成 Markdown，或 Kindle 的 My Clippings 格式，Readwise 和 Obsidian 直接能用。
- **一步查词。** 选中词按 `⌃⌘D`，或点选区上方小条里的「查询」。
- **关于本书。** 书里元数据的简介，显示在面板顶部。
- **竖排。** 原书竖排的日文书打开就是竖排，左边是下一页。设置「版式 › 排版方向」可以把任何书强制竖排或横排。
- **8 种语言。** 英文、简体中文、繁体中文、日文、韩文、法文、德文、西班牙文。

## 对比

[Readest](https://github.com/readest/readest) 功能最全，Apple Books 随系统附带，Calibre 最会管书。Leaf 只负责打开一本书。完整对比见[介绍页](https://chengffei.github.io/leaf/zh/#compare)。

## 接下来

- 字体设置优先于出版社样式，支持 TXT
- 真实页码，翻去看了别处能一键回来
- 访达封面缩略图、空格预览、聚焦搜索，之后再做

不做：书库、商店、账号、同步。

## 安装

1. 下载 [Leaf.dmg](https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg)，把 Leaf 拖进「应用程序」。
2. Leaf 没有经过 Apple 公证，第一次打开会被系统拦下。先打开它并点「完成」，再到「系统设置 › 隐私与安全性」，拉到底部点「仍要打开」。

也可以用 Homebrew：

```sh
brew tap chengffei/tap
brew trust chengffei/tap
brew install --cask leaf
```

需要 macOS 15 或更高版本。

## 快捷键

| 操作 | 按键 |
|---|---|
| 翻页 | `←` `→`、空格，或在触控板上左右滑 |
| 目录 | `⌘T` 或 `T`，或点左下角的章名 |
| 字号 | `⌘=` 放大，`⌘-` 缩小，`⌘0` 还原 |
| 查找 | `⌘F`，`⌘G` 下一个，`⇧⌘G` 上一个 |
| 跳转 | `⌘L` |
| 字号与主题 | 右上角 `Aa`，或在书页上右键 |
| 设置 | `⌘,` |
| 高亮 | 选中文字后选颜色 |
| 书签 | `⌘D` |
| 标注 | `⇧⌘N` |
| 查询 | `⌃⌘D` |

## 从源码构建

需要 Xcode 26 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```sh
xcodegen generate
./scripts/install.sh      # 构建并安装到 /Applications
./scripts/make-dmg.sh     # 打包 DMG 到 ~/Downloads
```

架构说明和踩过的坑见 [DEVELOPMENT.md](DEVELOPMENT.md)。

## 致谢

排版与格式解析由 [foliate-js](https://github.com/johnfactotum/foliate-js)（MIT）完成。`TestBooks/` 中的样书来自 [Project Gutenberg](https://www.gutenberg.org/)，属于公有领域。

## 参与贡献

欢迎贡献。提交代码前需要同意[贡献者许可协议](CLA.md)。

## 协议

[GPL-3.0](LICENSE)。foliate-js 仍按 MIT 协议，见 `Web/foliate/LICENSE`。
