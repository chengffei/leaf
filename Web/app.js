import './foliate/view.js'
import { FootnoteHandler } from './foliate/footnotes.js'
import { Overlayer } from './foliate/overlayer.js'

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
  widows: 2;
  orphans: 2;
}
/* 自动断词只对西文有用；中日韩文字不需要，关掉后 260KB 的中文章节排版快约 5%（598→571ms） */
html:not([data-leaf-cjk]) :is(p, li, blockquote, dd) {
  -webkit-hyphens: auto;
  hyphens: auto;
}
[align="left"] { text-align: left; }
[align="right"] { text-align: right; }
[align="center"] { text-align: center; }
pre { white-space: pre-wrap !important; }
/* 标题行高：书里大多不写，字体默认的行高太紧，折行后会贴住下划线 */
h1, h2, h3, h4, h5, h6 { line-height: 1.35 !important; }
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
// font 是内置的 sans/serif，或任意已安装字体的家族名（Swift 侧从 NSFontManager 取）
const FONTS = {
  sans: '-apple-system, "PingFang SC", sans-serif',
  serif: 'ui-serif, "New York", "Songti SC", serif',
}
const fontStack = font => font === 'original' ? '' : FONTS[font] ?? `"${font.replace(/["\\]/g, '')}", -apple-system, "PingFang SC", sans-serif`
// 主题。浅色 / 深色由窗口外观决定（跟随系统 = 不动窗口外观），这里只补书页的底色：
// 深色：书里常写死 body{background:white}，配上 markDarkText 改白的字就整页看不见，底色一并压掉
// 米黄：浅色外观之上染底色；深灰到黑的字（markDarkText 标记）换成棕色，彩色强调不动
const SEPIA = { bg: '#f4ecd8', fg: '#5b4636', link: '#8a5a2b' }
const DARK_BG = '#1c1c1e'
const darkMedia = matchMedia('(prefers-color-scheme: dark)')
const effectiveTheme = () => prefs.theme === 'system' ? (darkMedia.matches ? 'dark' : 'light') : prefs.theme
const THEME_CSS = {
  light: '',
  dark: `
html { background-color: ${DARK_BG} !important; }
body { background-color: transparent !important; }
`,
  sepia: `
html { color-scheme: light !important; background-color: ${SEPIA.bg} !important; color: ${SEPIA.fg}; }
body { background-color: transparent !important; }
[data-leaf-dark]:not(a) { color: ${SEPIA.fg} !important; }
a:link { color: ${SEPIA.link}; }
`,
}
const prefsCSS = ({ fontScale, lineHeight, font }) => `
html { font-size: ${fontScale * 100}% !important; }
p, li, blockquote, dd, dt, div, td, th { line-height: ${lineHeight} !important; }
${fontStack(font) ? `body, body :not(pre):not(code):not(kbd):not(samp):not(tt) {
  font-family: ${fontStack(font)} !important;
}` : ''}
${THEME_CSS[effectiveTheme()] ?? ''}
`
const query = new URLSearchParams(location.search)
const DEFAULT_PREFS = {
  fontScale: 1, lineHeight: 1.7, font: 'original', margin: 'standard',
  maxWidth: 680, columns: 'auto', theme: 'system',
}
let prefs = { ...DEFAULT_PREFS }
try { prefs = { ...prefs, ...JSON.parse(query.get('prefs') ?? '{}') } } catch {}
// 页边距三档：gap = 栏间距（也是左右留白，foliate 两侧各留一半），margin = 上下留白
const MARGINS = {
  narrow: { gap: '4%', margin: '24px' },
  standard: { gap: '7%', margin: '40px' },
  wide: { gap: '12%', margin: '56px' },
}
// 版心与分栏：foliate 的栏数 = min(max-column-count, ceil(宽度 / max-inline-size))，竖窗另有上限（上游写死 1，
// paginator.js 已打补丁开放为属性）。「双栏」在窄窗口里也要两栏，就把每栏上限压到半个窗口
// 值没变就不写：foliate 的 attributeChangedCallback 每次都会重排
const setAttr = (name, value) => {
  const r = view.renderer
  if (r?.setAttribute && r.getAttribute(name) !== value) r.setAttribute(name, value)
}
const applyLayout = () => {
  const max = prefs.maxWidth > 0 ? prefs.maxWidth : 100000
  const { columns } = prefs
  setAttr('max-column-count', columns === 'single' ? '1' : '2')
  setAttr('max-column-count-portrait', columns === 'double' ? '2' : '1')
  setAttr('max-inline-size', `${columns === 'double' ? Math.min(max, Math.floor(innerWidth / 2)) : max}px`)
}
const applyStyles = () => {
  const { gap, margin } = MARGINS[prefs.margin] ?? MARGINS.standard
  document.documentElement.dataset.theme = effectiveTheme()
  setAttr('gap', gap)
  setAttr('margin', margin)
  applyLayout()
  view.renderer?.setStyles?.(bookCSS + prefsCSS(prefs))
  // 回报实际生效的排版，供日志验收
  requestAnimationFrame(() => {
    const doc = view.renderer?.getContents?.()?.[0]?.doc
    const p = doc?.querySelector('p')
    const cs = p && doc.defaultView.getComputedStyle(p)
    const dark = doc?.defaultView.matchMedia('(prefers-color-scheme: dark)').matches
    post({ type: 'styled', ...prefs, width: innerWidth, lineHeightPx: cs?.lineHeight, fontSizePx: cs?.fontSize, fontFamily: cs?.fontFamily, color: cs?.color, dark, hostDark: matchMedia('(prefers-color-scheme: dark)').matches })
  })
}

// 标记深灰到纯黑的字，深色模式下由 bookCSS 改成系统前景色；浅色模式规则不生效，原书颜色不变。
// 只认接近无彩色的：书里用来强调的红、蓝等颜色保留
// 先全部读完再统一写：边读边写会让每次 getComputedStyle 都重算一遍样式
const markDarkText = doc => {
  const win = doc.defaultView
  const dark = [...doc.body?.querySelectorAll('*') ?? []].filter(el => {
    const [r, g, b, a = 1] = win.getComputedStyle(el).color.match(/[\d.]+/g)?.map(Number) ?? []
    const gray = Math.max(r, g, b) - Math.min(r, g, b) < 40
    return a > 0 && gray && 0.2126 * r + 0.7152 * g + 0.0722 * b < 90
  })
  for (const el of dark) el.setAttribute('data-leaf-dark', '')
}

// 中日韩文字为主的章节打标记，排版时跳过自动断词。取前 2000 字判断，免得遍历整章
const markCJK = doc => {
  const sample = doc.body?.textContent.slice(0, 2000) ?? ''
  const cjk = sample.match(/[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]/g)?.length ?? 0
  if (cjk > sample.replace(/\s/g, '').length / 3) doc.documentElement.setAttribute('data-leaf-cjk', '')
}

// 标题字号上限：不少转换书（如 Kindle 中文版）把标题设成正文的 2.5 倍，再叠加字号放大就一行放不下几个字。
// 超过正文 1.8 倍的压到 1.8 倍，用 rem 写，之后调字号仍按比例缩放；没超的不动
const HEADING_MAX = 1.8
const capHeadings = doc => {
  const win = doc.defaultView
  const px = el => parseFloat(win.getComputedStyle(el).fontSize)
  const text = [...doc.querySelectorAll('p')].find(p => p.textContent.trim().length > 20)
  const body = px(text ?? doc.body), root = px(doc.documentElement)
  if (!body || !root) return
  for (const h of doc.querySelectorAll('h1, h2, h3, h4, h5, h6')) {
    if (px(h) > body * HEADING_MAX) h.style.setProperty('font-size', `${(body * HEADING_MAX / root).toFixed(3)}rem`, 'important')
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
  prev() { turn(() => view.goLeft()) },
  next() { turn(() => view.goRight()) },
  find() { openFind() },
  findNext(step) { stepFind(step) },
}

// ---- 翻页输入：键盘 + 触控板（一次手势只翻一页） ----
// 用户亲手翻的页才计数：一次跳转本身会触发好几次 relocate，不能拿它数
const turn = go => {
  pagesSinceJump++
  updateBack()
  lastTurn = { at: Date.now(), bytes: bytesAt(lastLocation) } // 给阅读速度采样
  go()
}
const onKey = e => {
  if (!view.book || e.metaKey || e.ctrlKey || e.altKey) return
  if (e.target.closest?.('#find')) return // 查找框里打字不翻页
  const k = e.key
  if (k === 'Escape' && !$('#note').hidden) return closeNote()
  if (k === 'Escape' && !$('#find').hidden) return closeFind()
  if (k === 'Escape') return post({ type: 'closeTOC' })
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
const CHROME = '#note, #back, #find, #status'
const windowPoint = e => {
  const frame = e.view?.frameElement?.getBoundingClientRect()
  return { x: e.clientX + (frame?.left ?? 0), y: e.clientY + (frame?.top ?? 0) }
}
// 点正文左右两侧翻页：外侧各 15%，中间不动（留给选字）；拖选、点链接不算
const EDGE = 0.15
const listen = target => {
  target.addEventListener('keydown', onKey)
  target.addEventListener('mousedown', e => {
    if (e.target.closest?.(CHROME)) return // 点卡片里的按钮不算点正文
    lastPoint = windowPoint(e)
    closeNote()
    post({ type: 'closeTOC' }) // 点正文 = 收起目录
  })
  target.addEventListener('click', e => {
    if (e.button !== 0 || e.target.closest?.(`a, ${CHROME}`)) return
    if (!e.target.ownerDocument.getSelection()?.isCollapsed) return
    const { x, y } = windowPoint(e)
    if (Math.hypot(x - lastPoint.x, y - lastPoint.y) > 4) return
    const edge = innerWidth * EDGE
    if (x < edge) turn(() => view.goLeft())
    else if (x > innerWidth - edge) turn(() => view.goRight())
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
// ---- 查找：顶部浮条，Enter 下一个、Shift+Enter 上一个、Esc 关闭；命中处由 foliate 画高亮 ----
const find = { query: '', results: [], index: -1, run: 0 }
const findCount = text => { $('#find-count').textContent = text }
const openFind = () => {
  if (!view.book) return
  $('#find').hidden = false
  const input = $('#find-input')
  input.focus()
  input.select()
}
const closeFind = () => {
  if ($('#find').hidden) return
  $('#find').hidden = true
  find.run++ // 正在跑的搜索作废
  find.query = ''
  find.results = []
  find.index = -1
  findCount('')
  view.clearSearch()
  view.renderer?.getContents?.()?.[0]?.doc?.defaultView?.focus()
}
const runFind = async query => {
  const run = ++find.run
  find.query = query
  find.results = []
  find.index = -1
  view.clearSearch()
  if (!query) return findCount('')
  findCount('搜索中…')
  const gen = view.search({
    query, matchCase: false, matchDiacritics: false, matchWholeWords: false,
    draw: Overlayer.highlight, drawOptions: { color: '#ffd60a' },
  })
  let first = true
  for await (const r of gen) {
    if (run !== find.run) return gen.return()
    if (r === 'done') break
    if (r.subitems) {
      find.results.push(...r.subitems.map(({ cfi }) => cfi))
      if (first) { first = false; stepFind(1) } // 第一处命中立刻跳过去，不等整本搜完
      else findCount(`${find.index + 1} / ${find.results.length}…`)
    }
  }
  findCount(find.results.length ? `${find.index + 1} / ${find.results.length}` : '无结果')
}
const stepFind = step => {
  if ($('#find').hidden) return openFind()
  const n = find.results.length
  if (!n) return
  find.index = ((find.index + step) % n + n) % n
  findCount(`${find.index + 1} / ${n}`)
  view.goTo(find.results[find.index]).catch(e => post({ type: 'error', message: String(e) }))
}
let findTimer
$('#find-input').addEventListener('input', e => {
  clearTimeout(findTimer)
  findTimer = setTimeout(() => runFind(e.target.value.trim()), 300)
})
$('#find-input').addEventListener('keydown', e => {
  if (e.key === 'Escape') return closeFind()
  if (e.key !== 'Enter') return
  e.preventDefault()
  clearTimeout(findTimer)
  const q = e.target.value.trim()
  q === find.query ? stepFind(e.shiftKey ? -1 : 1) : runFind(q)
})
$('#find-prev').addEventListener('click', () => stepFind(-1))
$('#find-next').addEventListener('click', () => stepFind(1))
$('#find-close').addEventListener('click', closeFind)
listen(document)

let statusTimer
const flashStatus = () => {
  $('#status').classList.add('show')
  clearTimeout(statusTimer)
  statusTimer = setTimeout(() => $('#status').classList.remove('show'), 2000)
}

// ---- 进度指示：右下角点按循环 百分比 / 位置 / 本章剩余 / 全书剩余（Kindle 左下角那套） ----
// 剩余时间按本人翻页速度估：每次亲手翻页到下一次 relocate 的间隔与推进的字节数累计成速度，
// 太短（误触）或太长（走神）的间隔不算。速度和当前模式存 localStorage，所有书共用
const MODES = ['percent', 'location', 'chapter', 'book']
const SIZE_PER_LOC = 1500 // 与 view.js 里 SectionProgress 的参数一致：一个「位置」= 1500 字节
const DEFAULT_SPEED = 1600 // foliate 默认的每分钟字节数，样本不够时用
const MIN_SAMPLE_MINUTES = 3
const store = {
  get(k, d) { try { return JSON.parse(localStorage.getItem(k)) ?? d } catch { return d } },
  set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)) } catch {} },
}
let progressMode = MODES.includes(store.get('leaf.progressMode')) ? store.get('leaf.progressMode') : 'percent'
let speed = store.get('leaf.readingSpeed', { bytes: 0, minutes: 0 })
let lastTurn = null // { at, bytes }：上次亲手翻页的时刻与当时读到的字节位置
let lastLocation = null
const bytesAt = loc => (loc?.fraction ?? 0) * (loc?.location?.total ?? 0) * SIZE_PER_LOC
const sampleSpeed = loc => {
  const bytes = bytesAt(loc)
  if (lastTurn) {
    const minutes = (Date.now() - lastTurn.at) / 60000
    const advanced = bytes - lastTurn.bytes
    if (minutes >= 2 / 60 && minutes <= 5 && advanced > 0) {
      speed = { bytes: speed.bytes + advanced, minutes: speed.minutes + minutes }
      if (speed.minutes > 120) speed = { bytes: speed.bytes / 2, minutes: speed.minutes / 2 } // 旧样本慢慢淡出
      store.set('leaf.readingSpeed', speed)
    }
  }
  lastTurn = null
}
const bytesPerMinute = () => speed.minutes >= MIN_SAMPLE_MINUTES ? speed.bytes / speed.minutes : DEFAULT_SPEED
const fmtMinutes = m => {
  if (m < 1) return '不到 1 分钟'
  const h = Math.floor(m / 60), r = Math.round(m % 60)
  return h ? `${h} 小时${r ? ` ${r} 分钟` : ''}` : `${Math.round(m)} 分钟`
}
const progressText = loc => {
  if (!loc) return ''
  const learning = speed.minutes < MIN_SAMPLE_MINUTES
  // foliate 的 time 按 DEFAULT_SPEED 算，换成剩余字节再除以本人速度
  const left = t => fmtMinutes((t ?? 0) * DEFAULT_SPEED / bytesPerMinute())
  switch (progressMode) {
    case 'location': return loc.location ? `位置 ${loc.location.current} / ${loc.location.total}` : `${Math.round((loc.fraction ?? 0) * 100)}%`
    case 'chapter': return learning ? '本章剩余：测算中' : `本章剩余 ${left(loc.time?.section)}`
    case 'book': return learning ? '全书剩余：测算中' : `全书剩余 ${left(loc.time?.total)}`
    default: return `${Math.round((loc.fraction ?? 0) * 100)}%`
  }
}
const renderProgress = () => { $('#percent').textContent = progressText(lastLocation) }
$('#chapter').addEventListener('click', () => post({ type: 'toggleTOC' })) // 左下角章名 = 目录开关
$('#percent').addEventListener('click', () => {
  progressMode = MODES[(MODES.indexOf(progressMode) + 1) % MODES.length]
  store.set('leaf.progressMode', progressMode)
  renderProgress()
  flashStatus()
})

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
    markCJK(e.detail.doc)
    markDarkText(e.detail.doc)
    capHeadings(e.detail.doc)
  })
  view.addEventListener('relocate', e => {
    closeNote()
    flashStatus()
    const { cfi, fraction, tocItem } = e.detail
    sampleSpeed(e.detail)
    lastLocation = e.detail
    $('#chapter').textContent = tocItem?.label ?? ''
    renderProgress()
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

  applyStyles()
  addEventListener('resize', () => { if (prefs.columns === 'double') applyLayout() })
  darkMedia.addEventListener('change', applyStyles) // 跟随系统时，系统切换外观要重算底色

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
