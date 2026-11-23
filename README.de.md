<p align="center">
  <img src="docs/images/icon.png" width="128" alt="Leaf">
</p>

<h1 align="center">Leaf</h1>

<p align="center">
  Doppelklicken und lesen. Schließen und fertig.<br>
  Ein kleiner, nativer E-Book-Reader für den Mac. Kostenlos und Open Source.
</p>

<p align="center">
  <a href="https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg"><b>Laden</b></a> ·
  <a href="https://chengffei.github.io/leaf/">Website</a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.fr.md">Français</a> ·
  <b>Deutsch</b> ·
  <a href="README.es.md">Español</a>
</p>

<p align="center">
  <img src="docs/images/reading.png" width="760" alt="Leaf beim Lesen">
</p>

## Warum Leaf

Ein Buch, ein Fenster. Doppelklicke im Finder auf ein Buch und lies los. Schließt du das Fenster, wird Leaf beendet.

- **Keine Bibliothek.** Nichts importieren, nichts kopieren, kein Account.
- **Weiterlesen, wo du warst.** Auch wenn du die Datei umbenennst oder verschiebst.
- **Zu Hause auf dem Mac.** Native Menüs, Tastaturkurzbefehle, Nachschlagen und Übersetzen. Rund 5 MB.

## Gemacht zum Lesen

- **Sechs Formate.** EPUB, MOBI, AZW3, PDF, FB2 und CBZ öffnen sich direkt, ohne Konvertierung. MOBI und AZW3 müssen DRM-frei sein. PDFs behalten ihr ursprüngliches Layout.
- **Schrift nach deinem Geschmack.** Jede Schrift, Literata ist schon dabei. Größe von 80 bis 200 Prozent, fünf Stärken, dazu Zeilen-, Absatz- und Zeichenabstand, Ränder und Ausrichtung.
- **Vorlagen.** Kompakt, Standard, Groß, Sehschwäche und E-Ink. Eigene kannst du auch sichern.
- **Themen.** Papier, Sepia, E-Ink und Dunkel, oder wie im System.
- **Restzeit.** Klicke unten rechts für Prozent, Position oder die verbleibende Zeit im Kapitel oder Buch, geschätzt nach deinem Lesetempo.
- **Fußnoten an Ort und Stelle.** Ein Klick auf die Ziffer zeigt die Anmerkung direkt an. Nach jedem Sprung bringt dich `⌘[` zurück.
- **Suchen und springen.** `⌘F` listet Treffer nach Kapitel. `⌘L` springt zu jedem Prozentwert oder jeder Position.
- **Schwebendes Inhaltsverzeichnis.** `⌘T` öffnet es über der Seite, der Text bleibt, wo er ist.
- **Layout.** Textbreite einstellen, ein- oder zweispaltig lesen und zum Blättern auf den Seitenrand klicken.
- **Bilder.** Doppelklicke auf ein Bild, um es in voller Größe zu sehen.
- **Markierungen und Notizen.** Text auswählen, eine von vier Farben wählen, Notiz anhängen. `⌘D` setzt ein Lesezeichen auf die Seite. Das Notizen-Panel (`⇧⌘N`) listet alles nach Kapiteln.
- **Export.** Als Markdown oder im My-Clippings-Format von Kindle für Readwise und Obsidian.
- **Nachschlagen mit einem Schritt.** Wort auswählen und `⌃⌘D` drücken, oder die Leiste über der Auswahl benutzen.
- **Über das Buch.** Die Beschreibung aus den Metadaten des Buchs, oben im Panel.
- **Acht Sprachen.** Englisch, vereinfachtes Chinesisch, traditionelles Chinesisch, Japanisch, Koreanisch, Französisch, Deutsch und Spanisch.

## Im Vergleich

[Readest](https://github.com/readest/readest) kann am meisten. Apple Books ist auf jedem Mac dabei. Calibre verwaltet Sammlungen am besten. Leaf öffnet einfach ein Buch. Siehe den [vollständigen Vergleich](https://chengffei.github.io/leaf/#compare).

## Als Nächstes

- Eigene Schrifteinstellungen vor denen des Verlags, und TXT-Dateien
- Echte Seitenzahlen und ein Weg zurück nach dem Vorblättern
- Finder-Vorschaubilder, Quick Look und Spotlight-Suche, später

Nicht geplant: Bibliothek, Store, Account oder Sync.

## Installation

1. Lade [Leaf.dmg](https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg) und ziehe Leaf in den Ordner „Programme“.
2. Leaf ist nicht von Apple notarisiert, deshalb blockiert macOS die App beim ersten Start. Öffne sie und klicke auf **Fertig**. Gehe dann zu **Systemeinstellungen › Datenschutz & Sicherheit**, scrolle nach unten und klicke auf **Dennoch öffnen**.

Erfordert macOS 15 oder neuer.

## Tastaturkurzbefehle

| Aktion | Tasten |
|---|---|
| Blättern | `←` `→`, Leertaste oder Wischen auf dem Trackpad |
| Inhaltsverzeichnis | `⌘T` oder `T`, oder Klick auf den Kapitelnamen unten links |
| Textgröße | `⌘=` größer, `⌘-` kleiner, `⌘0` Originalgröße |
| Suchen | `⌘F`, dann `⌘G` weiter und `⇧⌘G` zurück |
| Gehe zu | `⌘L` |
| Größe und Thema | `Aa` oben rechts, oder Rechtsklick auf die Seite |
| Einstellungen | `⌘,` |
| Markieren | Text auswählen, dann eine Farbe wählen |
| Lesezeichen | `⌘D` |
| Notizen | `⇧⌘N` |
| Nachschlagen | `⌃⌘D` |

## Aus dem Quellcode bauen

Erfordert Xcode 26 und [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
./scripts/install.sh      # bauen und nach /Applications installieren
./scripts/make-dmg.sh     # DMG in ~/Downloads erstellen
```

Architektur und bekannte Fallstricke stehen in [DEVELOPMENT.md](DEVELOPMENT.md) (auf Chinesisch).

## Danksagung

Darstellung und Formatanalyse von [foliate-js](https://github.com/johnfactotum/foliate-js) (MIT). Die Beispielbücher in `TestBooks/` stammen von [Project Gutenberg](https://www.gutenberg.org/) und sind gemeinfrei.

## Mitwirken

Beiträge sind willkommen. Für Code-Beiträge musst du dem [Contributor License Agreement](CLA.md) zustimmen.

## Lizenz

[GPL-3.0](LICENSE). foliate-js behält seine MIT-Lizenz in `Web/foliate/LICENSE`.
