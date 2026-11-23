#!/usr/bin/env python3
"""从 index.template.html 生成介绍页，八种语言，与 app 一致。

模板里只写英文和简体中文（<span lang="en"> / <span lang="zh">）；其余六种语言在
scripts/site/i18n/<lang>.json 里按英文原文查译文，缺一条就报错，不会悄悄退回英文。
头部（标题、描述、OG、hreflang、JSON-LD）按语言生成；FAQ 结构化数据直接解析页面里的 FAQ；
sitemap 一并生成。改页面请改模板和译文表，然后运行：python3 scripts/site/build.py
"""
import datetime
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
TEMPLATE = HERE / "index.template.html"
SITE = "https://chengffei.github.io/leaf/"
DOWNLOAD = "https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg"

VERSION = re.search(r'MARKETING_VERSION: "([^"]+)"', (ROOT / "project.yml").read_text()).group(1)
TODAY = datetime.date.today()

MONTHS = {
    "fr": ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"],
    "de": ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"],
    "es": ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"],
}
DATES = {
    "en": f"{TODAY:%-d %B %Y}",
    "zh": f"{TODAY.year} 年 {TODAY.month} 月 {TODAY.day} 日",
    "zh-Hant": f"{TODAY.year} 年 {TODAY.month} 月 {TODAY.day} 日",
    "ja": f"{TODAY.year}年{TODAY.month}月{TODAY.day}日",
    "ko": f"{TODAY.year}년 {TODAY.month}월 {TODAY.day}일",
    "fr": f"{TODAY.day} {MONTHS['fr'][TODAY.month - 1]} {TODAY.year}",
    "de": f"{TODAY.day}. {MONTHS['de'][TODAY.month - 1]} {TODAY.year}",
    "es": f"{TODAY.day} de {MONTHS['es'][TODAY.month - 1]} de {TODAY.year}",
}

# 顺序 = 语言菜单的顺序。dir 是 docs 下的目录（英文在根）
PAGES = {
    "en": dict(dir="", html_lang="en", og_locale="en_US", name="English",
        title="Leaf — Free EPUB, MOBI and AZW3 Reader for Mac, No Library",
        description="A free, open-source ebook reader for Mac. Double-click an EPUB, MOBI, AZW3, PDF, FB2 or CBZ file to read; close the window to quit. No library, no account. Native, about 5 MB.",
        og_description="Double-click to read. Close to leave. A small, native ebook reader for Mac. Free and open source.",
        app_description="A free, open-source Mac ebook reader for EPUB, MOBI, AZW3, PDF, FB2 and CBZ. No library, no account."),
    "zh": dict(dir="zh/", html_lang="zh-Hans", og_locale="zh_CN", name="简体中文",
        title="Leaf — 不建书库的 Mac 电子书阅读器",
        description="免费开源的 Mac 电子书阅读器。双击 EPUB、MOBI、AZW3、PDF、FB2、CBZ 即读，关窗即退。没有书库，不用账号。原生应用，约 5 MB。",
        og_description="双击就读，关窗就走。小巧的原生 Mac 电子书阅读器，免费开源。",
        app_description="免费开源的 Mac 电子书阅读器，打开 EPUB、MOBI、AZW3、PDF、FB2、CBZ。没有书库，不用账号。"),
    "zh-Hant": dict(dir="zh-hant/", html_lang="zh-Hant", og_locale="zh_TW", name="繁體中文",
        title="Leaf — 不建書庫的 Mac 電子書閱讀器，支援直排",
        description="免費開源的 Mac 電子書閱讀器。按兩下 EPUB、MOBI、AZW3、PDF、FB2、CBZ 即讀，關窗即退。直排的書照原樣直排。沒有書庫，不用帳號。原生應用程式，約 5 MB。",
        og_description="按兩下就讀，關窗就走。小巧的原生 Mac 電子書閱讀器，免費開源，支援直排。",
        app_description="免費開源的 Mac 電子書閱讀器，打開 EPUB、MOBI、AZW3、PDF、FB2、CBZ。沒有書庫，不用帳號。"),
    "ja": dict(dir="ja/", html_lang="ja", og_locale="ja_JP", name="日本語",
        title="Leaf — 本棚のいらない Mac 用電子書籍リーダー、縦書き対応",
        description="無料でオープンソースの Mac 用電子書籍リーダー。EPUB、MOBI、AZW3、PDF、FB2、CBZ をダブルクリックで読み、ウインドウを閉じれば終了。縦書きの本はそのまま縦書きで、ルビも表示。ライブラリもアカウントも不要。ネイティブアプリ、約 5 MB。",
        og_description="ダブルクリックで読む。閉じれば終わり。縦書き対応の小さなネイティブ Mac 用電子書籍リーダー。無料・オープンソース。",
        app_description="無料でオープンソースの Mac 用電子書籍リーダー。EPUB、MOBI、AZW3、PDF、FB2、CBZ を開く。縦書き対応。ライブラリもアカウントも不要。"),
    "ko": dict(dir="ko/", html_lang="ko", og_locale="ko_KR", name="한국어",
        title="Leaf — 라이브러리 없는 Mac 전자책 리더",
        description="무료 오픈 소스 Mac 전자책 리더. EPUB, MOBI, AZW3, PDF, FB2, CBZ를 두 번 클릭해 읽고 창을 닫으면 종료. 라이브러리도 계정도 없음. 네이티브 앱, 약 5 MB.",
        og_description="두 번 클릭해 읽고, 창을 닫으면 끝. 작고 네이티브한 Mac 전자책 리더. 무료 오픈 소스.",
        app_description="무료 오픈 소스 Mac 전자책 리더. EPUB, MOBI, AZW3, PDF, FB2, CBZ를 엽니다. 라이브러리도 계정도 없습니다."),
    "fr": dict(dir="fr/", html_lang="fr", og_locale="fr_FR", name="Français",
        title="Leaf — Lecteur EPUB, MOBI et AZW3 gratuit pour Mac, sans bibliothèque",
        description="Lecteur d’ebooks gratuit et open source pour Mac. Double-cliquez sur un EPUB, MOBI, AZW3, PDF, FB2 ou CBZ pour lire ; fermez la fenêtre pour quitter. Pas de bibliothèque, pas de compte. Natif, environ 5 Mo.",
        og_description="Double-cliquez pour lire. Fermez pour partir. Un petit lecteur d’ebooks natif pour Mac. Gratuit et open source.",
        app_description="Lecteur d’ebooks gratuit et open source pour Mac : EPUB, MOBI, AZW3, PDF, FB2 et CBZ. Pas de bibliothèque, pas de compte."),
    "de": dict(dir="de/", html_lang="de", og_locale="de_DE", name="Deutsch",
        title="Leaf — Kostenloser EPUB-, MOBI- und AZW3-Reader für den Mac, ohne Bibliothek",
        description="Kostenloser Open-Source-E-Book-Reader für den Mac. EPUB, MOBI, AZW3, PDF, FB2 oder CBZ per Doppelklick lesen; Fenster schließen, fertig. Keine Bibliothek, kein Konto. Nativ, etwa 5 MB.",
        og_description="Doppelklicken und lesen. Schließen und fertig. Ein kleiner nativer E-Book-Reader für den Mac. Kostenlos und Open Source.",
        app_description="Kostenloser Open-Source-E-Book-Reader für den Mac: EPUB, MOBI, AZW3, PDF, FB2 und CBZ. Keine Bibliothek, kein Konto."),
    "es": dict(dir="es/", html_lang="es", og_locale="es_ES", name="Español",
        title="Leaf — Lector gratuito de EPUB, MOBI y AZW3 para Mac, sin biblioteca",
        description="Lector de ebooks gratuito y de código abierto para Mac. Doble clic en un EPUB, MOBI, AZW3, PDF, FB2 o CBZ para leer; cierra la ventana para salir. Sin biblioteca, sin cuenta. Nativo, unos 5 MB.",
        og_description="Doble clic para leer. Cierra y listo. Un pequeño lector de ebooks nativo para Mac. Gratis y de código abierto.",
        app_description="Lector de ebooks gratuito y de código abierto para Mac: EPUB, MOBI, AZW3, PDF, FB2 y CBZ. Sin biblioteca, sin cuenta."),
}
# 首屏截图：每种语言用本语言的公版经典，日文竖排。英文是爱丽丝（reading.png）
SHOTS = {
    "en": ("reading.png", "Leaf reading Alice’s Adventures in Wonderland on Mac in two-column layout"),
    "zh": ("reading-zh-hans.png", "Leaf 在 Mac 上双栏阅读鲁迅《狂人日记》"),
    "zh-Hant": ("reading-zh-hant.png", "Leaf 在 Mac 上雙欄閱讀《紅樓夢》"),
    "ja": ("reading-ja.png", "Leaf で夏目漱石『吾輩は猫である』を縦書きで読む"),
    "ko": ("reading-ko.png", "Leaf에서 이상의 『날개』를 두 단으로 읽는 모습"),
    "fr": ("reading-fr.png", "Leaf lisant Du côté de chez Swann de Proust sur Mac, en deux colonnes"),
    "de": ("reading-de.png", "Leaf liest Kafkas Die Verwandlung auf dem Mac, zweispaltig"),
    "es": ("reading-es.png", "Leaf leyendo Don Quijote de Cervantes en Mac, a dos columnas"),
}
# 目录面板截图：界面语言也切到本语言（启动参数 -AppleLanguages）
TOC_SHOTS = {
    "en": ("toc.png", "Leaf floating table of contents panel on macOS"),
    "zh": ("toc-zh-hans.png", "Leaf 的浮动目录面板，鲁迅《呐喊》"),
    "zh-Hant": ("toc-zh-hant.png", "Leaf 的浮動目錄面板，《紅樓夢》回目"),
    "ja": ("toc-ja.png", "Leaf の目次パネル、縦書きの『吾輩は猫である』"),
    "ko": ("toc-ko.png", "Leaf의 목차 패널, 이상 단편선"),
    "fr": ("toc-fr.png", "Le panneau Table des matières de Leaf, Du côté de chez Swann"),
    "de": ("toc-de.png", "Das Inhaltsverzeichnis-Panel von Leaf, Die Verwandlung"),
    "es": ("toc-es.png", "El panel de índice de Leaf, Don Quijote"),
}
for lang, page in PAGES.items():
    page["shot"], page["shot_alt"] = SHOTS[lang]
    page["toc_shot"], page["toc_shot_alt"] = TOC_SHOTS[lang]
    page["url"] = SITE + page["dir"]
    page["out"] = ROOT / "docs" / page["dir"] / "index.html"
    page["base"] = "../" if page["dir"] else ""
    page["updated"] = DATES[lang]

LANG_SPAN = r'<span lang="{}">(.*?)</span>'


def localize(text, lang):
    """只留本语言的文案。英文、简中直接取模板；其他语言按英文原文查译文表。"""
    if lang == "en":
        text = re.sub(LANG_SPAN.format("zh"), "", text, flags=re.S)
        return re.sub(LANG_SPAN.format("en"), r"\1", text, flags=re.S)
    if lang == "zh":
        text = re.sub(LANG_SPAN.format("en"), "", text, flags=re.S)
        return re.sub(LANG_SPAN.format("zh"), r"\1", text, flags=re.S)
    table = json.loads((HERE / "i18n" / f"{lang}.json").read_text())
    missing = sorted({s for s in re.findall(LANG_SPAN.format("en"), text, re.S) if s not in table})
    assert not missing, f"{lang}: {len(missing)} untranslated, first: {missing[0][:60]!r}"
    text = re.sub(LANG_SPAN.format("zh"), "", text, flags=re.S)
    return re.sub(LANG_SPAN.format("en"), lambda m: table[m.group(1)], text, flags=re.S)


def language_menu(current):
    """导航里的语言菜单：当前语言作标题，展开列出其余七种；不依赖 JS"""
    links = []
    for lang, page in PAGES.items():
        if lang == current:
            continue
        href = page["base"] and "" or ""
        # 从当前页到目标页的相对路径：根页直接写目录名，子目录页先回上一级
        href = ("../" if PAGES[current]["dir"] else "") + page["dir"]
        if not href:
            href = "./" if not PAGES[current]["dir"] else "../"
        links.append(f'<a href="{href}" hreflang="{page["html_lang"]}" lang="{page["html_lang"]}">{page["name"]}</a>')
    return ('<details class="langs"><summary class="lang-toggle" aria-label="Language">'
            f'{PAGES[current]["name"]}</summary><div class="langs-menu">' + "".join(links) + "</div></details>")


def plain(fragment):
    return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()


def faq_items(page_html):
    pattern = r"<details><summary>(.*?)</summary><p>(.*?)</p></details>"
    return [(plain(q), plain(a)) for q, a in re.findall(pattern, page_html, re.S)]


def head(lang, page, faq):
    esc = lambda s: html.escape(s, quote=True)
    app = {
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": "Leaf",
        "description": page["app_description"],
        "applicationCategory": "ProductivityApplication",
        "applicationSubCategory": "Ebook reader",
        "operatingSystem": "macOS 15 or later",
        "softwareVersion": VERSION,
        "dateModified": TODAY.isoformat(),
        "inLanguage": page["html_lang"],
        "url": page["url"],
        "downloadUrl": DOWNLOAD,
        "fileFormat": ["application/epub+zip", "application/x-mobipocket-ebook", "application/vnd.amazon.mobi8-ebook", "application/pdf", "application/x-fictionbook+xml", "application/vnd.comicbook+zip"],
        "screenshot": SITE + "images/" + page["shot"],
        "image": SITE + "images/icon.png",
        "license": "https://www.gnu.org/licenses/gpl-3.0.html",
        "isAccessibleForFree": True,
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
        "author": {"@type": "Person", "name": "Felix", "url": "https://github.com/chengffei"},
        "codeRepository": "https://github.com/chengffei/leaf",
    }
    faq_ld = {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "inLanguage": page["html_lang"],
        "mainEntity": [
            {"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}}
            for q, a in faq
        ],
    }
    ld = lambda d: '<script type="application/ld+json">\n' + json.dumps(d, ensure_ascii=False, indent=2) + "\n</script>"
    alternates = [f'<link rel="alternate" hreflang="{p["html_lang"]}" href="{p["url"]}">' for p in PAGES.values()]
    alternates.append(f'<link rel="alternate" hreflang="x-default" href="{SITE}">')
    locales = [f'<meta property="og:locale:alternate" content="{p["og_locale"]}">' for l, p in PAGES.items() if l != lang]
    return "\n".join([
        f"<title>{esc(page['title'])}</title>",
        f'<meta name="description" content="{esc(page["description"])}">',
        f'<link rel="canonical" href="{page["url"]}">',
        *alternates,
        f'<link rel="alternate" type="text/plain" title="llms.txt" href="{SITE}llms.txt">',
        '<meta name="theme-color" content="#f6f4ef">',
        '<meta property="og:type" content="website">',
        '<meta property="og:site_name" content="Leaf">',
        f'<meta property="og:url" content="{page["url"]}">',
        f'<meta property="og:title" content="{esc(page["title"])}">',
        f'<meta property="og:description" content="{esc(page["og_description"])}">',
        f'<meta property="og:image" content="{SITE}images/og.png">',
        '<meta property="og:image:width" content="1200">',
        '<meta property="og:image:height" content="630">',
        '<meta property="og:image:alt" content="Leaf showing a book in two-column layout">',
        f'<meta property="og:locale" content="{page["og_locale"]}">',
        *locales,
        '<meta name="twitter:card" content="summary_large_image">',
        f'<meta name="twitter:title" content="{esc(page["title"])}">',
        f'<meta name="twitter:description" content="{esc(page["og_description"])}">',
        f'<meta name="twitter:image" content="{SITE}images/og.png">',
        f'<link rel="icon" type="image/png" sizes="64x64" href="{page["base"]}images/favicon.png">',
        f'<link rel="apple-touch-icon" href="{page["base"]}images/apple-touch-icon.png">',
        ld(app),
        ld(faq_ld),
    ])


def sitemap():
    links = "".join(f'\n    <xhtml:link rel="alternate" hreflang="{p["html_lang"]}" href="{p["url"]}"/>' for p in PAGES.values())
    links += f'\n    <xhtml:link rel="alternate" hreflang="x-default" href="{SITE}"/>'
    urls = "".join(f"\n  <url>\n    <loc>{p['url']}</loc>\n    <lastmod>{TODAY.isoformat()}</lastmod>{links}\n  </url>" for p in PAGES.values())
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
            f'xmlns:xhtml="http://www.w3.org/1999/xhtml">{urls}\n</urlset>\n')


def main():
    template = TEMPLATE.read_text()
    for lang, page in PAGES.items():
        body = localize(template, lang)
        out = (body
               .replace("{{HTML_LANG}}", page["html_lang"])
               .replace("{{BASE}}", page["base"])
               .replace("{{LANG_TOGGLE}}", language_menu(lang))
               .replace("{{SHOT}}", page["shot"])
               .replace("{{SHOT_ALT}}", html.escape(page["shot_alt"], quote=True))
               .replace("{{TOC_SHOT}}", page["toc_shot"])
               .replace("{{TOC_SHOT_ALT}}", html.escape(page["toc_shot_alt"], quote=True))
               .replace("{{VERSION}}", VERSION)
               .replace("{{UPDATED}}", TODAY.isoformat())
               .replace("{{UPDATED_EN}}", page["updated"])
               .replace("{{UPDATED_ZH}}", page["updated"])
               .replace("{{UPDATED_L}}", page["updated"]))
        out = out.replace("{{HEAD}}", head(lang, page, faq_items(out)))
        assert "{{" not in out and "<span lang=" not in out, lang
        page["out"].parent.mkdir(parents=True, exist_ok=True)
        page["out"].write_text(out)
        print(f"{lang}: {page['out'].relative_to(ROOT)} ({len(out):,} bytes, {len(faq_items(out))} FAQ)")
    (ROOT / "docs/sitemap.xml").write_text(sitemap())
    print("sitemap: docs/sitemap.xml")


if __name__ == "__main__":
    main()
