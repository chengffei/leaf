#!/usr/bin/env python3
"""从 index.template.html 生成介绍页：docs/index.html（英文）与 docs/zh/index.html（中文）。

每页只保留自己语言的 <span lang="..."> 片段，头部（标题、描述、OG、hreflang、
JSON-LD）按语言生成；FAQ 结构化数据直接解析页面里的 FAQ，只维护一份。
改页面请改模板，然后运行：python3 scripts/site/build.py
"""
import datetime
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = Path(__file__).with_name("index.template.html")
SITE = "https://chengffei.github.io/leaf/"
DOWNLOAD = "https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg"

VERSION = re.search(r'MARKETING_VERSION: "([^"]+)"', (ROOT / "project.yml").read_text()).group(1)
TODAY = datetime.date.today()

PAGES = {
    "en": {
        "out": ROOT / "docs/index.html",
        "url": SITE,
        "html_lang": "en",
        "og_locale": "en_US",
        "base": "",
        "title": "Leaf — Free EPUB, MOBI & AZW3 Reader for Mac",
        "description": "Leaf is a free, open-source ebook reader for Mac. Double-click an EPUB, MOBI or AZW3 file to start reading — no library, no importing. Requires macOS 15.",
        "og_description": "A lightweight ebook reader for Mac. Open EPUB, MOBI and AZW3 files without a library or importing. Free and open source.",
        "app_description": "A free, open-source ebook reader for Mac that opens EPUB, MOBI and AZW3 files without a library or importing.",
        "toggle": '<a class="lang-toggle" href="zh/" hreflang="zh-Hans" lang="zh-Hans">中文</a>',
        "updated": f"{TODAY:%-d %B %Y}",
    },
    "zh": {
        "out": ROOT / "docs/zh/index.html",
        "url": SITE + "zh/",
        "html_lang": "zh-Hans",
        "og_locale": "zh_CN",
        "base": "../",
        "title": "Leaf — 免费的 Mac EPUB / MOBI / AZW3 电子书阅读器",
        "description": "Leaf 是免费开源的 Mac 电子书阅读器。在访达里双击 EPUB、MOBI 或 AZW3 文件即可阅读，不用建书库、不用导入。需要 macOS 15 或更高版本。",
        "og_description": "轻量的 Mac 电子书阅读器，直接打开 EPUB、MOBI、AZW3，不用书库、不用导入。免费开源。",
        "app_description": "免费开源的 Mac 电子书阅读器，直接打开 EPUB、MOBI 和 AZW3 文件，不用建书库、不用导入。",
        "toggle": '<a class="lang-toggle" href="../" hreflang="en" lang="en">EN</a>',
        "updated": f"{TODAY.year} 年 {TODAY.month} 月 {TODAY.day} 日",
    },
}

LANG_SPAN = r'<span lang="{}">(.*?)</span>'


def keep_language(text, lang):
    other = "zh" if lang == "en" else "en"
    text = re.sub(LANG_SPAN.format(other), "", text, flags=re.S)
    return re.sub(LANG_SPAN.format(lang), r"\1", text, flags=re.S)


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
        "fileFormat": ["application/epub+zip", "application/x-mobipocket-ebook", "application/vnd.amazon.mobi8-ebook"],
        "screenshot": SITE + "images/reading.png",
        "image": SITE + "images/icon.png",
        "license": "https://opensource.org/licenses/MIT",
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
    other = "zh_CN" if lang == "en" else "en_US"
    return "\n".join([
        f"<title>{esc(page['title'])}</title>",
        f'<meta name="description" content="{esc(page["description"])}">',
        f'<link rel="canonical" href="{page["url"]}">',
        f'<link rel="alternate" hreflang="en" href="{SITE}">',
        f'<link rel="alternate" hreflang="zh-Hans" href="{SITE}zh/">',
        f'<link rel="alternate" hreflang="x-default" href="{SITE}">',
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
        f'<meta property="og:locale:alternate" content="{other}">',
        '<meta name="twitter:card" content="summary_large_image">',
        f'<meta name="twitter:title" content="{esc(page["title"])}">',
        f'<meta name="twitter:description" content="{esc(page["og_description"])}">',
        f'<meta name="twitter:image" content="{SITE}images/og.png">',
        f'<link rel="icon" type="image/png" sizes="64x64" href="{page["base"]}images/favicon.png">',
        f'<link rel="apple-touch-icon" href="{page["base"]}images/apple-touch-icon.png">',
        ld(app),
        ld(faq_ld),
    ])


def main():
    template = TEMPLATE.read_text()
    for lang, page in PAGES.items():
        body = keep_language(template, lang)
        out = (body
               .replace("{{HTML_LANG}}", page["html_lang"])
               .replace("{{BASE}}", page["base"])
               .replace("{{LANG_TOGGLE}}", page["toggle"])
               .replace("{{VERSION}}", VERSION)
               .replace("{{UPDATED}}", TODAY.isoformat())
               .replace("{{UPDATED_EN}}", page["updated"])
               .replace("{{UPDATED_ZH}}", page["updated"]))
        out = out.replace("{{HEAD}}", head(lang, page, faq_items(out)))
        assert "{{" not in out and "<span lang=" not in out, lang
        page["out"].parent.mkdir(parents=True, exist_ok=True)
        page["out"].write_text(out)
        print(f"{lang}: {page['out'].relative_to(ROOT)} ({len(out):,} bytes, {len(faq_items(out))} FAQ)")


if __name__ == "__main__":
    main()
