import './foliate/view.js'
import { FootnoteHandler } from './foliate/footnotes.js'

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
  /* 书里写死的深色字（常见行内 color:rgb(0,0,0)）在深底上看不见，由 markDarkText 标记 */
  [data-leaf-dark]:not(a) { color: CanvasText !important; }
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

// 标记深灰到纯黑的字，深色模式下由 bookCSS 改成系统前景色；浅色模式规则不生效，原书颜色不变。
// 只认接近无彩色的：书里用来强调的红、蓝等颜色保留
const markDarkText = doc => {
  const win = doc.defaultView
  for (const el of doc.body?.querySelectorAll('*') ?? []) {
    const [r, g, b, a = 1] = win.getComputedStyle(el).color.match(/[\d.]+/g)?.map(Number) ?? []
    const gray = Math.max(r, g, b) - Math.min(r, g, b) < 40
    if (a > 0 && gray && 0.2126 * r + 0.7152 * g + 0.0722 * b < 90) el.setAttribute('data-leaf-dark', '')
  }
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
  goTo(href) { jumpTo(href) },
  setPrefs(next) {
    prefs = { ...prefs, ...next }
    applyStyles()
  },
  back() { view.history.back() },
  forward() { view.history.forward() },
}

// ---- 翻页输入：键盘 + 触控板（一次手势只翻一页） ----
// 用户亲手翻的页才计数：一次跳转本身会触发好几次 relocate，不能拿它数
const turn = go => {
  pagesSinceJump++
  updateBack()
  go()
}
const onKey = e => {
  if (!view.book || e.metaKey || e.ctrlKey || e.altKey) return
  const k = e.key
  if (k === 'Escape' && !$('#note').hidden) return closeNote()
  if (k === 't') return post({ type: 'toggleTOC' })
  if (k === 'ArrowLeft') turn(() => view.goLeft())
  else if (k === 'ArrowRight') turn(() => view.goRight())
  else if (k === 'ArrowUp' || k === 'PageUp' || (k === ' ' && e.shiftKey)) turn(() => view.prev())
  else if (k === 'ArrowDown' || k === 'PageDown' || k === ' ') turn(() => view.next())
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
  if (horizontal) turn(() => d > 0 ? view.goRight() : view.goLeft())
  else turn(() => d > 0 ? view.next() : view.prev())
}

// 书页在 iframe 里，点击坐标要加上 iframe 的偏移才是窗口坐标；注释卡片按它定位
let lastPoint = { x: innerWidth / 2, y: innerHeight / 2 }
const listen = target => {
  target.addEventListener('keydown', onKey)
  target.addEventListener('mousedown', e => {
    if (e.target.closest?.('#note, #back')) return // 点卡片里的按钮不算点正文
    const frame = e.view?.frameElement?.getBoundingClientRect()
    lastPoint = { x: e.clientX + (frame?.left ?? 0), y: e.clientY + (frame?.top ?? 0) }
    closeNote()
    post({ type: 'closeTOC' }) // 点正文 = 收起目录
  })
  target.addEventListener('wheel', onWheel, { passive: false })
}

// ---- 脚注：就地弹出，不离开当前页（识别交给 foliate 的 FootnoteHandler） ----
// 注释片段首尾的段落外边距会变成卡片里的空白，也让量出的高度偏小
const noteCSS = `
html, body { margin: 0 !important; padding: 0 !important; }
body > :first-child, body > :first-child > :first-child { margin-top: 0 !important; }
body > :last-child, body > :last-child > :last-child { margin-bottom: 0 !important; }
`
const footnotes = new FootnoteHandler()
const closeNote = () => {
  if ($('#note').hidden) return
  $('#note').hidden = true
  $('#note').style.visibility = ''
  $('#note-body').replaceChildren()
}
footnotes.addEventListener('before-render', e => {
  const note = e.detail.view
  // 必须先挂进页面：iframe 不在文档里就没有 contentDocument，排版会报错。先隐形，排好再显示
  $('#note-body').replaceChildren(note)
  $('#note').style.visibility = 'hidden'
  $('#note').hidden = false
  layoutNote(innerHeight)
  note.renderer.setAttribute('flow', 'scrolled')
  note.renderer.setAttribute('margin', '0px')
  note.renderer.setAttribute('gap', '0%')
  note.renderer.setStyles(bookCSS + prefsCSS(prefs) + noteCSS)
  note.addEventListener('load', e => {
    markDarkText(e.detail.doc)
    e.detail.doc.addEventListener('keydown', e => e.key === 'Escape' && closeNote())
  })
  // 注释里的链接（如「见第 3 章」）在主视图打开
  note.addEventListener('link', e => {
    e.preventDefault()
    closeNote()
    jumpTo(e.detail.href)
  })
  note.addEventListener('external-link', e => {
    e.preventDefault()
    post({ type: 'link', href: e.detail.a.href })
  })
})
footnotes.addEventListener('render', e => {
  const { view: note, href, hidden } = e.detail
  // 藏在正文里的脚注（aside）跳过去也看不见，不给「前往」
  $('#note-go').hidden = hidden
  $('#note-go').onclick = () => { closeNote(); jumpTo(href) }
  // 内容排好后按实际高度收紧卡片，再显示
  requestAnimationFrame(() => requestAnimationFrame(() => {
    const doc = note.renderer?.getContents?.()?.[0]?.doc
    layoutNote(Math.ceil(doc?.body?.getBoundingClientRect().height ?? 0) + 2 || 120)
    $('#note').style.visibility = ''
  }))
})
const layoutNote = (contentHeight = 120) => {
  const box = $('#note')
  const width = Math.min(440, innerWidth - 32)
  const extra = $('#note-go').hidden ? 0 : 32
  const height = Math.min(contentHeight, innerHeight * 0.45)
  $('#note-body').style.height = `${height}px`
  const total = height + extra + 32 // 上下内边距
  const x = Math.min(Math.max(lastPoint.x - width / 2, 16), innerWidth - width - 16)
  const below = lastPoint.y + 18 + total < innerHeight - 40
  const y = below ? lastPoint.y + 18 : Math.max(16, lastPoint.y - 18 - total)
  Object.assign(box.style, { left: `${x}px`, top: `${y}px`, width: `${width}px` })
}
addEventListener('resize', closeNote)

// ---- 跳转与返回：链接、目录跳过去之后，底部给一个「返回」 ----
// foliate 每次跳转压一条历史，翻页只改写当前那条，所以返回的是跳走前实际读到的位置
const BACK_PAGES = 3 // 在新位置连翻几页就当作接着读下去了，收起提示（⌘[ 仍可用）
let backLabel = null, pagesSinceJump = 0
const jumpTo = href => {
  backLabel = view.lastLocation?.tocItem?.label?.trim() || '原来的位置'
  pagesSinceJump = 0
  return view.goTo(href).catch(e => post({ type: 'error', message: String(e) }))
}
const updateBack = () => {
  const back = $('#back')
  const show = backLabel && view.history.canGoBack && pagesSinceJump < BACK_PAGES
  back.hidden = !show
  if (show) back.textContent = `返回「${backLabel}」`
}
$('#back').addEventListener('click', () => {
  backLabel = null
  view.history.back()
})
listen(document)

let statusTimer
const flashStatus = () => {
  $('#status').classList.add('show')
  clearTimeout(statusTimer)
  statusTimer = setTimeout(() => $('#status').classList.remove('show'), 2000)
}

// ---- 打开 ----
try {
  await view.open('leaf://app/book')
  const { book } = view
  const title = titleOf(book.metadata?.title) || '未命名'
  const author = [book.metadata?.author].flat()
    .map(a => typeof a === 'string' ? a : titleOf(a?.name)).filter(Boolean).join('、')
  post({ type: 'meta', title, author })

  view.addEventListener('load', e => {
    listen(e.detail.doc)
    markDarkText(e.detail.doc)
  })
  view.addEventListener('relocate', e => {
    closeNote()
    flashStatus()
    const { cfi, fraction, tocItem } = e.detail
    $('#chapter').textContent = tocItem?.label ?? ''
    $('#percent').textContent = `${Math.round((fraction ?? 0) * 100)}%`
    post({ type: 'relocate', cfi, fraction, tocHref: tocItem?.href ?? null })
  })
  view.addEventListener('link', e => {
    const shown = footnotes.handle(view.book, e)
    if (shown) {
      shown.catch(err => { console.warn('脚注解析失败，改为跳转', err); jumpTo(e.detail.href) })
      return
    }
    e.preventDefault() // 普通书内链接也走 jumpTo，好给「返回」
    jumpTo(e.detail.href)
  })
  view.history.addEventListener('index-change', () => {
    if (!view.history.canGoBack) backLabel = null
    updateBack()
    post({ type: 'history', back: view.history.canGoBack, forward: view.history.canGoForward })
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
