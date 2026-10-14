# Fase 1.8J — Decisión técnica de AlbumArtworkImage

Documento de evaluación. No se modificó código de producción ni tests, no se
migró ningún consumidor y no se actualizaron `ARCHITECTURE.md` ni
`DESIGN_SYSTEM.md`. La evidencia sale de la lectura del código, de la
documentación del SDK de Flutter (3.41.9) y de un experimento con un test
temporal (ya borrado; se describe en §4 para poder repetirlo).

**Limitaciones de la evidencia.** No había dispositivo Android conectado:
lo que devuelve MediaStore en Android 10+ (`loadThumbnail`) **no está medido**.
Las cifras de §4 son de decodificación real de Flutter sobre PNG sintéticos,
no de carátulas reales.

---

## 1. Estado actual

`AlbumArtworkImage` (`lib/core/artwork/album_artwork_image.dart`, 72 líneas,
incluye la excepción `ArtworkUnavailable`) es un `ImageProvider<ArtworkKey>`
que lee los bytes de una `ArtworkCache` y los decodifica a un ancho fijo.

Verificado con búsquedas sobre `lib/`, `test/` y `docs/`:

| Tipo de referencia | Dónde |
|---|---|
| Consumidores de producción | **Ninguno** |
| Imports de producción | **Ninguno** |
| Referencias indirectas (subclases, reexports) | Ninguna |
| Tests | `test/core/widgets/taki_artwork_test.dart`: import (l. 6) y un grupo de 2 tests (l. 147–183) |
| Comentarios de código | `taki_artwork.dart:24` y `taki_song_tile.dart:51` (lo citan como ejemplo de fuente), y un comentario en el propio archivo (l. 9) que menciona `ArtworkImage`, ya eliminado |
| Documentación | `DESIGN_SYSTEM.md:1001` (vigente solo en apariencia: dice que la carátula local "llega como `AlbumArtworkImage`", y no es así) y `:1103` (histórica, dice que la carátula sale de `ArtworkCache` como `MemoryImage` y no de `AlbumArtworkImage`) |

`ArtworkUnavailable` solo se usa dentro del mismo archivo.

En Flutter no hay ningún ajuste de `imageCache` en `lib/`: rigen los valores
por defecto (hasta 1000 imágenes y 100 MiB decodificadas).

---

## 2. Qué aporta AlbumArtworkImage

Separado por capas:

| Capa | AlbumArtworkImage |
|---|---|
| Resolución del artwork | Pide `cache.load((albumId, size × dpr))` **dentro** de `loadImage`, al resolver la imagen. El `dpr` sale de la `ImageConfiguration` que pasa el widget `Image` |
| Caché de bytes | Usa la `ArtworkCache` recibida por parámetro (`cache`). Siempre asíncrono: no consulta `contains`/`peek` |
| Bytes → imagen | `MultiFrameImageStreamCompleter` con `decode(buffer, getTargetSize: …)` |
| Tamaño físico pedido | `(size × dpr).round()`, la misma fórmula que el builder |
| Decodificación limitada | **Sí**: `getTargetSize: (w, h) => TargetImageSize(width: key.size)` |
| Ausencia de artwork | Lanza `ArtworkUnavailable` si los bytes son `null` o vacíos |
| Errores | Los del repositorio los convierte `ArtworkCache` en `null` (→ `ArtworkUnavailable`); los de decodificación los maneja `TakiArtwork.errorBuilder` |
| ImageCache de Flutter | La clave es el `ArtworkKey` `(albumId, size)` (más la `cache` por identidad en `==`) |

---

## 3. Comparación con AlbumArtworkBuilder

| Capa | AlbumArtworkBuilder | AlbumArtworkImage |
|---|---|---|
| Resolución | Widget con estado (`ConsumerStatefulWidget`): resuelve en `didChangeDependencies`/`didUpdateWidget` | En el propio `ImageProvider`, al resolverse la imagen |
| Caché de bytes | `ref.read(artworkCacheProvider)`; acierto **síncrono** con `contains`/`peek` | `cache` por parámetro; siempre `await cache.load` |
| Bytes → imagen | `MemoryImage(bytes)` | `decode(…, getTargetSize: …)` |
| Tamaño físico **pedido al repositorio** | `(size × dpr).round()` (mosaico: `floor(size/2)`) | `(size × dpr).round()` |
| Decodificación en Flutter | **Al tamaño intrínseco de los bytes**, sin límite | **Acotada a `key.size` de ancho** |
| Ausencia de artwork | Entrega `null`; no hay excepción | Excepción `ArtworkUnavailable` en cada resolución |
| Clave en ImageCache | Los bytes (identidad + escala de `MemoryImage`) | `(albumId, size)` |
| `ArtworkCache.clear()` | Nuevos widgets reciben bytes nuevos → clave nueva | Misma clave → Flutter puede servir la imagen vieja (ver E4) |
| Mosaicos | Sí (`AlbumArtworkMosaicBuilder`) | No: una imagen por provider |

**Conclusión de la comparación.** `AlbumArtworkBuilder` usa el tamaño físico
solo como **pista al repositorio** (primera capa). No lo aplica a la
decodificación de Flutter (cuarta capa): `TakiArtwork` dibuja con
`Image(image: …, width, height, fit: cover)` sin `cacheWidth` y el builder
entrega `MemoryImage(bytes)` sin `ResizeImage`. Por tanto **`size` en la
petición y `cacheWidth` son cosas distintas y hoy solo se aplica la primera.**

Las dos capas por separado:

```
MediaStore / ArtworkRepository   ← aquí se aplica (size × dpr), como pista: "lado aproximado"
        ↓
ArtworkCache                     ← guarda los bytes por (albumId, size); no decodifica
        ↓
bytes (JPEG)
        ↓
ImageProvider                    ← MemoryImage (builder) | decode con getTargetSize (AlbumArtworkImage)
        ↓
decodificación de Flutter        ← tamaño intrínseco (builder) | ancho = key.size (AlbumArtworkImage)
```

---

## 4. Análisis de getTargetSize / decodificación

**Qué recibe.** El callback `getTargetSize: (width, height)` recibe las
dimensiones **intrínsecas** de la imagen codificada. `AlbumArtworkImage` las
ignora y devuelve siempre `TargetImageSize(width: key.size)`, donde
`key.size = (size lógico × dpr).round()` y el `dpr` es el de la
`ImageConfiguration` (`configuration.devicePixelRatio ?? 1`).

**Qué pide y dónde se aplica.** Pide un ancho en píxeles físicos, y lo
aplica **al decodificar** (antes de que la imagen entre en `ImageCache`); el
alto se calcula por proporción. No cambia lo que se pide al repositorio.

**Diferencia con `ResizeImage`.** Según la documentación del SDK,
`ResizeImage` con `allowUpscaling: false` (el valor por defecto) limita el
resultado al tamaño intrínseco. `AlbumArtworkImage` se comporta como
`allowUpscaling: true`.

**Experimento** (test temporal, borrado; decodificación real de Flutter de
PNG sintéticos cuadrados; se piden 144 px = 48 lógicos a dpr 3):

| Caso | `AlbumArtworkImage` | `MemoryImage` (builder) | `ResizeImage(ancho 144)` |
|---|---|---|---|
| E1: el repositorio devuelve **más** (300 px) | 144×144 | **300×300** | 144×144 |
| E2: el repositorio devuelve **menos** (50 px) | **144×144** (amplía) | 50×50 | 50×50 |
| E3: devuelve justo lo pedido (144 px) | 144×144 | 144×144 | 144×144 |

- **E4 — tras `cache.clear()` y arte nuevo con el mismo `(albumId, size)`**
  (rojo → azul): `AlbumArtworkImage` devuelve **rojo** (la imagen vieja, servida
  desde el `ImageCache` de Flutter) aunque la `ArtworkCache` ya tenía los bytes
  azules; `MemoryImage` sobre los bytes nuevos devuelve azul.
- **E5 — álbum sin carátula:** lanza `ArtworkUnavailable` en cada resolución,
  pero el repositorio se consultó **una sola vez** (`ArtworkCache` recuerda el
  `null`). No se repiten lecturas nativas.

**Qué beneficio tiene.** Acota los píxeles decodificados cuando los bytes son
más grandes que el lado necesario (E1: −77 % de píxeles, 300² → 144²). La
memoria decodificada es ancho × alto × 4 bytes: por ejemplo, una fila de 126 px
ocupa 63 504 B y una de 252 px, 254 016 B. La portada de Reproduciendo
(≈898 px a dpr 2.625) ocupa ≈3,2 MB si los bytes miden lo pedido.

**Por qué puede no importar, y por qué puede importar, en Taki.**
- Solo hay beneficio si el repositorio devuelve bytes **mayores** que el lado
  pedido. Por el código nativo (`MediaStoreChannel.kt`):
  - **Android 7–9** (`legacyAlbumArt`): submuestrea por potencias de 2 mientras
    `lado / (muestra × 2) ≥ size`, así que el resultado queda entre `size` y
    `2 × size` de lado. Con una carátula de 1000 px y 126 px pedidos resulta de
    250 px: unas **3,9 veces** los píxeles necesarios. Esto es un hecho del
    código.
  - **Android 10+** (`loadThumbnail(uri, Size(size, size), …)`): el tamaño
    devuelto lo decide el sistema. **No está verificado** y depende de la
    versión y de las miniaturas disponibles. El port lo documenta como "lado
    aproximado".
- Cuando el repositorio devuelve **menos** (carátula original pequeña),
  `AlbumArtworkImage` amplía (E2) y gasta más memoria que `MemoryImage` sin
  aportar detalle.

**Conclusión:** el beneficio existe solo con bytes sobredimensionados; para
este proyecto es real como mínimo en Android 7–9 y desconocido en Android 10+.
La implementación actual, además, tiene dos defectos medidos: amplía (E2) y
puede servir imagen vieja tras `clear()` (E4).

---

## 5. Cobertura de tests

Los 2 tests de `AlbumArtworkImage` (`taki_artwork_test.dart`) **no comprueban
la decodificación acotada**: solo verifican la petición y que se muestre la
imagen, o el placeholder.

| Contrato | AlbumArtworkImage | AlbumArtworkBuilder | Estado |
|---|---|---|---|
| Pide al repositorio, vía `ArtworkCache`, el lado en px físicos (`size × dpr`) | Test 1 (`requests == [(7, round(48 × ratio))]`) | `tamaño físico = (size × dpr).round()`, cambios de size y de dpr, y las aserciones de petición de las páginas | **Cubierto por ambos** |
| Se muestra la imagen cuando hay carátula | Test 1 (`RawImage` con imagen) | `artwork disponible: MemoryImage…` y ~25 aserciones `as MemoryImage` en 9 archivos de test | **Cubierto por ambos** |
| Álbum sin carátula → placeholder sin excepción | Test 2 (kind `playlist`, sin excepción) | `artwork ausente: null…`, `bytes vacíos`, `lectura fallida` + los tests de placeholder de `TakiArtwork` | **Mismo resultado**, distinto mecanismo (excepción frente a `null`) |
| Decodificación acotada al lado pedido (`getTargetSize`) | **Sin test** | No existe | **No lo cubre nadie** |
| Clave en `ImageCache` por `(albumId, size)` | Sin test | No aplica (la clave son los bytes) | Sin cobertura; comportamiento distinto (E4) |
| Comportamiento tras `ArtworkCache.clear()` | Sin test | Documentado: no reacciona con la misma clave | Distinto; ninguno lo prueba para `ImageCache` |
| Acierto síncrono de caché en la primera construcción | No lo tiene | `cache hit: la primera construcción ya trae la imagen` | Solo builder |
| Sin carátula no repite lecturas nativas | Sin test (E5 lo mostró) | `ArtworkCache`: `recuerda los álbumes sin carátula` | Lo cubre `ArtworkCache` |

---

## 6. Riesgos de eliminarlo

- **¿Se perdería alguna optimización?** En producción no: no se usa. Se
  perdería una posible optimización (decodificación acotada) que nunca ha
  estado activa y que ningún test protege.
- **¿Aumentaría el uso de memoria?** No respecto a hoy: hoy ya se decodifica
  con `MemoryImage` al tamaño intrínseco.
- **¿Cambiaría el comportamiento visual?** No.
- **¿Cambiaría el de errores?** No: en producción los errores ya pasan por el
  builder.
- **¿Cambiaría la semántica de artwork inexistente?** No: el builder entrega
  `null`; `AlbumArtworkImage` no participa.
- **DPR alto:** el riesgo existe con o sin este archivo. Al crecer el `dpr`,
  crece el lado pedido y los píxeles decodificados (con bytes del tamaño
  pedido, como el cuadrado del lado). Eliminar el archivo no lo introduce ni
  lo agrava. Lo que sí quedaría sin resolver, si se comprueba que es real, es
  la decodificación de bytes sobredimensionados.

---

## 7. Opciones

### Opción A — conservar

- **Ventajas:** ningún cambio ni riesgo; conserva un punto de partida para la
  decodificación acotada.
- **Desventajas:** código sin uso (72 líneas y 2 tests) con dos defectos
  medidos (E2, E4); documentación y comentarios con referencias confusas
  (`DESIGN_SYSTEM.md:1001`).
- **Cambios requeridos:** ninguno.
- **Riesgo:** nulo para producción.
- **Impacto arquitectónico:** ninguno.

### Opción B — trasladar la capacidad al sistema compartido

Hay dos variantes técnicamente distintas.

**B1 — `ResizeImage(MemoryImage(bytes), width: lado)` dentro de
`AlbumArtworkBuilder`.**
- **Ventajas:** acota la decodificación sin ampliar (E1 y E2); conserva la
  clave por bytes, así que no sirve imágenes viejas tras `clear()`; usa una
  clase estándar de Flutter; `TakiArtwork` no cambia.
- **Desventajas:** modifica la infraestructura de 1.8A; cambia el tipo de
  provider que recibe `TakiArtwork`; la clave del `ImageCache` pasa a incluir
  el tamaño.
- **Cambios requeridos:** el builder (guardar el lado físico ya calculado y
  envolver la imagen) y sus tests; ~25 aserciones `as MemoryImage` en 9
  archivos de test habría que adaptarlas (p. ej. desenvolviendo
  `ResizeImage.imageProvider`).
- **Riesgo:** bajo a medio: toca todas las pantallas a la vez, aunque la
  imagen visible no cambia.
- **Impacto arquitectónico:** dentro de `core/artwork`; sin cambios en
  puertos ni en features.

**B2 — usar `AlbumArtworkImage` como provider del builder.**
- **Ventajas:** reutiliza código existente con tests.
- **Desventajas:** hereda E2 (amplía) y E4 (imagen vieja tras `clear()`);
  pierde el acierto síncrono de caché; obliga a pasar la `ArtworkCache` a cada
  provider; no cubre `null`.
- **Cambios requeridos:** reescribir la resolución del builder y de los
  mosaicos.
- **Riesgo:** medio a alto.
- **Impacto arquitectónico:** cambia el modelo de resolución (de widget con
  estado a `ImageProvider`).

### Opción C — eliminar

- **Ventajas:** quita código sin uso y las referencias confusas; ningún otro
  cambio.
- **Desventajas:** se pierde el punto de partida de la decodificación acotada;
  si después se demuestra que hace falta, habrá que escribirla (en B1 es
  una línea de Flutter).
- **Cambios requeridos:** eliminar `album_artwork_image.dart`, el grupo de 2
  tests y el import de `taki_artwork_test.dart`, y actualizar 2 líneas de
  `DESIGN_SYSTEM.md` y 3 comentarios. Los 2 tests dejan de proteger: la
  petición al tamaño físico y el placeholder **cuando el provider lanza
  `ArtworkUnavailable`** (ambos resultados siguen cubiertos por el builder).
- **Riesgo:** nulo en producción.
- **Impacto arquitectónico:** ninguno.

---

## 8. Recomendación técnica

1. **No adoptar `AlbumArtworkImage` tal como está** (B2): los experimentos E2
   y E4 muestran dos comportamientos peores que los del builder actual, y sus
   tests no protegen precisamente lo que aportaría (la decodificación
   acotada).
2. **La capacidad que aporta es real pero no está demostrada como necesaria
   en Taki.** El beneficio existe solo con bytes mayores que el lado pedido;
   el código demuestra que ocurre en Android 7–9 (hasta ~4 veces los píxeles)
   y el comportamiento en Android 10+ no está medido.
3. **Decisión:** **conservar (A) por ahora**, sin tocar nada, y decidir entre
   **B1** y **C** con una medición, porque ambos caminos terminan sin
   `AlbumArtworkImage`:
   - si la medición muestra bytes sobredimensionados de forma relevante → B1
     (`ResizeImage` en el builder) y se elimina `AlbumArtworkImage`;
   - si no → C (se elimina, junto a su grupo de tests).
4. Eliminar ya (C) no empeoraría nada en producción, pero se descartaría una
   capacidad sin tener la evidencia que la justifique. Esa es la única razón
   para esperar.

---

## 9. Próximo paso propuesto

**Fase 1.8K — medición en dispositivo** (sin implementar el cambio):

- Instrumentación temporal, no integrada en producción, que registre por cada
  `getAlbumArtwork(albumId, size)` el lado que devuelve MediaStore, frente al
  pedido, en al menos un Android 10+ y, si es posible, uno 7–9.
- Medir la memoria de imágenes decodificadas (DevTools, `ImageCache`) en las
  pantallas con más carátulas: Biblioteca, Reproduciendo y el mosaico del
  detalle de una playlist.
- Con esos datos, decidir **B1 o C** y abrir la fase correspondiente. La
  documentación pendiente (`ARCHITECTURE.md` y `DESIGN_SYSTEM.md`, incluidas
  las líneas 1001 y 1103) y los comentarios que mencionan `ArtworkImage` se
  actualizan en la fase de documentación, no aquí.
