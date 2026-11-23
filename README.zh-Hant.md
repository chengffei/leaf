<p align="center">
  <img src="docs/images/icon.png" width="128" alt="Leaf">
</p>

<h1 align="center">Leaf</h1>

<p align="center">
  按兩下就讀，關掉就走。<br>
  小巧的原生 Mac 電子書閱讀器，免費開源。
</p>

<p align="center">
  <a href="https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg"><b>下載</b></a> ·
  <a href="https://chengffei.github.io/leaf/">網站</a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <b>繁體中文</b> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.es.md">Español</a>
</p>

<p align="center">
  <img src="docs/images/reading.png" width="760" alt="Leaf 閱讀畫面">
</p>

## 為什麼是 Leaf

一本書，一個視窗。在 Finder 裡按兩下就開始讀，關掉視窗，Leaf 就結束。

- **沒有書庫。** 不必匯入，不拷貝檔案，也不需要帳號。
- **從上次讀到的地方繼續。** 檔案改名或搬移也一樣。
- **道地的 Mac App。** 系統選單、快速鍵、查詢與翻譯都在。約 5 MB。

## 為閱讀而設計

- **六種格式。** EPUB、MOBI、AZW3、PDF、FB2、CBZ 直接打開，不必轉檔。MOBI 和 AZW3 須無 DRM，PDF 保留原始版面。
- **字體隨你調。** 任意字體，內建 Literata。字級 80% 到 200%，字重五級，行距、段距、字距、邊界、對齊都能調。
- **排版預設。** 緊湊、標準、大字、低視力、電子紙，也能儲存自己的。
- **主題。** 紙白、米黃、電子紙、深色，或跟隨系統。
- **還剩多久。** 按一下右下角，切換百分比、位置、本章剩餘和全書剩餘時間，依你的閱讀速度估算。
- **註腳就地看。** 按一下編號，註解就在原處跳出。跳轉之後按 `⌘[` 回來。
- **搜尋與跳轉。** `⌘F` 依章節列出結果，`⌘L` 跳到任意百分比或位置。
- **浮動目錄。** `⌘T` 打開，浮在書頁上，內文不重排。
- **版面。** 版心寬度可調，單欄或雙欄，按一下頁面兩側翻頁。
- **看圖。** 按兩下圖片看大圖。
- **螢光標示與筆記。** 選取文字，選一種顏色就是標示，可以附筆記。`⌘D` 為目前頁面加入書籤。「標註」面板（`⇧⌘N`）按章節列出全部。
- **匯出。** 存成 Markdown，或 Kindle 的 My Clippings 格式，Readwise 和 Obsidian 直接能用。
- **一步查詢。** 選取字詞按 `⌃⌘D`，或點選取範圍上方小條裡的「查詢」。
- **關於本書。** 書裡後設資料的簡介，顯示在面板頂部。
- **直排。** 原書直排的日文書打開就是直排，左邊是下一頁。設定「版面 › 排版方向」可以把任何書強制直排或橫排。
- **8 種語言。** 英文、簡體中文、繁體中文、日文、韓文、法文、德文、西班牙文。

## 比較

[Readest](https://github.com/readest/readest) 功能最多，Apple 書籍隨 Mac 內建，Calibre 最會管理藏書。Leaf 只負責打開一本書。完整比較請見[網站](https://chengffei.github.io/leaf/#compare)。

## 接下來

- 字體設定優先於出版社樣式，支援 TXT
- 真實頁碼，翻去看了別處能一鍵回來
- Finder 封面縮圖、快速查看、Spotlight 搜尋，之後再做

不做：書庫、書店、帳號、同步。

## 安裝

1. 下載 [Leaf.dmg](https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg)，把 Leaf 拖進「應用程式」。
2. Leaf 沒有經過 Apple 公證，第一次打開會被系統擋下。先打開它並按「完成」，再到「系統設定 › 隱私權與安全性」，捲到底部按「強制打開」。

也可以用 Homebrew：

```sh
brew tap chengffei/tap
brew trust chengffei/tap
brew install --cask leaf
```

需要 macOS 15 或以上版本。

## 快速鍵

| 動作 | 按鍵 |
|---|---|
| 翻頁 | `←` `→`、空白鍵，或在觸控板上左右滑 |
| 目錄 | `⌘T` 或 `T`，或按一下左下角的章名 |
| 字級 | `⌘=` 放大，`⌘-` 縮小，`⌘0` 實際大小 |
| 搜尋 | `⌘F`，`⌘G` 下一個，`⇧⌘G` 上一個 |
| 跳轉 | `⌘L` |
| 字級與主題 | 右上角 `Aa`，或在書頁上按右鍵 |
| 設定 | `⌘,` |
| 標示 | 選取文字後選顏色 |
| 書籤 | `⌘D` |
| 標註 | `⇧⌘N` |
| 查詢 | `⌃⌘D` |

## 從原始碼建置

需要 Xcode 26 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```sh
xcodegen generate
./scripts/install.sh      # 建置並安裝到 /Applications
./scripts/make-dmg.sh     # 打包 DMG 到 ~/Downloads
```

架構說明和已知問題見 [DEVELOPMENT.md](DEVELOPMENT.md)（簡體中文）。

## 致謝

排版與格式解析由 [foliate-js](https://github.com/johnfactotum/foliate-js)（MIT）完成。`TestBooks/` 中的範例書來自 [Project Gutenberg](https://www.gutenberg.org/)，屬於公有領域。

## 參與貢獻

歡迎貢獻。提交程式碼前需要同意[貢獻者授權協議](CLA.md)。

## 授權

[GPL-3.0](LICENSE)。foliate-js 仍依 MIT 授權，見 `Web/foliate/LICENSE`。
