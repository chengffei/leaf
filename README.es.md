<p align="center">
  <img src="docs/images/icon.png" width="128" alt="Leaf">
</p>

<h1 align="center">Leaf</h1>

<p align="center">
  Doble clic para leer. Cierra y listo.<br>
  Un lector de libros electrónicos ligero y nativo para Mac. Gratis y de código abierto.
</p>

<p align="center">
  <a href="https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg"><b>Descargar</b></a> ·
  <a href="https://chengffei.github.io/leaf/">Sitio web</a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <b>Español</b>
</p>

<p align="center">
  <img src="docs/images/reading.png" width="760" alt="Leaf en modo lectura">
</p>

## Por qué Leaf

Un libro, una ventana. Haz doble clic en un libro en el Finder y empieza a leer. Cierra la ventana y Leaf se cierra.

- **Sin biblioteca.** Nada que importar, nada que copiar, sin cuenta.
- **Sigue donde lo dejaste.** Aunque cambies el nombre del archivo o lo muevas.
- **Como en casa en tu Mac.** Menús nativos, atajos de teclado, Consultar y Traducir. Unos 5 MB.

## Pensado para leer

- **Seis formatos.** EPUB, MOBI, AZW3, PDF, FB2 y CBZ se abren tal cual, sin convertir. Los MOBI y AZW3 deben estar libres de DRM. Los PDF conservan su diseño original.
- **La letra a tu manera.** Cualquier tipo de letra, con Literata incluida. Tamaño del 80 al 200 %, cinco grosores y ajustes de interlineado, espacio entre párrafos, espaciado entre letras, márgenes y alineación.
- **Ajustes predefinidos.** Compacto, Estándar, Grande, Baja visión y Tinta electrónica. También puedes guardar los tuyos.
- **Temas.** Papel, Sepia, Tinta electrónica y Oscuro, o el del sistema.
- **Tiempo restante.** Haz clic en la esquina inferior derecha para ver el porcentaje, la posición o el tiempo que queda del capítulo o del libro, calculado según tu ritmo de lectura.
- **Notas en su sitio.** Haz clic en una llamada de nota y aparece justo ahí. Tras cualquier salto, `⌘[` te devuelve.
- **Buscar e ir a.** `⌘F` lista los resultados por capítulo. `⌘L` te lleva a cualquier porcentaje o posición.
- **Índice flotante.** `⌘T` lo abre sobre la página, así el texto no se recoloca.
- **Diseño.** Ajusta el ancho del texto, lee en una o dos columnas y haz clic en los bordes para pasar de página.
- **Imágenes.** Haz doble clic en una imagen para verla a tamaño completo.
- **Resaltados y notas.** Selecciona texto, elige uno de cuatro colores y añade una nota. `⌘D` marca la página. El panel de notas (`⇧⌘N`) lo lista todo por capítulo.
- **Exportar.** En Markdown o en el formato My Clippings de Kindle, para Readwise y Obsidian.
- **Consultar en un solo paso.** Selecciona una palabra y pulsa `⌃⌘D`, o usa la barra que aparece sobre la selección.
- **Sobre el libro.** La descripción de los metadatos del libro, en la cabecera del panel.
- **Ocho idiomas.** Inglés, chino simplificado, chino tradicional, japonés, coreano, francés, alemán y español.

## Comparativa

[Readest](https://github.com/readest/readest) es el más completo. Apple Books viene con tu Mac. Calibre es el mejor para gestionar una colección. Leaf solo abre un libro. Consulta la [comparativa completa](https://chengffei.github.io/leaf/#compare).

## Próximamente

- Tus ajustes de fuente por encima de los del editor, y archivos TXT
- Números de página reales y una forma de volver tras hojear más adelante
- Miniaturas en el Finder, Vista Rápida y búsqueda con Spotlight, más adelante

No está previsto: biblioteca, tienda, cuenta ni sincronización.

## Instalación

1. Descarga [Leaf.dmg](https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg) y arrastra Leaf a Aplicaciones.
2. Leaf no está notarizada por Apple, así que macOS la bloquea la primera vez. Ábrela y haz clic en **OK**. Después ve a **Ajustes del Sistema › Privacidad y seguridad**, desplázate hacia abajo y haz clic en **Abrir igualmente**.

Requiere macOS 15 o posterior.

## Atajos de teclado

| Acción | Teclas |
|---|---|
| Pasar página | `←` `→`, barra espaciadora o deslizar en el trackpad |
| Índice | `⌘T` o `T`, o clic en el nombre del capítulo abajo a la izquierda |
| Tamaño del texto | `⌘=` más grande, `⌘-` más pequeño, `⌘0` tamaño real |
| Buscar | `⌘F`, luego `⌘G` siguiente y `⇧⌘G` anterior |
| Ir a | `⌘L` |
| Tamaño y tema | `Aa` arriba a la derecha, o clic derecho en la página |
| Ajustes | `⌘,` |
| Resaltar | Selecciona texto y elige un color |
| Marcador | `⌘D` |
| Notas | `⇧⌘N` |
| Consultar | `⌃⌘D` |

## Compilar desde el código fuente

Requiere Xcode 26 y [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
./scripts/install.sh      # compilar e instalar en /Applications
./scripts/make-dmg.sh     # crear un DMG en ~/Downloads
```

Las notas de arquitectura y los problemas conocidos están en [DEVELOPMENT.md](DEVELOPMENT.md) (en chino).

## Créditos

Renderizado y análisis de formatos con [foliate-js](https://github.com/johnfactotum/foliate-js) (MIT). Los libros de ejemplo de `TestBooks/` provienen del [Proyecto Gutenberg](https://www.gutenberg.org/) y son de dominio público.

## Contribuir

Las contribuciones son bienvenidas. Para contribuir con código hay que aceptar el [acuerdo de licencia para colaboradores](CLA.md).

## Licencia

[GPL-3.0](LICENSE). foliate-js mantiene su licencia MIT en `Web/foliate/LICENSE`.
