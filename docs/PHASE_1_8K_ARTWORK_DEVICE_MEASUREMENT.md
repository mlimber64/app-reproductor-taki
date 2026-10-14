# Fase 1.8K — Medición real de artwork en dispositivo Android

Estado: medición completada en **un emulador Android 15 (API 35)**. No se dispuso de ningún dispositivo físico ni de ninguna imagen Android 7–9. Este documento **no decide entre B1 y C** (ver sección 8).

## 1. Objetivo

Medir qué devuelve realmente `MediaStore` cuando Taki pide una carátula de un tamaño dado (`MediaStoreChannel.getArtwork(albumId, size)`), y cómo decodifican esos bytes `MemoryImage` (comportamiento actual de `AlbumArtworkBuilder`) y `ResizeImage` (candidato en la decisión B1/C de la Fase 1.8J). Solo se registran **dimensiones en píxeles**; no se midió memoria.

## 2. Dispositivo y entorno

| Dato | Valor |
|---|---|
| Tipo | **Emulador** (AVD `peru_api35`), no hardware físico |
| Modelo / fabricante / marca | `sdk_gphone64_x86_64` / Google / Google |
| Android | 15 (release), **API 35** |
| Build | `google/sdk_gphone64_x86_64/emu64xa:15/AE3A.240806.043/12960925:userdebug/dev-keys` |
| ABI | x86_64 (`ro.kernel.qemu=1`) |
| Pantalla | 1080×2400 px, densidad 420 dpi |
| DPR | **2,625** (420 / 160; leído de `wm density`) |
| Flutter | 3.41.9 |
| Ruta de código ejercitada | Android ≥ Q: `contentResolver.loadThumbnail(albumUri, Size(size, size), null)` |

Nota sobre el DPR: el log de la propia app imprimió `dpr=1.0, physical=0x0` porque se consultó la vista antes del primer frame. Ese valor **no es válido y se descarta**; el DPR de la tabla viene del sistema. Es un valor del dispositivo, no se varió por petición: todas las filas usan 2,625.

**Android 7–9 (API 24–28): NO medido.** No hay imagen de sistema instalada. La rama `legacyAlbumArt` (`inSampleSize` potencia de 2) solo se conoce por lectura de código; este documento no afirma ningún comportamiento medido para ella.

**Android 10+:** medido únicamente en API 35 sobre un emulador con MediaProvider de Google. No se afirma que Android 10–14 ni dispositivos de otros fabricantes (OEM) se comporten igual.

## 3. Metodología

1. **Fixtures sintéticas**: 10 MP3 silenciosos (~36 s, ID3v2.3) con carátula JPEG incrustada (APIC), artista `Fixture 1.8K`, un álbum por archivo. Carátulas cuadradas de 64, 128, 200, 300, 500, 1000, 1400 y 3000 px, una de 1000×600 (no cuadrada) y una canción **sin carátula**. Las JPEG se generaron con `System.Drawing`; los MP3 con un script Dart propio.
2. Se copiaron a una carpeta propia de `/sdcard/Music/` y se escanearon a MediaStore (10 filas confirmadas por `content query`).
3. **Instrumentación temporal**: un punto de entrada aparte (`lib/zz_artwork_measure.dart`, compilado con `-t`; `main.dart` no se tocó) que usa el `MediaStoreSongRepository` y el `MediaStoreArtworkRepository` **reales**, pide cada álbum a cada tamaño, decodifica los bytes recibidos para obtener sus dimensiones intrínsecas y resuelve `MemoryImage`, `ResizeImage(width: size)` y `ResizeImage(width: size, allowUpscaling: true)` con `ImageConfiguration.empty`, vaciando el `ImageCache` entre medidas.
4. Tamaños pedidos: 64, 96, 126, 144, 250, 300, 512 (los del brief) más 336 y 898 (898 = 342 lp × 2,625, tamaño del hero de Now Playing). 10 álbumes × 9 tamaños = 90 peticiones, **una sola petición por combinación** (no se midió repetibilidad).
5. Las dimensiones se leyeron de los logs (`K18|ROW|…`) sin post-proceso salvo el cálculo del cociente.
6. **Retirado al terminar**: se borró el archivo temporal, se eliminaron las fixtures del emulador (MediaStore sin filas de `Fixture 1.8K`) y se reinstaló la compilación normal. Sin cambios en código de producción.

Limitaciones de método: ver sección 7.

## 4. Resultados

«Tamaño físico solicitado» es el valor en píxeles enviado a MediaStore (el repositorio recibe ya píxeles). El equivalente en lp (px / 2,625) es aritmética informativa, no una medición. «Recibido» son las dimensiones del JPEG devuelto; para 1000×600 el cociente usa el **ancho**. `null` = el canal devolvió `null` (sin carátula incrustada).

| Álbum / caso | Solicitado (px) | DPR | Físico solicitado | Recibido (px) | Recibido / solicitado |
|---|---:|---:|---:|---:|---:|
| 1000x1000 | 64 (~24,4 lp) | 2,625 | 64 px | 66x66 | 1,03× |
| 1000x1000 | 96 (~36,6 lp) | 2,625 | 96 px | 100x100 | 1,04× |
| 1000x1000 | 126 (~48 lp) | 2,625 | 126 px | 142x142 | 1,13× |
| 1000x1000 | 144 (~54,9 lp) | 2,625 | 144 px | 166x166 | 1,15× |
| 1000x1000 | 250 (~95,2 lp) | 2,625 | 250 px | 250x250 | 1,00× |
| 1000x1000 | 300 (~114,3 lp) | 2,625 | 300 px | 333x333 | 1,11× |
| 1000x1000 | 512 (~195 lp) | 2,625 | 512 px | 1000x1000 | 1,95× |
| 1000x1000 | 336 (~128 lp) | 2,625 | 336 px | 500x500 | 1,49× |
| 1000x1000 | 898 (~342,1 lp) | 2,625 | 898 px | 1000x1000 | 1,11× |
| 1000x600 | 64 (~24,4 lp) | 2,625 | 64 px | 66x40 | 1,03× |
| 1000x600 | 96 (~36,6 lp) | 2,625 | 96 px | 100x60 | 1,04× |
| 1000x600 | 126 (~48 lp) | 2,625 | 126 px | 142x85 | 1,13× |
| 1000x600 | 144 (~54,9 lp) | 2,625 | 144 px | 166x100 | 1,15× |
| 1000x600 | 250 (~95,2 lp) | 2,625 | 250 px | 250x150 | 1,00× |
| 1000x600 | 300 (~114,3 lp) | 2,625 | 300 px | 333x200 | 1,11× |
| 1000x600 | 512 (~195 lp) | 2,625 | 512 px | 1000x600 | 1,95× |
| 1000x600 | 336 (~128 lp) | 2,625 | 336 px | 500x300 | 1,49× |
| 1000x600 | 898 (~342,1 lp) | 2,625 | 898 px | 1000x600 | 1,11× |
| 128x128 | 64 (~24,4 lp) | 2,625 | 64 px | 64x64 | 1,00× |
| 128x128 | 96 (~36,6 lp) | 2,625 | 96 px | 128x128 | 1,33× |
| 128x128 | 126 (~48 lp) | 2,625 | 126 px | 128x128 | 1,02× |
| 128x128 | 144 (~54,9 lp) | 2,625 | 144 px | 128x128 | 0,89× |
| 128x128 | 250 (~95,2 lp) | 2,625 | 250 px | 128x128 | 0,51× |
| 128x128 | 300 (~114,3 lp) | 2,625 | 300 px | 128x128 | 0,43× |
| 128x128 | 512 (~195 lp) | 2,625 | 512 px | 128x128 | 0,25× |
| 128x128 | 336 (~128 lp) | 2,625 | 336 px | 128x128 | 0,38× |
| 128x128 | 898 (~342,1 lp) | 2,625 | 898 px | 128x128 | 0,14× |
| 1400x1400 | 64 (~24,4 lp) | 2,625 | 64 px | 70x70 | 1,09× |
| 1400x1400 | 96 (~36,6 lp) | 2,625 | 96 px | 100x100 | 1,04× |
| 1400x1400 | 126 (~48 lp) | 2,625 | 126 px | 140x140 | 1,11× |
| 1400x1400 | 144 (~54,9 lp) | 2,625 | 144 px | 175x175 | 1,22× |
| 1400x1400 | 250 (~95,2 lp) | 2,625 | 250 px | 350x350 | 1,40× |
| 1400x1400 | 300 (~114,3 lp) | 2,625 | 300 px | 350x350 | 1,17× |
| 1400x1400 | 512 (~195 lp) | 2,625 | 512 px | 700x700 | 1,37× |
| 1400x1400 | 336 (~128 lp) | 2,625 | 336 px | 350x350 | 1,04× |
| 1400x1400 | 898 (~342,1 lp) | 2,625 | 898 px | 700x700 | 0,78× |
| 200x200 | 64 (~24,4 lp) | 2,625 | 64 px | 66x66 | 1,03× |
| 200x200 | 96 (~36,6 lp) | 2,625 | 96 px | 100x100 | 1,04× |
| 200x200 | 126 (~48 lp) | 2,625 | 126 px | 200x200 | 1,59× |
| 200x200 | 144 (~54,9 lp) | 2,625 | 144 px | 200x200 | 1,39× |
| 200x200 | 250 (~95,2 lp) | 2,625 | 250 px | 200x200 | 0,80× |
| 200x200 | 300 (~114,3 lp) | 2,625 | 300 px | 200x200 | 0,67× |
| 200x200 | 512 (~195 lp) | 2,625 | 512 px | 200x200 | 0,39× |
| 200x200 | 336 (~128 lp) | 2,625 | 336 px | 200x200 | 0,60× |
| 200x200 | 898 (~342,1 lp) | 2,625 | 898 px | 200x200 | 0,22× |
| 3000x3000 | 64 (~24,4 lp) | 2,625 | 64 px | 66x66 | 1,03× |
| 3000x3000 | 96 (~36,6 lp) | 2,625 | 96 px | 100x100 | 1,04× |
| 3000x3000 | 126 (~48 lp) | 2,625 | 126 px | 150x150 | 1,19× |
| 3000x3000 | 144 (~54,9 lp) | 2,625 | 144 px | 150x150 | 1,04× |
| 3000x3000 | 250 (~95,2 lp) | 2,625 | 250 px | 300x300 | 1,20× |
| 3000x3000 | 300 (~114,3 lp) | 2,625 | 300 px | 300x300 | 1,00× |
| 3000x3000 | 512 (~195 lp) | 2,625 | 512 px | 600x600 | 1,17× |
| 3000x3000 | 336 (~128 lp) | 2,625 | 336 px | 600x600 | 1,79× |
| 3000x3000 | 898 (~342,1 lp) | 2,625 | 898 px | 600x600 | 0,67× |
| 300x300 | 64 (~24,4 lp) | 2,625 | 64 px | 75x75 | 1,17× |
| 300x300 | 96 (~36,6 lp) | 2,625 | 96 px | 100x100 | 1,04× |
| 300x300 | 126 (~48 lp) | 2,625 | 126 px | 150x150 | 1,19× |
| 300x300 | 144 (~54,9 lp) | 2,625 | 144 px | 150x150 | 1,04× |
| 300x300 | 250 (~95,2 lp) | 2,625 | 250 px | 300x300 | 1,20× |
| 300x300 | 300 (~114,3 lp) | 2,625 | 300 px | 300x300 | 1,00× |
| 300x300 | 512 (~195 lp) | 2,625 | 512 px | 300x300 | 0,59× |
| 300x300 | 336 (~128 lp) | 2,625 | 336 px | 300x300 | 0,89× |
| 300x300 | 898 (~342,1 lp) | 2,625 | 898 px | 300x300 | 0,33× |
| 500x500 | 64 (~24,4 lp) | 2,625 | 64 px | 71x71 | 1,11× |
| 500x500 | 96 (~36,6 lp) | 2,625 | 96 px | 100x100 | 1,04× |
| 500x500 | 126 (~48 lp) | 2,625 | 126 px | 166x166 | 1,32× |
| 500x500 | 144 (~54,9 lp) | 2,625 | 144 px | 166x166 | 1,15× |
| 500x500 | 250 (~95,2 lp) | 2,625 | 250 px | 250x250 | 1,00× |
| 500x500 | 300 (~114,3 lp) | 2,625 | 300 px | 500x500 | 1,67× |
| 500x500 | 512 (~195 lp) | 2,625 | 512 px | 500x500 | 0,98× |
| 500x500 | 336 (~128 lp) | 2,625 | 336 px | 500x500 | 1,49× |
| 500x500 | 898 (~342,1 lp) | 2,625 | 898 px | 500x500 | 0,56× |
| 64x64 | 64 (~24,4 lp) | 2,625 | 64 px | 64x64 | 1,00× |
| 64x64 | 96 (~36,6 lp) | 2,625 | 96 px | 64x64 | 0,67× |
| 64x64 | 126 (~48 lp) | 2,625 | 126 px | 64x64 | 0,51× |
| 64x64 | 144 (~54,9 lp) | 2,625 | 144 px | 64x64 | 0,44× |
| 64x64 | 250 (~95,2 lp) | 2,625 | 250 px | 64x64 | 0,26× |
| 64x64 | 300 (~114,3 lp) | 2,625 | 300 px | 64x64 | 0,21× |
| 64x64 | 512 (~195 lp) | 2,625 | 512 px | 64x64 | 0,13× |
| 64x64 | 336 (~128 lp) | 2,625 | 336 px | 64x64 | 0,19× |
| 64x64 | 898 (~342,1 lp) | 2,625 | 898 px | 64x64 | 0,07× |
| sin arte | 64 (~24,4 lp) | 2,625 | 64 px | no disponible (null) | no disponible |
| sin arte | 96 (~36,6 lp) | 2,625 | 96 px | no disponible (null) | no disponible |
| sin arte | 126 (~48 lp) | 2,625 | 126 px | no disponible (null) | no disponible |
| sin arte | 144 (~54,9 lp) | 2,625 | 144 px | no disponible (null) | no disponible |
| sin arte | 250 (~95,2 lp) | 2,625 | 250 px | no disponible (null) | no disponible |
| sin arte | 300 (~114,3 lp) | 2,625 | 300 px | no disponible (null) | no disponible |
| sin arte | 512 (~195 lp) | 2,625 | 512 px | no disponible (null) | no disponible |
| sin arte | 336 (~128 lp) | 2,625 | 336 px | no disponible (null) | no disponible |
| sin arte | 898 (~342,1 lp) | 2,625 | 898 px | no disponible (null) | no disponible |

Observación directa sobre las dimensiones recibidas (no es una regla verificada en el código del proveedor): para cada fuente, los valores recibidos coinciden con la fuente dividida por un entero (1000 → 66, 100, 142, 166, 250, 333, 500, 1000; 1400 → 70, 100, 140, 175, 350, 700; 3000 → 66, 100, 150, 300, 600). No se leyó el código de MediaProvider, así que el mecanismo no está confirmado.

## 5. Comparación MemoryImage vs ResizeImage

### 5.1 Datos observados

`MemoryImage` = decodificación a tamaño intrínseco. `ResizeImage` con solo `width` (la altura se deriva de la relación de aspecto). Dimensiones de la imagen decodificada.

| Álbum / caso | Solicitado (px) | Recibido intrínseco | MemoryImage | ResizeImage(width: solicitado) | ResizeImage(allowUpscaling: true) |
|---|---:|---:|---:|---:|---:|
| 1000x1000 | 64 | 66x66 | 66x66 | 64x64 | 64x64 |
| 1000x1000 | 96 | 100x100 | 100x100 | 96x96 | 96x96 |
| 1000x1000 | 126 | 142x142 | 142x142 | 126x126 | 126x126 |
| 1000x1000 | 144 | 166x166 | 166x166 | 144x144 | 144x144 |
| 1000x1000 | 250 | 250x250 | 250x250 | 250x250 | 250x250 |
| 1000x1000 | 300 | 333x333 | 333x333 | 300x300 | 300x300 |
| 1000x1000 | 512 | 1000x1000 | 1000x1000 | 512x512 | 512x512 |
| 1000x1000 | 336 | 500x500 | 500x500 | 336x336 | 336x336 |
| 1000x1000 | 898 | 1000x1000 | 1000x1000 | 898x898 | 898x898 |
| 1000x600 | 64 | 66x40 | 66x40 | 64x38 | 64x38 |
| 1000x600 | 96 | 100x60 | 100x60 | 96x57 | 96x57 |
| 1000x600 | 126 | 142x85 | 142x85 | 126x75 | 126x75 |
| 1000x600 | 144 | 166x100 | 166x100 | 144x86 | 144x86 |
| 1000x600 | 250 | 250x150 | 250x150 | 250x150 | 250x150 |
| 1000x600 | 300 | 333x200 | 333x200 | 300x180 | 300x180 |
| 1000x600 | 512 | 1000x600 | 1000x600 | 512x307 | 512x307 |
| 1000x600 | 336 | 500x300 | 500x300 | 336x201 | 336x201 |
| 1000x600 | 898 | 1000x600 | 1000x600 | 898x538 | 898x538 |
| 128x128 | 64 | 64x64 | 64x64 | 64x64 | 64x64 |
| 128x128 | 96 | 128x128 | 128x128 | 96x96 | 96x96 |
| 128x128 | 126 | 128x128 | 128x128 | 126x126 | 126x126 |
| 128x128 | 144 | 128x128 | 128x128 | 128x128 | 144x144 |
| 128x128 | 250 | 128x128 | 128x128 | 128x128 | 250x250 |
| 128x128 | 300 | 128x128 | 128x128 | 128x128 | 300x300 |
| 128x128 | 512 | 128x128 | 128x128 | 128x128 | 512x512 |
| 128x128 | 336 | 128x128 | 128x128 | 128x128 | 336x336 |
| 128x128 | 898 | 128x128 | 128x128 | 128x128 | 898x898 |
| 1400x1400 | 64 | 70x70 | 70x70 | 64x64 | 64x64 |
| 1400x1400 | 96 | 100x100 | 100x100 | 96x96 | 96x96 |
| 1400x1400 | 126 | 140x140 | 140x140 | 126x126 | 126x126 |
| 1400x1400 | 144 | 175x175 | 175x175 | 144x144 | 144x144 |
| 1400x1400 | 250 | 350x350 | 350x350 | 250x250 | 250x250 |
| 1400x1400 | 300 | 350x350 | 350x350 | 300x300 | 300x300 |
| 1400x1400 | 512 | 700x700 | 700x700 | 512x512 | 512x512 |
| 1400x1400 | 336 | 350x350 | 350x350 | 336x336 | 336x336 |
| 1400x1400 | 898 | 700x700 | 700x700 | 700x700 | 898x898 |
| 200x200 | 64 | 66x66 | 66x66 | 64x64 | 64x64 |
| 200x200 | 96 | 100x100 | 100x100 | 96x96 | 96x96 |
| 200x200 | 126 | 200x200 | 200x200 | 126x126 | 126x126 |
| 200x200 | 144 | 200x200 | 200x200 | 144x144 | 144x144 |
| 200x200 | 250 | 200x200 | 200x200 | 200x200 | 250x250 |
| 200x200 | 300 | 200x200 | 200x200 | 200x200 | 300x300 |
| 200x200 | 512 | 200x200 | 200x200 | 200x200 | 512x512 |
| 200x200 | 336 | 200x200 | 200x200 | 200x200 | 336x336 |
| 200x200 | 898 | 200x200 | 200x200 | 200x200 | 898x898 |
| 3000x3000 | 64 | 66x66 | 66x66 | 64x64 | 64x64 |
| 3000x3000 | 96 | 100x100 | 100x100 | 96x96 | 96x96 |
| 3000x3000 | 126 | 150x150 | 150x150 | 126x126 | 126x126 |
| 3000x3000 | 144 | 150x150 | 150x150 | 144x144 | 144x144 |
| 3000x3000 | 250 | 300x300 | 300x300 | 250x250 | 250x250 |
| 3000x3000 | 300 | 300x300 | 300x300 | 300x300 | 300x300 |
| 3000x3000 | 512 | 600x600 | 600x600 | 512x512 | 512x512 |
| 3000x3000 | 336 | 600x600 | 600x600 | 336x336 | 336x336 |
| 3000x3000 | 898 | 600x600 | 600x600 | 600x600 | 898x898 |
| 300x300 | 64 | 75x75 | 75x75 | 64x64 | 64x64 |
| 300x300 | 96 | 100x100 | 100x100 | 96x96 | 96x96 |
| 300x300 | 126 | 150x150 | 150x150 | 126x126 | 126x126 |
| 300x300 | 144 | 150x150 | 150x150 | 144x144 | 144x144 |
| 300x300 | 250 | 300x300 | 300x300 | 250x250 | 250x250 |
| 300x300 | 300 | 300x300 | 300x300 | 300x300 | 300x300 |
| 300x300 | 512 | 300x300 | 300x300 | 300x300 | 512x512 |
| 300x300 | 336 | 300x300 | 300x300 | 300x300 | 336x336 |
| 300x300 | 898 | 300x300 | 300x300 | 300x300 | 898x898 |
| 500x500 | 64 | 71x71 | 71x71 | 64x64 | 64x64 |
| 500x500 | 96 | 100x100 | 100x100 | 96x96 | 96x96 |
| 500x500 | 126 | 166x166 | 166x166 | 126x126 | 126x126 |
| 500x500 | 144 | 166x166 | 166x166 | 144x144 | 144x144 |
| 500x500 | 250 | 250x250 | 250x250 | 250x250 | 250x250 |
| 500x500 | 300 | 500x500 | 500x500 | 300x300 | 300x300 |
| 500x500 | 512 | 500x500 | 500x500 | 500x500 | 512x512 |
| 500x500 | 336 | 500x500 | 500x500 | 336x336 | 336x336 |
| 500x500 | 898 | 500x500 | 500x500 | 500x500 | 898x898 |
| 64x64 | 64 | 64x64 | 64x64 | 64x64 | 64x64 |
| 64x64 | 96 | 64x64 | 64x64 | 64x64 | 96x96 |
| 64x64 | 126 | 64x64 | 64x64 | 64x64 | 126x126 |
| 64x64 | 144 | 64x64 | 64x64 | 64x64 | 144x144 |
| 64x64 | 250 | 64x64 | 64x64 | 64x64 | 250x250 |
| 64x64 | 300 | 64x64 | 64x64 | 64x64 | 300x300 |
| 64x64 | 512 | 64x64 | 64x64 | 64x64 | 512x512 |
| 64x64 | 336 | 64x64 | 64x64 | 64x64 | 336x336 |
| 64x64 | 898 | 64x64 | 64x64 | 64x64 | 898x898 |

Hechos observados en la tabla:

- `MemoryImage` decodifica **siempre** al tamaño intrínseco de los bytes recibidos (81 filas con carátula, sin excepción).
- `ResizeImage(width: size)` (por defecto `allowUpscaling: false`): si intrínseco > solicitado, decodifica a `width = solicitado`; si intrínseco ≤ solicitado, decodifica al intrínseco. **Nunca amplió** en las 81 filas.
- `ResizeImage(width: size, allowUpscaling: true)` **sí amplía** hasta el ancho solicitado (p. ej. 64×64 → 898×898, 200×200 → 898×898).
- En 1000×600 la relación de aspecto se conserva (p. ej. 64 px → 64×38; 898 px → 898×538).
- Píxeles decodificados en casos concretos (ancho×alto de la tabla): 1000×1000 a 512 → `MemoryImage` 1 000 000 px frente a `ResizeImage` 262 144 px (3,81×); 1400 a 250 → 350×350 = 122 500 px frente a 250×250 = 62 500 px (1,96×).
- Con `ResizeImage` por defecto, cuando `MediaStore` ya devuelve ≤ solicitado el resultado es idéntico a `MemoryImage` (p. ej. 1000×1000 a 250, 300×300 a 300).

### 5.2 Interpretación (separada de los datos)

- El ahorro de `ResizeImage` depende de cuánto más grande que lo pedido devuelva MediaStore. En esta medición el exceso en ancho fue de hasta +95 %; los mayores excesos se dieron con pedidos de 300 a 512 px sobre fuentes de 500–3000 px.
- Como `ResizeImage` por defecto no amplía, no introduce el efecto de «ampliar una imagen pequeña» que sí tiene `AlbumArtworkImage` (Fase 1.8J). `allowUpscaling: true` sí lo reproduciría.
- Esta comparación mide **dimensiones decodificadas**; no mide memoria. Cualquier cifra de memoria sería una inferencia a partir de píxeles, y aquí no se da.

## 6. Casos relevantes

Umbrales usados (elegidos aquí, arbitrarios): «ligeramente mayor» = cociente > 1,00 y ≤ 1,25; «mucho mayor» = cociente > 1,25.

- **Exactamente lo solicitado (1,00×)**: 1000² y 500² a 250; 300² a 300; 3000² a 300; 64² a 64; 128² a 64; 1000×600 a 250 (ancho).
- **Ligeramente mayor**: 1000² a 64/96/126/144/300/898 (1,03–1,15×); 1400² a 96/126/144/300/336 (1,04–1,22×); 3000² a 96/144/250/512 (1,04–1,20×).
- **Mucho mayor**: 1000² a 512 (**1,95×**); 3000² a 336 (1,79×); 500² a 300 (1,67×); 200² a 126 (1,59×); 1000² a 336 (1,49×); 500² a 336 (1,49×); 1400² a 250 (1,40×); 200² a 144 (1,39×); 1400² a 512 (1,37×); 128² a 96 (1,33×); 500² a 126 (1,32×).
- **Menor que lo solicitado**:
  - Limitado por la fuente (recibido = fuente; MediaStore no pudo dar más): 64² a >64; 128² a 144+; 200² a 250+; 300² a 512/898; 500² a 512 (0,98×) y 898 (0,56×).
  - **Con fuente mayor que lo pedido**: 1400² a 898 → **700** (0,78×); 3000² a 898 → **600** (0,67×). Aquí MediaStore devolvió menos que lo pedido aunque la fuente era más grande. Es el tamaño del hero de Now Playing; el pedido de 898 px solo se satisfizo con la fuente de 1000 px (1000, 1,11×).
- **Variable**: el mismo pedido da cocientes distintos según la fuente. A 512 px: 1000² → 1,95×; 1400² → 1,37×; 3000² → 1,17×; 500² → 0,98×; 300² → 0,59×. A 64 px se recibieron 66, 70, 66, 71, 75, 66 y 64 px según la fuente (1000, 1400, 3000, 500, 300, 200 y 64 respectivamente, más 64 para 128).
- **Sin carátula**: los 9 pedidos devolvieron `null` (esperado; hoy `ArtworkCache` cachea ese `null`).
- **Bytes idénticos entre tamaños**: p. ej. 1000² a 512 y a 898 devolvieron el mismo JPEG (105 314 bytes, 1000×1000); 1400² a 250/300/336 → mismos 350×350. Hoy `ArtworkCache` guarda entradas separadas por tamaño.

## 7. Limitaciones

- **Un solo dispositivo y emulador**, no hardware físico; un MediaProvider, una versión (Android 15, API 35).
- **Android 7–9 no medido.** La rama legacy sigue siendo solo análisis de código; Android 10–14 tampoco se midió.
- **Fuentes sintéticas**: JPEG generadas con `System.Drawing`, no carátulas reales de álbumes. La fuente es cuadrada salvo un caso de 1000×600; no se probó PNG, carátulas en archivo (`folder.jpg`) ni fuentes mayores de 3000 px.
- Una única petición por combinación; no se comprobó que el resultado sea determinista entre ejecuciones.
- El DPR de la app no se pudo leer en ejecución (ver sección 2); se usó el del sistema.
- `ResizeImage` se midió solo con `width`; no se probó `height` ni ambos, ni su coste de CPU o tiempo de decodificación.
- No se midió memoria, rendimiento, efecto en `ImageCache` ni nitidez visual.
- La medición usó el punto de entrada temporal, no la UI de Taki: no se observó el `Image` dentro de `TakiArtwork`.

## 8. Evidencia para la decisión B1/C

Esta sección aporta evidencia y **no elige B1 ni C**.

Lo que los datos **respaldan**:

- En Android 15 (emulador), MediaStore entregó el tamaño exacto pedido solo en casos puntuales; el exceso observado llegó a 1,95× en ancho (3,8× en píxeles).
- `ResizeImage` por defecto redujo la decodificación al tamaño pedido cuando había exceso y no amplió nunca, en las 81 filas con carátula.
- Con exceso grande (512 px sobre fuentes de 1000–3000 px), `MemoryImage` decodifica bastante más píxeles que `ResizeImage`.
- Para pedidos de 64–144 px el exceso fue pequeño con fuentes ≥ 500 px (1,03–1,32×); los mayores cocientes en ese rango aparecieron con fuentes pequeñas (p. ej. 1,59× para 200 px a 126).

Lo que los datos **no respaldan / no cubren**:

- Nada sobre Android 7–9 ni sobre otros OEM; el caso legacy (entre 1× y 2× el tamaño pedido según el código) no está medido.
- Nada sobre memoria real ni sobre fluidez.
- Con fuentes reales y otro MediaProvider la distribución de excesos puede diferir.
- El pedido de 898 px (hero) devolvió **menos** de lo pedido con fuentes de 1400 y 3000 px; eso afecta a la nitidez en cualquier opción y no depende de `ResizeImage`.

Decisión pendiente para una fase posterior; conviene decidir si se exige medición en Android 7–9 / hardware real antes de elegir.
