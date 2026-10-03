import './foliate/view.js'

const $ = s => document.querySelector(s)
const post = msg => window.webkit?.messageHandlers?.leaf?.postMessage(msg)

// 注入书内 iframe 的样式：只给缺省值，不压过书本自带排版
const bookCSS = `
@namespace epub "http://www.idpf.org/2007/ops";
html {
  color-scheme: light dark;
  font-family: -apple-system, "PingFang SC", "Hiragino Sans GB", serif;
}
@media (prefers-color-scheme: dark) {
  a:link { color: #6cb4ff; }
}
p, li, blockquote, dd {
  text-align: justify;
  -webkit-hyphens: auto;
  hyphens: auto;
  widows: 2;
  orphans: 2;
}
[align="left"] { text-align: left; }
[align="right"] { text-align: right; }
[align="center"] { text-align: center; }
pre { white-space: pre-wrap !important; }
/* 章首的「分页前断开」在 WebKit 多栏里变成断栏，每章前多出一整栏空白；只取消每段开头那一串元素的 */
body > :first-child,
body > :first-child > :first-child,
body > :first-child > :first-child > :first-child {
  break-before: auto !important;
  page-break-before: auto !important;
}
aside[epub|type~="endnote"], aside[epub|type~="footnote"],
aside[epub|type~="note"], aside[epub|type~="rearnote"] { display: none; }
`

// 用户排版偏好：行距强制覆盖书本（否则很多书调了没反应），字体「原书」时不干预
const FONTS = {
  sans: '-apple-system, "PingFang SC", sans-serif',
  serif: 'ui-serif, "New York", "Songti SC", serif',
}
const prefsCSS = ({ fontScale, lineHeight, font }) => `
html { font-size: ${fontScale * 100}% !important; }
p, li, blockquote, dd, dt, div, td, th { line-height: ${lineHeight} !important; }
${FONTS[font] ? `body, body :not(pre):not(code):not(kbd):not(samp):not(tt) {
  font-family: ${FONTS[font]} !important;
}` : ''}
`
const query = new URLSearchParams(location.search)
let prefs = {
  fontScale: parseFloat(query.get('fs')) || 1,
  lineHeight: parseFloat(query.get('lh')) || 1.7,
  font: query.get('font') || 'original',
}
const applyStyles = () => {
  view.renderer?.setStyles?.(bookCSS + prefsCSS(prefs))
  // 回报实际生效的排版，供日志验收
  requestAnimationFrame(() => {
    const doc = view.renderer?.getContents?.()?.[0]?.doc
    const p = doc?.querySelector('p')
    const cs = p && doc.defaultView.getComputedStyle(p)
    post({ type: 'styled', ...prefs, width: innerWidth, lineHeightPx: cs?.lineHeight, fontSizePx: cs?.fontSize, fontFamily: cs?.fontFamily })
  })
}

const titleOf = x => !x ? '' : typeof x === 'string' ? x : Object.values(x)[0] ?? ''

const view = document.createElement('foliate-view')
document.body.prepend(view)

// 目录交给原生侧栏：嵌套树压平成带缩进层级的列表
const flatTOC = (items, depth = 0, out = []) => {
  for (const { label, href, subitems } of items ?? []) {
    out.push({ label: (label ?? '').trim(), href: href ?? '', depth })
    if (subitems?.length) flatTOC(subitems, depth + 1, out)
  }
  return out
}
// Swift 侧调用的入口
globalThis.leaf = {
  goTo(href) {
    view.goTo(href).catch(e => post({ type: 'error', message: String(e) }))
  },
  setPrefs(next) {
    prefs = { ...prefs, ...next }
    applyStyles()
  },
}

// ---- 翻页输入：键盘 + 触控板（一次手势只翻一页） ----
const onKey = e => {
  if (!view.book || e.metaKey || e.ctrlKey || e.altKey) return
  const k = e.key
  if (k === 't') return post({ type: 'toggleTOC' })
  if (k === 'ArrowLeft') view.goLeft()
  else if (k === 'ArrowRight') view.goRight()
  else if (k === 'ArrowUp' || k === 'PageUp' || (k === ' ' && e.shiftKey)) view.prev()
  else if (k === 'ArrowDown' || k === 'PageDown' || k === ' ') view.next()
  else return
  e.preventDefault()
}

let wheelFired = false, wheelIdle
const onWheel = e => {
  if (!view.book || view.renderer?.getAttribute('flow') === 'scrolled') return
  e.preventDefault()
  clearTimeout(wheelIdle)
  wheelIdle = setTimeout(() => wheelFired = false, 180) // 惯性滚动结束才解锁
  const horizontal = Math.abs(e.deltaX) > Math.abs(e.deltaY)
  const d = horizontal ? e.deltaX : e.deltaY
  if (wheelFired || Math.abs(d) < 8) return
  wheelFired = true
  if (horizontal) d > 0 ? view.goRight() : view.goLeft()
  else d > 0 ? view.next() : view.prev()
}

const listen = target => {
  target.addEventListener('keydown', onKey)
  target.addEventListener('mousedown', () => post({ type: 'closeTOC' })) // 点正文 = 收起目录
  target.addEventListener('wheel', onWheel, { passive: false })
}
listen(document)

// ---- 打开 ----
try {
  await view.open('leaf://app/book')
  const { book } = view
  const title = titleOf(book.metadata?.title) || '未命名'

  view.addEventListener('load', e => listen(e.detail.doc))
  view.addEventListener('relocate', e => {
    const { cfi, fraction, tocItem } = e.detail
    $('#chapter').textContent = tocItem?.label ?? ''
    $('#percent').textContent = `${Math.round((fraction ?? 0) * 100)}%`
    post({ type: 'relocate', cfi, fraction, tocHref: tocItem?.href ?? null })
  })
  view.addEventListener('external-link', e => {
    e.preventDefault()
    post({ type: 'link', href: e.detail.a.href })
  })

  view.renderer.setAttribute('margin', '40px')
  view.renderer.setAttribute('gap', '7%')
  view.renderer.setAttribute('max-inline-size', '680px')
  applyStyles()

  post({ type: 'toc', items: flatTOC(book.toc) })

  const cfi = query.get('cfi')
  await view.init({ lastLocation: cfi || null, showTextStart: true })
  // 存的位置失效、或书里的「正文起点」解析不了时 foliate 会静默留白，退回第一节
  if (!view.lastLocation) await view.goTo(Math.max(0, book.sections.findIndex(s => s.linear !== 'no')))
  post({
    type: 'ready',
    title,
    format: book.constructor?.name ?? '',
    sections: book.sections?.length ?? 0,
    toc: book.toc?.length ?? 0,
    restored: Boolean(cfi),
    rendered: Boolean(view.lastLocation),
  })
} catch (e) {
  $('#error').hidden = false
  $('#error').textContent = `打不开这本书\n\n${e?.message ?? e}`
  post({ type: 'error', message: `${e?.name}: ${e?.message}\n${e?.stack}` })
}
