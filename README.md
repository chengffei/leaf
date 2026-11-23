<p align="center">
  <img src="docs/images/icon.png" width="128" alt="Leaf">
</p>

<h1 align="center">Leaf</h1>

<p align="center">
  Double-click to read. Close to leave.<br>
  A small, native e-book reader for Mac. Free and open source.
</p>

<p align="center">
  <a href="https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg"><b>Download</b></a> ·
  <a href="https://chengffei.github.io/leaf/">Website</a>
</p>

<p align="center">
  <b>English</b> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.es.md">Español</a>
</p>

<p align="center">
  <img src="docs/images/reading.png" width="760" alt="Leaf reading view">
</p>

## Why Leaf

One book, one window. Double-click a book in Finder and start reading. Close the window and Leaf quits.

- **No library.** Nothing to import, nothing copied, no account.
- **Picks up where you left off.** Even if you rename or move the file.
- **At home on your Mac.** Native menus, shortcuts, Look Up and Translate. About 5 MB.

## Made for reading

- **Six formats.** EPUB, MOBI, AZW3, PDF, FB2 and CBZ open as they are. MOBI and AZW3 must be DRM-free. PDFs keep their original layout.
- **Type, your way.** Any font, with Literata built in. Size from 80 to 200 percent, five weights, and your choice of spacing, margins and alignment.
- **Presets.** Compact, Standard, Large, Low Vision and E-ink. Save your own, too.
- **Themes.** Paper, Sepia, E-ink and Dark, or follow the system.
- **Time left.** Click the bottom-right corner to see percent, location, or time left in the chapter or book, based on how fast you read.
- **Footnotes in place.** Click a marker and the note appears right there. Press `⌘[` to go back after any jump.
- **Find and go to.** `⌘F` lists matches by chapter. `⌘L` takes you to any percent or location.
- **Contents that float.** `⌘T` opens them over the page, so the text never reflows.
- **Layout.** Set the text width, read in one or two columns, and click the edges of the page to turn it.
- **Pictures.** Double-click any image to see it full size.
- **Highlights and notes.** Select text to highlight it in one of four colors and add a note. `⌘D` bookmarks the page. The Notes panel (`⇧⌘N`) lists everything by chapter.
- **Export.** Save your notes as Markdown, or in Kindle’s My Clippings format for Readwise and Obsidian.
- **Look up in one step.** Select a word and press `⌃⌘D`, or use the bar that appears above the selection.
- **About the book.** The description from the book’s metadata, at the top of the panel.
- **Eight languages.** English, Simplified Chinese, Traditional Chinese, Japanese, Korean, French, German and Spanish.

## How it compares

[Readest](https://github.com/readest/readest) does the most. Apple Books comes with your Mac. Calibre is best at managing a collection. Leaf just opens a book. See the [full comparison](https://chengffei.github.io/leaf/#compare).

## What's next

- Your font settings over the publisher’s, and TXT files
- Real page numbers, and a way back after flipping ahead
- Finder thumbnails, Quick Look and Spotlight search, later

Not planned: a library, a store, an account or sync.

## Install

1. Download [Leaf.dmg](https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg) and drag Leaf to Applications.
2. Leaf isn't notarized by Apple, so macOS blocks it the first time. Open it and click **Done**. Then go to **System Settings › Privacy & Security**, scroll down and click **Open Anyway**.

Requires macOS 15 or later.

## Shortcuts

| Action | Keys |
|---|---|
| Turn the page | `←` `→`, Space, or swipe on the trackpad |
| Contents | `⌘T` or `T`, or click the chapter name at the bottom left |
| Text size | `⌘=` larger, `⌘-` smaller, `⌘0` actual size |
| Find | `⌘F`, then `⌘G` next and `⇧⌘G` previous |
| Go to | `⌘L` |
| Size and theme | `Aa` at the top right, or right-click the page |
| Settings | `⌘,` |
| Highlight | Select text, then pick a color |
| Bookmark | `⌘D` |
| Notes | `⇧⌘N` |
| Look Up | `⌃⌘D` |

## Build from source

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
./scripts/install.sh      # build and install to /Applications
./scripts/make-dmg.sh     # package a DMG into ~/Downloads
```

Architecture notes and known pitfalls are in [DEVELOPMENT.md](DEVELOPMENT.md) (in Chinese).

## Credits

Rendering and format parsing by [foliate-js](https://github.com/johnfactotum/foliate-js) (MIT). Sample books in `TestBooks/` come from [Project Gutenberg](https://www.gutenberg.org/) and are in the public domain.

## Contributing

Contributions are welcome. Code contributions require agreeing to the [Contributor License Agreement](CLA.md).

## License

[GPL-3.0](LICENSE). foliate-js keeps its MIT license in `Web/foliate/LICENSE`.
