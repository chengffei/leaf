// 大章节分块：EPUB 里超过 CHUNK_MIN 的章节切成几个虚拟章节，开书只排第一块。
// 只动书对象（sections、resolveHref、resolveCFI），foliate 不打补丁。
// 块外的节点不删：元素换成页面外的空 span、文本置空，DOM 路径与原章节一致，
// 所以 CFI 照旧按原章节生成和解析，存下的进度不受影响。
const CHUNK_MIN = 128 * 1024 // 章节超过这么多字节才切
const CHUNK_SIZE = 64 * 1024 // 每块目标字节数

const fragmentOf = (doc, id) => doc.getElementById(id)
  ?? doc.querySelector(`[name="${CSS.escape(id)}"]`)

// 从 body 往下穿过只有一个元素子节点的包装层，到能切的那一层
const containerOf = doc => {
  let el = doc.body
  while (el?.children.length === 1
    && ![...el.childNodes].some(n => n.nodeType === 3 && n.data.trim())) el = el.firstElementChild
  return el
}

// 每个子节点分到哪一块：按文字量累计均分；节点够多时保证每块至少一个节点
const plans = new WeakMap()
const planOf = (doc, n) => {
  if (plans.has(doc)) return plans.get(doc)
  const container = containerOf(doc)
  let plan = null
  if (container) {
    const nodes = [...container.childNodes]
    const weights = nodes.map(x => (x.textContent?.length ?? 0) + 1)
    const total = weights.reduce((a, b) => a + b, 0)
    const chunkOf = []
    let sum = 0, prev = 0
    for (const [i, w] of weights.entries()) {
      const want = Math.floor(sum / total * n)
      const mustReach = n - (nodes.length - i) // 剩下的节点得够填满后面的块
      prev = i === 0 ? 0 : Math.min(prev + 1, Math.max(prev, want, mustReach))
      chunkOf.push(prev)
      sum += w
    }
    plan = { container, nodes, chunkOf, count: (chunkOf.at(-1) ?? 0) + 1 }
  }
  plans.set(doc, plan)
  return plan
}

// 节点所在的容器直接子节点序号
const topIndex = (plan, node) => {
  if (node === plan.container) return 0
  while (node && node.parentNode !== plan.container) node = node.parentNode
  return plan.nodes.indexOf(node)
}
const chunkOfNode = (plan, node) => {
  const i = plan && node ? topIndex(plan, node) : -1
  return i < 0 ? 0 : plan.chunkOf[i]
}

// 只留第 k 块；目录片段落在块外时，在占位元素里放同 id 的空标记，
// 好让 foliate 的目录进度照原顺序比较位置
const cut = (doc, plan, k, fragments) => {
  const markers = new Map() // 子节点序号 → 要保留的 id
  for (const id of fragments) {
    const el = fragmentOf(doc, id)
    const i = el ? topIndex(plan, el) : -1
    // 片段就是占位元素本身时不用标记：清空内容不动属性
    if (i < 0 || plan.chunkOf[i] === k || plan.nodes[i] === el) continue
    markers.set(i, [...markers.get(i) ?? [], id])
  }
  for (const [i, node] of plan.nodes.entries()) {
    if (plan.chunkOf[i] === k) continue
    if (node.nodeType === 1) {
      // 整个换成空 span：元素个数和顺序不变，CFI 照旧。只留 id、name 供链接和目录定位。
      // 占位挪到页面外：foliate 按矩形判断可见范围，display: none 或 <br> 这类不吃定位的元素
      // 矩形在原点，会被算进第一页；留在原位的零高块会被算进最后一页
      const span = doc.createElementNS(node.namespaceURI, 'span')
      for (const name of ['id', 'name']) if (node.hasAttribute(name)) span.setAttribute(name, node.getAttribute(name))
      span.setAttribute('style', PLACEHOLDER)
      span.append(...(markers.get(i) ?? []).map(id => {
        const marker = doc.createElementNS(node.namespaceURI, 'span')
        marker.id = id
        return marker
      }))
      node.replaceWith(span)
    } else if (node.nodeType === 3) node.data = ''
  }
  return doc
}

const PLACEHOLDER = ['display: block', 'position: absolute', 'left: -99999px', 'top: -99999px',
  'width: 0', 'height: 0', 'margin: 0', 'padding: 0', 'border: 0', 'overflow: hidden']
  .map(x => `${x} !important`).join('; ')

const serialize = (doc, type) => type.includes('xml')
  ? new XMLSerializer().serializeToString(doc)
  : '<!DOCTYPE html>\n' + doc.documentElement.outerHTML

// 原章节文档只缓存最近一章：查找会逐章扫，全缓存会把合集撑爆内存
let rawCache = null
let renderedCache = null

export const chunkSections = book => {
  if (!book.resources?.manifest || book.rendition?.layout === 'pre-paginated') return
  const isHTML = s => /html/.test(book.resources.getItemByHref(s.id)?.mediaType ?? '')
  if (!book.sections.some(s => s.size > CHUNK_MIN && isHTML(s))) return

  // 目录和页码表里落在大章节的片段
  const tocFragments = new Map()
  const walk = list => list?.forEach(item => {
    const [path, frag] = item.href?.split('#') ?? []
    if (frag) tocFragments.set(path, [...tocFragments.get(path) ?? [], frag])
    walk(item.subitems)
  })
  walk(book.toc)
  walk(book.pageList)

  const splits = new Map() // 原章节序号 → { first, n, raw() }
  const newIndex = []
  const sections = []
  for (const [i, section] of book.sections.entries()) {
    newIndex[i] = sections.length
    if (!(section.size > CHUNK_MIN && isHTML(section))) {
      sections.push(section)
      continue
    }
    const n = Math.ceil(section.size / CHUNK_SIZE)
    const fragments = tocFragments.get(section.id) ?? []
    const split = {
      first: sections.length,
      n,
      raw: () => {
        if (rawCache?.split !== split)
          rawCache = { split, doc: Promise.resolve(section.createDocument()) }
        return rawCache.doc
      },
      // 已经按渲染版排过版的文档（资源链接换成了 blob），按 URL 缓存
      rendered: async url => {
        if (renderedCache?.url !== url) renderedCache = {
          url, doc: fetch(url).then(r => r.blob()).then(async blob => {
            const type = blob.type || 'application/xhtml+xml'
            return { type, doc: new DOMParser().parseFromString(await blob.text(), type) }
          }),
        }
        return renderedCache.doc
      },
      // 块数不够时（单个节点特别大，或文档没有 body），多出来的空块标成非线性，翻页跳过
      markEmpty: plan => {
        for (let k = plan?.count ?? 1; k < n; k++) sections[split.first + k].linear = 'no'
      },
    }
    splits.set(i, split)
    for (let k = 0; k < n; k++) {
      let url = null
      sections.push({
        ...section,
        size: section.size / n,
        load: async () => {
          const src = await section.load()
          const { type, doc } = await split.rendered(src)
          const copy = doc.cloneNode(true)
          const plan = planOf(copy, n)
          split.markEmpty(plan)
          if (!plan && k === 0) return src // 切不了就由第一块整章渲染
          if (plan) cut(copy, plan, k, fragments)
          else copy.documentElement.replaceChildren()
          url = URL.createObjectURL(new Blob([serialize(copy, type)], { type }))
          return url
        },
        unload: () => {
          if (url) URL.revokeObjectURL(url)
          url = null
          section.unload()
        },
        createDocument: async () => {
          const doc = await split.raw()
          const plan = planOf(doc, n)
          if (!plan) return k === 0 ? doc : document.implementation.createHTMLDocument()
          const copy = doc.cloneNode(true)
          return cut(copy, planOf(copy, n), k, fragments)
        },
      })
    }
  }
  book.sections = sections

  // 链接和 CFI 先按原章节解析，落到大章节时再看具体在哪一块
  const resolveHref = book.resolveHref.bind(book)
  book.resolveHref = href => {
    const r = resolveHref(href)
    if (!r || r.index < 0) return r
    const split = splits.get(r.index)
    if (!split) return { ...r, index: newIndex[r.index] }
    const hash = href.split('#')[1]
    if (!hash) return { ...r, index: split.first }
    return split.raw().then(doc => {
      const plan = planOf(doc, split.n)
      const el = fragmentOf(doc, hash)
      return { ...r, index: split.first + chunkOfNode(plan, el) }
    })
  }
  const resolveCFI = book.resolveCFI.bind(book)
  book.resolveCFI = cfi => {
    const r = resolveCFI(cfi)
    if (!r || r.index < 0) return r
    const split = splits.get(r.index)
    if (!split) return { ...r, index: newIndex[r.index] }
    return split.raw().then(doc => {
      let node = null
      try { node = r.anchor(doc)?.startContainer } catch { /* 解析不了就去第一块 */ }
      return { ...r, index: split.first + chunkOfNode(planOf(doc, split.n), node) }
    })
  }
}
