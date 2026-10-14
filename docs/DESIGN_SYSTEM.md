# Taki Design System — "Midnight + Taki Orange"

> **Estado:** especificación (Fase 1). Nada de este documento está implementado
> todavía salvo donde se indica "actual". La implementación seguirá la
> [estrategia de migración](#22-estrategia-de-migración), paso a paso.
>
> Documentos relacionados: [ARCHITECTURE.md](ARCHITECTURE.md) (dónde vive cada
> pieza de código).

Taki es hoy un reproductor de música para Android (biblioteca local y, con
credencial, catálogo remoto de Jamendo), en español y en modo oscuro. Este
sistema define su lenguaje visual para lo que existe hoy (Biblioteca, Buscar,
Favoritos, Playlists, Reproduciendo, Cola) y para lo que podría existir más
adelante (artistas, álbumes, géneros, discovery, más fuentes) sin tener que
inventar otro lenguaje.

---

## Índice

- [0. Punto de partida](#0-punto-de-partida)
- [Principios](#principios)
- [1. Color](#1-color)
- [2. Tipografía](#2-tipografía)
- [3. Espaciado](#3-espaciado)
- [4. Formas y radios](#4-formas-y-radios)
- [5. Superficies y elevación](#5-superficies-y-elevación)
- [6. Iconografía](#6-iconografía)
- [7. Artwork](#7-artwork)
- [8. TakiSongTile](#8-takisongtile)
- [9. Botones](#9-botones)
- [9b. TakiSearchField](#9b-takisearchfield)
- [10. TakiMiniPlayer](#10-takiminiplayer)
- [11. Reproduciendo](#11-reproduciendo)
- [12. TakiPlaylistCard](#12-takiplaylistcard)
- [13. TakiSectionHeader](#13-takisectionheader)
- [14. TakiEmptyState](#14-takiemptystate)
- [15. TakiErrorState](#15-takierrorstate)
- [16. Navegación inferior](#16-navegación-inferior)
- [17. Estados de interacción](#17-estados-de-interacción)
- [18. Movimiento](#18-movimiento)
- [19. Accesibilidad](#19-accesibilidad)
- [20. Do / Don't](#20-do--dont)
- [21. Inventario de componentes](#21-inventario-de-componentes)
- [22. Estrategia de migración](#22-estrategia-de-migración)

---

## 0. Punto de partida

### Lo que existe hoy

Inventario de partida, **anterior a la migración**. `SongTile`,
`PlayShuffleButtons`, `MessageView` y `PlayingBars` se sustituyeron por
`TakiSongTile`, `TakiButton`, `TakiEmptyState` / `TakiErrorState` y
`TakiPlayingIndicator`, y se eliminaron en la Fase 1.7E. `ArtworkImage` y
`PlaylistCover` se sustituyeron por `TakiArtwork` y `AlbumArtworkBuilder`
(`core/artwork/`) y se eliminaron en las Fases 1.8A–1.8M.

| Pieza | Dónde | Qué hace |
|---|---|---|
| `AppColors` · *eliminado en 1.9B* | `lib/core/theme/app_colors.dart` | *(Valores de entonces, sustituidos por `TakiColors`, §1.)* Paleta "Medianoche + ámbar": fondo `#111318`, surface `#1B1E26`, surfaceElevated `#1F232D`, border `#2A2E39`, texto `#F2F0EB` / `#A3A6B0`, acento ámbar `#F5A524` |
| `AppTheme` | `lib/app/theme/app_theme.dart` | `ThemeData` Material 3 oscuro; Sora (display/headline/title) y DM Sans (resto), empaquetadas como fuentes de la app (`fonts:` en `pubspec.yaml`, Fase 1.2); tamaño táctil mínimo 48 |
| `ArtworkImage` · *eliminado en 1.8* | `lib/core/widgets/` | Carátula cuadrada con radio, caché LRU, placeholder con nota musical |
| `SongTile` · *eliminado en 1.7E* | `lib/core/widgets/` | Fila de 64 px: carátula 48, título, artista, duración |
| `PlayShuffleButtons` · *eliminado en 1.7E* | `lib/core/widgets/` | Botones "Reproducir" (acento) y "Aleatorio" (surface + borde), en píldora de 48 |
| `MessageView` · *eliminado en 1.7E* | `lib/core/widgets/` | Estado vacío / error / permiso: icono 56 en acento, título, texto, botón |
| `MiniPlayer` | `features/player/.../widgets/` | Tarjeta de 64 px sobre la barra inferior, radio 16, barra de progreso de 3 px |
| `NowPlayingPage` | `features/player/.../pages/` | Carátula grande (radio 24, sombra), título 24, controles, seek, botón "Cola" |
| `PlayingBars` · *eliminado en 1.7E* | `features/player/.../widgets/` | Ecualizador de 3 barras que marca la canción que suena en la Cola |
| `PlaylistCover` · *eliminado en 1.8* | `features/playlists/.../widgets/` | Portada 2×2 o carátula única; icono de lista si está vacía |

El ícono de la app (`android/app/src/main/res/mipmap-*`) usa un fondo
medianoche violáceo (`#111139`) y un degradado que va de naranja (`#FBA356`,
`#FC8F53`) a coral (`#FC514C`), rosa (`#FC0A93`) y violeta (`#B116DC` a
`#9B11E6`). El
naranja de este sistema sale del extremo cálido de ese degradado.

### Qué se reutiliza

- **Tipografías:** Sora + DM Sans. Cumplen el objetivo (Sora es geométrica y
  con carácter para títulos; DM Sans es muy legible en tamaños pequeños). No
  se añade ninguna fuente.
- **Estructura de tokens:** los tokens en `core/theme` (hoy `TakiColors` y el resto de
  tokens Taki; antes `AppColors`, eliminado en la Fase 1.9B) y `AppTheme` en
  `app/theme` ya siguen la separación tokens / composición del tema.
- **Componentes:** `ArtworkImage`, `SongTile`, `PlayShuffleButtons`,
  `MessageView`, `MiniPlayer`, `PlayingBars` y `PlaylistCover` son la base de
  los componentes `Taki*` del [inventario](#21-inventario-de-componentes)
  (`SongTile`, `PlayShuffleButtons`, `MessageView` y `PlayingBars` ya se
  eliminaron, en la Fase 1.7E; `ArtworkImage` y `PlaylistCover`, en las
  Fases 1.8A–1.8M).
- **Decisiones que ya son correctas:** tamaño táctil de 48, tooltips en todos
  los botones de icono, `Semantics(toggled:)` en aleatorio, cifras tabulares
  en duraciones, iconos de la familia *rounded*, transición de pantalla
  completa de 320/260 ms con `easeOutCubic` / `easeInCubic`.

### Inconsistencias detectadas

| # | Severidad | Inconsistencia | Evidencia |
|---|---|---|---|
| I1 | Alta · **Resuelta en Fase 1.2** | **Las fuentes no llegaban a la build de release.** `google_fonts` las descargaba en tiempo de ejecución, no estaban incluidas como assets y el `AndroidManifest.xml` principal no declara `INTERNET` (solo los de debug y profile). En release la app usaba la fuente de respaldo del sistema. Ahora van empaquetadas (ver §2.1) y `google_fonts` se retiró | `pubspec.yaml` (`fonts:`), `assets/fonts/` |
| I2 | Media · **Resuelta en 1.7A–1.7C-2** | La canción que suena se marca **solo con color** (título en acento) en Biblioteca, Favoritos y el detalle de playlist. La Cola sí añade `PlayingBars` | `core/widgets/song_tile.dart` (eliminado en 1.7E) |
| I3 | Media | Aleatorio y "repetir todo" activos se distinguen **solo por color** (acento vs gris); "repetir una" sí cambia de icono | `now_playing_page.dart` (`toggleColor`) |
| I4 | Media | Seis radios distintos para elementos parecidos: 10, 12, 14, 16, 24 y píldora | `artwork_image` (eliminado en 1.8), `queue_page`, `mini_player`, `app_theme`, `now_playing_page` |
| I5 | Media | Tamaños de fuente fijados a mano con `copyWith(fontSize:)` (11, 12, 13, 14, 15, 20, 24, 26) en lugar de roles con nombre. El mismo rol cambia entre pantallas: título de canción 15 en listas y 14 en el mini player; "eyebrow" 11/1.5 en Reproduciendo y 12/1.2 en Playlists y Cola | varias páginas |
| I6 | Media · **Resuelta en 1.7A–1.7C-2** | `MessageView` pinta igual el vacío, el error y el permiso (icono siempre en acento): un error no se distingue de "aún no tienes favoritos" | `core/widgets/message_view.dart` (eliminado en 1.7E) |
| I7 | Baja | Márgenes laterales mezclados: 16 (listas), 20 (Cola, sheets), 24 (Reproduciendo), 32 (estados vacíos) | páginas |
| I8 | Baja | Alturas de fila 64 y 68, y carátulas de 44, 48, 52 y 128 para funciones muy parecidas | `song_tile`, `playlists_page`, `queue_page`, `mini_player`, `playlist_cover` (eliminado en 1.8) |
| I9 | Baja | El botón de reproducir es un círculo **blanco** en el mini player y **ámbar** en Reproduciendo, sin una regla documentada | `mini_player.dart`, `now_playing_page.dart` |
| I10 | Baja | `surface` y `surfaceElevated` casi no se distinguen (contraste entre ellos 1.06:1) | `app_colors.dart` (eliminado en 1.9B) |
| I11 | Baja | No hay colores semánticos de error, éxito o aviso; el error sale del `ColorScheme.fromSeed` por defecto. Tampoco hay tema de SnackBar (se usa el claro por defecto de Material 3) | `app_theme.dart` |
| I12 | Baja · **Parcialmente resuelta en 1.9B** | Tokens sin uso: `accentCoral`, `accentBlue`, `accentMint` (se eliminaron con `AppColors` en 1.9B) y el parámetro `accent` de `AppTheme.dark()` (sigue pendiente) | `app_colors.dart` (eliminado), `app_theme.dart` |
| I13 | Baja · **Resuelta en 1.7A** | `SongTile` tiene alto fijo (64) y la Biblioteca usa `SliverFixedExtentList`: con texto grande (200 %) el contenido puede no caber | `library_page.dart`, `song_tile.dart` (eliminado en 1.7E) |
| I14 | Baja | Reproduciendo muestra "REPRODUCIENDO DESDE Biblioteca" siempre, y su botón "Más opciones" no hace nada | `now_playing_page.dart:317, 332` |
| I15 | Baja | Mezcla de variantes de icono fuera de la navegación (`music_off_outlined`, `delete_outline_rounded`, `lock_outline_rounded` junto a `*_rounded` rellenos) | páginas |

Este documento **no corrige** ninguna: define el sistema al que se migrará.

---

## Principios

1. **Music first.** La carátula y el nombre de la canción son lo más
   importante de cada pantalla. La interfaz se aparta: fondos oscuros y
   neutros, pocos bordes, sin decoración que compita con el artwork.
2. **Jerarquía visual clara.** En un vistazo se distingue:
   - *qué suena* → naranja + indicador animado + texto accesible;
   - *qué se puede reproducir* → filas y tarjetas con carátula, pulsables
     enteras;
   - *qué está seleccionado* → contenedor naranja tenue + marca de
     verificación;
   - *qué acciones hay* → un solo botón primario por pantalla y el resto
     secundarios o de icono.
3. **Interfaz tranquila.** Superficies por luminosidad, no por bordes. Un solo
   color de acento. Espacio en blanco en lugar de separadores.
4. **Artwork fuerte.** Donde la canción es protagonista (Reproduciendo,
   cabeceras de playlist, futuras páginas de álbum), la carátula ocupa el
   espacio que merece. En las listas es pequeña pero siempre está.
5. **Consistencia.** Un concepto se ve igual en todas partes: una canción es
   siempre un `TakiSongTile`, reproducir es siempre el mismo botón, "está
   sonando" se marca siempre igual. Vale para Biblioteca, Playlists, el
   reproductor y cualquier área online futura.
6. **Táctil.** Toda zona pulsable mide al menos 48×48. Las acciones
   frecuentes (reproducir, pausa, siguiente) son las más grandes.
7. **Dark-first.** Pensado para escuchar de noche y durante horas: fondo muy
   oscuro pero no negro puro, texto blanco cálido (no `#FFFFFF`) y acento
   saturado solo en puntos concretos.
8. **Future-ready.** Los componentes describen *conceptos* (canción,
   colección, sección, estado), no pantallas concretas. Un álbum, un artista
   o una playlist online reutilizan `TakiArtwork`, `TakiPlaylistCard`,
   `TakiSectionHeader` y los estados vacíos y de error.

**Lo que hace a Taki distinto** (y no una copia de Spotify, Deezer o Apple
Music): fondo *midnight* azulado en lugar de negro o gris neutro, acento
naranja cálido derivado del ícono, títulos en Sora geométrica, reproductor
sin fondos teñidos por la carátula a pantalla completa (ver
[§11](#11-reproduciendo)) e indicador "sonando" propio (`TakiPlayingIndicator`).

---

## 1. Color

### 1.1 Reglas generales

- La paleta es **pequeña**: 4 niveles de superficie (más el scrim), 3 de
  texto, 1 acento (con 4 tokens derivados: `onPrimary`, `primaryPressed`,
  `primaryContainer`, `onPrimaryContainer`), 3 colores de estado (más
  `errorContainer`), 2 líneas y 1 degradado de marca.
- **El naranja es identidad y foco, no decoración.** Solo se usa para:
  la acción principal de una pantalla, lo que está sonando, lo que está
  activo o seleccionado, y el foco del teclado. Nunca para fondos grandes,
  texto largo, iconos decorativos ni bordes.
- Todo color se usa por **token semántico** (`TakiColors.textSecondary`),
  nunca por HEX en un widget.
- Los contrastes de esta sección están **medidos** (WCAG 2.1, fórmula de
  luminancia relativa).

### 1.2 Superficies (midnight)

Escalón de luminosidad uniforme entre niveles (≈1.1:1), frente al 1.06:1
actual entre `surface` y `surfaceElevated` (I10).

| Nombre | Token | HEX | Propósito | Dónde sí | Dónde no |
|---|---|---|---|---|---|
| Background | `background` | `#0E1016` | Nivel 0: fondo de toda la app | Scaffold, listas, Reproduciendo, Cola | Dentro de tarjetas o sheets (se perdería la capa) |
| Surface | `surface` | `#161920` | Nivel 1: zonas agrupadas integradas | Barra de navegación, cabecera de playlist, contenedores de grupo, placeholder de artwork | Como fondo de pantalla |
| Surface Elevated | `surfaceElevated` | `#1E222B` | Nivel 2: elementos que flotan | Mini player, bottom sheets, menús, diálogos, SnackBars | Filas de lista normales |
| Surface Highest | `surfaceHighest` | `#272B36` | Superficie anidada sobre un nivel 2 (no es un nivel de elevación propio, ver §5) | Campos de texto dentro de un sheet, chips, tooltips | Fondos amplios |
| Scrim | `scrim` | `#000000` al 60 % | Oscurecer detrás de un modal | Detrás de sheets y diálogos | Como color de superficie |

### 1.3 Texto e iconos

| Nombre | Token | HEX | Contraste sobre N0 / N1 / N2 / N3 | Dónde sí | Dónde no |
|---|---|---|---|---|---|
| Text Primary | `textPrimary` | `#F2F0EB` | 16.7 / 15.4 / 14.0 / 12.4 | Títulos, nombres de canción, texto de botones secundarios | Texto largo de ayuda (cansa en oscuro); usar `textSecondary` |
| Text Secondary | `textSecondary` | `#A3A6B0` | 7.8 / 7.2 / 6.6 / 5.8 | Artista, descripciones, metadata importante, etiquetas inactivas | Títulos |
| Text Muted | `textMuted` | `#858A98` | 5.5 / 5.1 / 4.6 / **4.1** | Metadata de baja prioridad (duración, contadores, "eyebrows") | Sobre nivel 3 (no llega a 4.5:1); información imprescindible |
| Icon Primary | `iconPrimary` | = `textPrimary` | — | Controles de reproducción, iconos de acción principales | — |
| Icon Secondary | `iconSecondary` | = `textSecondary` | — | Iconos de fila (⋯, asa de arrastre), navegación inactiva, toggles apagados | Controles principales del reproductor |
| On Text Primary | `onTextPrimary` | `#0E1016` (= `background`) | 16.7 sobre `textPrimary` | Icono dentro de un círculo `textPrimary` (play del mini player, §10) | Texto sobre superficies oscuras |

`textPrimary` es blanco cálido a propósito: reduce el deslumbramiento frente a
`#FFFFFF` y combina con el naranja.

### 1.4 Acento: Taki Orange

| Nombre | Token | HEX | Propósito | Dónde sí | Dónde no |
|---|---|---|---|---|---|
| Primary | `primary` | `#FF8A3D` | Identidad y foco. 8.1:1 sobre `background` | Botón primario, botón de play de Reproduciendo, título de la canción que suena, toggles activos, progreso, anillo de foco | Fondos grandes, texto corrido, iconos decorativos, bordes, errores |
| On Primary | `onPrimary` | `#0E1016` | Texto e icono sobre naranja. 8.1:1 | Etiqueta del botón primario, icono de play | Sobre cualquier otro color |
| Primary Pressed | `primaryPressed` | `#E97A30` | Pulsado de elementos naranjas (6.6:1 con `onPrimary`) | Botón primario y play mientras se pulsan | Estado por defecto |
| Primary Container | `primaryContainer` | `#3A2517` | Fondo tenue de selección o activo | Indicador de la pestaña activa, fila o tarjeta seleccionada | Botones; fondos de pantalla |
| On Primary Container | `onPrimaryContainer` | `#FFC9A3` | Texto sobre `primaryContainer` (9.7:1) | Etiqueta de un chip seleccionado | Texto normal |

`primary` se toma del extremo naranja del degradado del ícono (`#FC8F53`),
un poco más saturado para que destaque sobre el fondo oscuro.

### 1.4.1 Estados derivados

No son colores nuevos: son tokens con nombre que reutilizan los anteriores.
Su comportamiento completo está en [§17](#17-estados-de-interacción).

| Nombre | Token | Valor | Propósito |
|---|---|---|---|
| Selected | `selected` | `primaryContainer` (`#3A2517`) + marca `check_circle_rounded` en `primary` | Fondo de una fila, tarjeta o chip seleccionado |
| Active | `active` | `primary` (`#FF8A3D`) + variante de icono | Icono o texto de un toggle encendido, pestaña actual, canción que suena |
| Pressed | `pressedOverlay` | `textPrimary` (`#F2F0EB`) al 10 %, encima del componente; sobre naranja, `primaryPressed` | Respuesta al pulsar |
| Focus | `focusRing` | `primary` (`#FF8A3D`), 2 px; `textPrimary` sobre componentes naranjas | Foco de teclado o de accesibilidad |
| Disabled (contenido) | `disabledContent` | `textPrimary` al 38 % | Texto e icono deshabilitados |
| Disabled (contenedor) | `disabledContainer` | `textPrimary` al 12 % | Fondo de un botón deshabilitado |
| Artwork scrim | `artworkScrim` | `background` (`#0E1016`) al 55 % | Velo sobre la carátula de lo que suena, para que el indicador se lea (§8, §12) |

### 1.5 Líneas

| Nombre | Token | HEX | Dónde sí | Dónde no |
|---|---|---|---|---|
| Divider | `divider` | `#23272F` | Separar grupos dentro de una misma superficie cuando el espacio no basta | Entre cada fila de una lista (usar espacio) |
| Outline | `outline` | `#2E3340` | Borde del botón secundario, placeholder de playlist vacía, campos de texto | Como único medio para distinguir un componente (contraste 1.5:1, decorativo) |

### 1.6 Estados

| Nombre | Token | HEX | Contraste sobre N0 | Dónde sí | Dónde no |
|---|---|---|---|---|---|
| Error | `error` | `#FF6B6B` | 6.9:1 | Icono y texto de errores, botón destructivo | Acciones normales; favoritos (el corazón es `primary`) |
| Error Container | `errorContainer` | `#3A1A1C` | — | Fondo del icono en `TakiErrorState` | Fondos de pantalla |
| Success | `success` | `#3DD6B0` | 10.4:1 | Confirmaciones puntuales (p. ej. futura descarga completada) | Estado "sonando" o "activo" (eso es `primary`) |
| Warning | `warning` | `#F2C94C` | 12.0:1 | Avisos no bloqueantes (p. ej. canción no disponible) | Como sustituto del naranja |

`error` y `primary` tienen luminosidad parecida (1.18:1 entre ellos): un error
**siempre** lleva icono y texto, nunca se comunica solo con color.

### 1.7 Degradado de marca

| Token | Valor | Uso |
|---|---|---|
| `brandGradient` | `#FF8A3D` → `#FC0A93` → `#9B11E6` (lineal, 135°) | **Solo** momentos de marca: ícono, splash, onboarding e ilustraciones de estados vacíos de primer uso |

Nunca en botones, texto, barras de progreso ni fondos de pantalla.

### 1.8 Tokens actuales que se retiran (histórico: ya retirados)

`accentCoral`, `accentBlue` y `accentMint` (sin uso, I12) y el ámbar `accent`
`#F5A524`, que sustituye `primary`. `miniProgressTrack`, `seekTrack` y
`artworkShadow` pasan a ser tokens de componente (§10, §11, §7).

**Estado:** `AppColors` se eliminó en la Fase 1.9B; `TakiColors` es la fuente
vigente de los tokens de color. `accentCoral`, `accentBlue`, `accentMint` y el ámbar
desaparecieron con él; `miniProgressTrack` y `seekTrack` eran alias de `divider` y
`artworkShadow` es `TakiElevation.artworkShadow`.

---

## 2. Tipografía

### 2.1 Familias

| Familia | Uso | Por qué |
|---|---|---|
| **Sora** | Display, headline y title | Geométrica y reconocible: da identidad a los títulos sin ser decorativa |
| **DM Sans** | Body, label y caption (incluidos los nombres de canción) | Muy legible en 12–15 px, con cifras tabulares para tiempos |

Ya son las familias actuales. No se añade ninguna fuente nueva.

**Empaquetado (Fase 1.2):** las dos familias van dentro de la app como fuentes
de Flutter (`fonts:` en `pubspec.yaml`), en `assets/fonts/`. Funcionan sin
conexión, en debug y en release; no hay descarga en tiempo de ejecución.

| Familia | Pesos empaquetados | Por qué |
|---|---|---|
| Sora | 400, 500, 600, 700 | 600 y 700: escala de §2.2. 400 y 500: los usa todavía el tema actual (display, headline y titleLarge a 400; titleMedium y titleSmall a 500) |
| DM Sans | 400, 500, 600 | Escala de §2.2 (body, label, trackTitle) |

- Son instancias estáticas (un archivo por peso), las mismas que servía
  `google_fonts`, verificadas por SHA-256.
- Licencia: SIL Open Font License 1.1. `Sora-OFL.txt` y `DMSans-OFL.txt`
  viajan en el APK junto a las fuentes.
- **Regla:** un peso que no esté en la tabla no existe. Si una pantalla pide
  otro (p. ej. 800), Flutter lo simula engrosando el más cercano. Añadir un
  peso exige añadir su archivo y su entrada en `pubspec.yaml`.
- Cuando la migración (§22) retire los usos de Sora 400 y 500, esos dos
  archivos podrán eliminarse.

### 2.2 Escala

Todos los tamaños están en px lógicos y escalan con la preferencia de tamaño
de texto del sistema.

| Rol | Token | Familia | Tamaño / interlínea | Peso | Tracking | Uso |
|---|---|---|---|---|---|---|
| Display | `display` | Sora | 32 / 40 | 700 | −0.5 | Cabecera hero futura (álbum, artista, discovery) |
| Headline | `headline` | Sora | 24 / 32 | 700 | −0.25 | Título de pantalla ("Tu música"), nombre de playlist en su cabecera, título en Reproduciendo |
| Title Large | `titleLarge` | Sora | 20 / 28 | 600 | 0 | Barra superior, títulos de sección de contenido, título de estado vacío/error, título de diálogo |
| Title Medium | `titleMedium` | Sora | 16 / 24 | 600 | 0 | Título de bottom sheet, nombre de tarjeta en cuadrícula |
| Track Title | `trackTitle` | DM Sans | 15 / 20 | 600 | 0 | Nombre de canción o playlist en filas y en el mini player |
| Body Large | `bodyLarge` | DM Sans | 16 / 24 | 400 | 0 | Artista en Reproduciendo, texto destacado |
| Body | `body` | DM Sans | 14 / 20 | 400 | 0 | Descripciones, mensajes de estados vacíos y de error, diálogos |
| Track Subtitle | `trackSubtitle` | DM Sans | 13 / 18 | 400 | 0 | Artista (y álbum) en filas y en el mini player |
| Label | `label` | DM Sans | 14 / 20 | 600 | 0.1 | Texto de botones |
| Label Small | `labelSmall` | DM Sans | 12 / 16 | 500 | 0.2 | Etiquetas de navegación, chips |
| Caption | `caption` | DM Sans | 12 / 16 | 400 | 0, cifras tabulares | Duraciones, tiempos del reproductor, contadores |
| Eyebrow | `eyebrow` | DM Sans | 11 / 16 | 600 | 1.2, MAYÚSCULAS | Etiquetas de grupo ("TUS PLAYLISTS", "REPRODUCIENDO DESDE"). Unifica los dos estilos actuales (I5) |

Es la única escala. Un widget elige un rol; no ajusta `fontSize` a mano.

### 2.3 Dónde se usa cada rol

| Elemento | Rol | Color |
|---|---|---|
| Título de pantalla | `headline` (en la página) o `titleLarge` (en la barra superior) | `textPrimary` |
| Nombre de canción | `trackTitle`; en Reproduciendo, `headline` | `textPrimary`; `primary` si suena |
| Artista | `trackSubtitle`; en Reproduciendo, `bodyLarge` | `textSecondary` |
| Álbum | `trackSubtitle`, detrás del artista con " · " | `textSecondary` |
| Metadata (duración, "12 canciones · 48 min") | `caption` o `trackSubtitle` | `textMuted` / `textSecondary` |
| Botones | `label` | según el botón |
| Navegación inferior | `labelSmall` | activa `textPrimary` (600), inactiva `textSecondary` |
| Reproductor: tiempos | `caption` tabular | `textSecondary` |
| Estados vacíos y de error | título `titleLarge`, texto `body` | `textPrimary` / `textSecondary` |
| Etiqueta de grupo | `eyebrow` | `textMuted` |

**Truncado:** títulos y artistas en filas y en el mini player → 1 línea con
elipsis. Título en Reproduciendo → hasta 2 líneas. Descripciones → sin límite.

---

## 3. Espaciado

Escala de base 4. El análisis de la UI actual encuentra sobre todo 4, 8, 12,
16 y 24; se formalizan esos valores y se descartan los sueltos (6, 10, 18,
22).

| Token | Valor | Uso típico |
|---|---|---|
| `space2xs` | 2 | Solo entre dos líneas de texto acopladas (título ↔ artista) |
| `spaceXs` | 4 | Icono ↔ texto en chips; separación mínima |
| `spaceSm` | 8 | Entre botones de icono; debajo de una etiqueta de grupo |
| `spaceMd` | 12 | Artwork ↔ texto en filas; entre botones del par Reproducir/Aleatorio |
| `spaceLg` | 16 | Margen lateral estándar; separación entre bloques de una sección |
| `spaceXl` | 24 | Entre secciones; margen de pantallas inmersivas |
| `space2xl` | 32 | Margen interior de estados vacíos y de error |
| `space3xl` | 48 | Separación grande (cabeceras hero, parte superior de estados vacíos) |

Tamaños que no son espaciado (alturas de fila, de artwork y de botón) se
definen en cada componente.

### Reglas

| Concepto | Valor |
|---|---|
| Margen lateral de página | `spaceLg` (16) en Biblioteca, Favoritos, Playlists, Cola, Ajustes, sheets y diálogos. `spaceXl` (24) solo en Reproduciendo (pantalla inmersiva). Sustituye los 20 actuales de Cola y sheets (I7) |
| Entre secciones | `spaceXl` (24) |
| Entre tarjetas (cuadrícula futura) | `spaceMd` (12) horizontal y `spaceLg` (16) vertical |
| Entre filas de lista | 0: cada fila ya incluye su propio relleno vertical |
| Icono ↔ texto | `spaceSm` (8) en botones; `spaceMd` (12) en filas de menú |
| Artwork ↔ texto | `spaceMd` (12) en filas y en el mini player; `spaceLg` (16) en cabeceras |
| Final de lista | `spaceLg` (16) extra para que la última fila no quede pegada al mini player |

---

## 4. Formas y radios

Cuatro radios más la píldora (hoy son seis, I4). Se conservan 16 y 24, que ya
usan el mini player y la carátula de Reproduciendo.

| Token | Valor | Componentes |
|---|---|---|
| `radiusSm` | 8 | Artwork ≤ 64 px (filas, mini player, Cola), tooltips |
| `radiusMd` | 12 | Artwork de 65 a 160 px (cabecera de playlist, tarjetas en cuadrícula), campos de texto, SnackBars, fila actual de la Cola |
| `radiusLg` | 16 | Mini player, contenedores y tarjetas agrupadas, menús |
| `radiusXl` | 24 | Artwork > 160 px (Reproduciendo), bordes superiores de bottom sheets, diálogos |
| `radiusFull` | píldora / círculo | Botones de texto, chips, indicador de navegación, botones de icono con contenedor, futuro campo de búsqueda, futuro artwork de artista |

**Regla:** el radio lo decide el tipo y el tamaño del componente, no la
pantalla. Un mosaico 2×2 de artwork lleva el radio en el contenedor y 0 en
cada pieza.

---

## 5. Superficies y elevación

En oscuro la elevación se comunica sobre todo con **luminosidad**; las
sombras casi no se ven sobre `#0E1016`.

| Nivel | Superficie | Aspecto | Componentes |
|---|---|---|---|
| **0 · Integrado** | `background` | Parte del fondo | Listas, contenido de página, Reproduciendo |
| **1 · Ligeramente elevado** | `surface` | Zona agrupada, sin sombra | Barra de navegación, cabecera de playlist, placeholder de artwork, futuros contenedores de sección |
| **2 · Claramente elevado** | `surfaceElevated` | Flota sobre el contenido; sin sombra o con una muy suave | Mini player, bottom sheets, menús, SnackBars |
| **3 · Modal** | `surfaceElevated` + `scrim` detrás; lo anidado dentro usa `surfaceHighest` | Bloquea el resto | Diálogos, sheets modales |

Reglas:

- **Bordes:** solo cuando dos superficies del mismo nivel se tocan o el
  componente necesita silueta (botón secundario, playlist vacía): 1 px
  `outline`. Nunca para "separar" un nivel de otro que ya se distingue por
  luminosidad.
- **Sombras:** solo el token de componente `artworkShadow` (negro al 40 %,
  desenfoque 32, desplazamiento y 12), para el artwork grande de Reproduciendo
  y cabeceras hero. Ningún otro componente lleva sombra.
- **Pulsado de un nivel 2:** capa de pulsado (§17), no un cambio de nivel.

---

## 6. Iconografía

### 6.1 Reglas

- **Familia:** Material Icons, variante **rounded** (`Icons.*_rounded`), la
  que ya usa la mayoría de la app. Formas redondeadas, coherentes con Sora y
  con los radios.
- **Relleno vs contorno:** relleno por defecto. El contorno solo se usa para
  la **versión inactiva** de un icono que tiene estado (navegación inactiva,
  favorito sin marcar). Se corrige la mezcla actual (I15).
- **Tamaños:**

| Token | Tamaño | Uso |
|---|---|---|
| `iconXs` | 16 | Indicadores de estado no pulsables en filas: corazón de favorita, barras de "sonando" (§8) |
| `iconSm` | 20 | Iconos dentro de botones de texto y chips, acciones secundarias de fila |
| `iconMd` | 24 | Estándar: navegación, barra superior, menús, ⋯, aleatorio, repetir |
| `iconLg` | 28 | Favorito en Reproduciendo |
| `iconXl` | 32 | Anterior / siguiente en Reproduciendo |
| `iconHero` | 40 | Play / pausa en Reproduciendo |

El área táctil es siempre ≥ 48 aunque el icono mida 20.

- **Color:** `iconPrimary` para acciones principales, `iconSecondary` para
  las secundarias y los estados inactivos, `primary` para los activos. Nunca
  `textMuted` en un icono pulsable.

### 6.2 Iconos del sistema

| Concepto | Icono (Material rounded) | Estados |
|---|---|---|
| Play | `play_arrow_rounded` | — |
| Pausa | `pause_rounded` | Cambio play ↔ pausa con fundido (§18) |
| Siguiente / anterior | `skip_next_rounded` / `skip_previous_rounded` | Deshabilitado al 38 % si no hay canción |
| Aleatorio | `shuffle_rounded` | Activo: `primary` **sobre un círculo `primaryContainer` de 40** (Fase 1.6B; sustituye al icono `_on`, que Material dibuja como un cuadrado relleno demasiado pesado) |
| Repetir | `repeat_rounded` → `repeat_one_rounded` | Desactivado: `iconSecondary`; todas / una: `primary` sobre círculo `primaryContainer`; "una" usa además su icono. Semántica: interruptor con valor desactivado / todas / una |
| Favorito | `favorite_border_rounded` → `favorite_rounded` | Marcado: relleno + `primary` |
| Cola | `queue_music_rounded` | — |
| Más | `more_horiz_rounded` (filas y reproductor), `more_vert_rounded` solo en la barra superior | — |
| Atrás / cerrar | `arrow_back_rounded` (navegación), `keyboard_arrow_down_rounded` (cerrar pantallas que suben desde abajo) | — |
| Buscar | `search_rounded` | — |
| Ajustes | `settings_outlined` inactivo → `settings_rounded` activo | Solo en navegación |

No se cambia ningún icono en esta fase.

---

## 7. Artwork

### 7.1 Reglas comunes (`TakiArtwork`)

- **Proporción 1:1 siempre.** Una imagen que no es cuadrada se recorta al
  centro (`cover`); nunca se deforma ni se muestra con bandas.
- **Radio según tamaño** (§4): ≤ 64 → `radiusSm`; 65–160 → `radiusMd`;
  > 160 → `radiusXl`. Artistas (futuro): círculo (`radiusFull`), para
  distinguir personas de colecciones.
- **Origen transparente:** el componente recibe una referencia a la carátula
  y no sabe si es local (MediaStore) o remota (Jamendo). Mismo tamaño,
  radio, placeholder y transición en ambos casos. Hoy la referencia es un
  `ImageProvider?` que entrega `AlbumArtworkBuilder` (ver «Estado del
  artwork».)

### 7.2 Estados

| Estado | Aspecto |
|---|---|
| **Cargando** | Placeholder (abajo). Sin shimmer ni spinner: en listas largas distraen |
| **Cargada** | Fundido de entrada de 150 ms sobre el placeholder (solo si no estaba en caché) |
| **Ausente** (el álbum no tiene carátula) | Placeholder, definitivo |
| **Error** (no se pudo leer o descargar) | Igual que ausente. Nunca un icono de "imagen rota": una carátula que falta no es un error para el usuario |

**Placeholder:** fondo `surface` (nivel 1) e icono centrado en
`iconSecondary`, al 45 % del lado. El icono depende del tipo:

| Tipo | Icono |
|---|---|
| Canción / álbum | `music_note_rounded` |
| Playlist | `queue_music_rounded` |
| Artista (futuro) | `person_rounded` |
| Género (futuro) | `category_rounded` |

### 7.3 Tamaños

| Token | Tamaño | Dónde | Actual |
|---|---|---|---|
| `artworkRow` | 48 | `TakiSongTile`, filas de Cola, mini player | 48 en filas; 44 en mini player y Cola |
| `artworkCard` | 56 | `TakiPlaylistCard` en fila, menú "Añadir a playlist" | 52 |
| `artworkHeader` | 128 | Cabecera de playlist (y futuras de álbum o artista) | 128 |
| `artworkGrid` | fluido (ancho de columna) | Tarjetas en cuadrícula (futuro discovery) | — |
| `artworkHero` | fluido: ancho disponible − 2 × 24, máximo 360 | Reproduciendo | fluido, 240 en pantallas bajas |

**Playlist:** mosaico 2×2 si las primeras canciones tienen 4 carátulas
distintas; si no, la carátula de la primera; vacía → placeholder de playlist
con borde `outline`. Los álbumes se eligen con `playlistCoverAlbumIds` (las
primeras 4 canciones → álbumes distintos) y se resuelven con
`PlaylistCoverImages`; `TakiArtwork.mosaic` dibuja el 2×2 solo con 4
imágenes.

---

## 8. TakiSongTile

Fila de una canción. Es el componente más repetido de la app.

```
┌──────────────────────────────────────────────────────────────┐
│ 16 ┌──────┐ 12  Título de la canción               3:45  ⋯ 4 │
│    │ art  │     Artista · Álbum                              │
│    └──────┘                                                  │
└──────────────────────────────────────────────────────────────┘
```

| Parte | Especificación |
|---|---|
| Altura | **Mínimo 64**; crece si el tamaño de texto lo necesita (I13) |
| Relleno | 16 a la izquierda; 16 a la derecha, o 4 si hay acción final (el botón ya aporta su margen) |
| Artwork | `artworkRow` (48), `radiusSm` |
| Artwork ↔ texto | 12 |
| Título | `trackTitle`, `textPrimary`, 1 línea |
| Subtítulo | `trackSubtitle`, `textSecondary`: "Artista" o "Artista · Álbum"; "Artista desconocido" si falta |
| Metadata opcional | Duración en `caption` tabular, `textMuted`, a la derecha |
| Acciones finales | Opcionales: ⋯ (`more_horiz_rounded`, 48 táctil), asa de arrastre en listas reordenables |

### Estados

| Estado | Aspecto | Además del color |
|---|---|---|
| Normal | Como arriba | — |
| **Sonando** | Título en `primary` y `TakiPlayingIndicator` (16 px) sobre la carátula, con velo `background` al 55 %; las barras se detienen si está en pausa | Barras visibles + semántica "Reproduciendo" |
| **Favorita** | Corazón relleno de 16 px en `primary` delante del subtítulo, solo donde sea relevante (Biblioteca, playlists; no en Favoritos) | Forma del icono |
| **Seleccionada** (multi-selección futura) | Fondo `primaryContainer` y marca `check_circle_rounded` en `primary` en lugar del artwork | Icono de marca |
| Pulsada | Capa de pulsado (§17) | Respuesta táctil |
| **No disponible** | Contenido al 38 %, subtítulo "No disponible"; se puede pulsar para ver por qué | Texto |

### Prioridad con poco espacio

Se oculta en este orden (lo último nunca se oculta):

1. Álbum del subtítulo
2. Duración
3. Asa de arrastre (se sigue pudiendo reordenar con pulsación larga y acciones de accesibilidad)
4. **Nunca:** artwork, título, artista y ⋯

---

## 9. Botones

Medidas comunes: **alto 48**, **radio píldora**, relleno horizontal **24**
(con icono delante: **16** a la izquierda y 24 a la derecha, dentro de la
escala de §3), icono `iconSm` (20) a **8** del texto, texto en `label`. Un
solo botón primario por pantalla o sección.

**Botón de icono con contenedor** (círculo `surfaceElevated` o
`textPrimary`): círculo visible de **40** dentro del área táctil de 48; el
anillo de foco (2 px a 2 px) cabe justo en esos 48. Solo admite iconos
`iconSm` o `iconMd`.

| Tipo | Fondo | Texto / icono | Borde | Uso |
|---|---|---|---|---|
| **Primario** | `primary` | `onPrimary` | — | La acción principal: Reproducir, Crear, Permitir acceso |
| **Secundario** | `surfaceElevated` | `textPrimary` | 1 px `outline` | Acción alternativa junto a una primaria: Aleatorio, Cola |
| **Terciario / texto** | transparente | `primary` | — | Acciones de bajo peso: Cancelar, Deshacer, Ver todo |
| **Icono** | transparente (o círculo `surfaceElevated` / `textPrimary` en la variante con contenedor) | `iconPrimary` o `iconSecondary`; activo `primary` | — | Acciones sin texto; siempre con tooltip |
| **Destructivo** | `error` (versión rellena, solo para confirmar una acción irreversible) o transparente con texto `error` (en diálogos) | `onPrimary` / `error` | — | Eliminar playlist, quitar definitivamente |

### Estados

| Estado | Primario | Secundario | Terciario | Icono |
|---|---|---|---|---|
| Default | Como arriba | Como arriba | Como arriba | Como arriba |
| Pressed | Fondo `primaryPressed` + escala 0.98 | Capa de pulsado | Capa de pulsado | Capa circular de pulsado |
| Focused | Anillo 2 px `textPrimary` a 2 px del botón | Anillo 2 px `primary` | Anillo 2 px `primary` | Anillo 2 px `primary` |
| Disabled | Fondo `textPrimary` 12 %, texto 38 % | Texto 38 %, borde 12 % | Texto 38 % | Icono 38 % |
| Loading | El icono se sustituye por un spinner de 20 px en el color del texto; mismo ancho; no se puede pulsar | Igual | Texto → spinner | Icono → spinner |

**Destructivo:** el relleno (`error`) se comporta como el primario al pulsar
(capa `pressedOverlay` encima y escala 0.98, sin un color `errorPressed`) y
con foco (anillo `textPrimary`); deshabilitado, como el primario. La versión
de texto (`error` sin fondo) se comporta como el terciario.

---

## 9b. TakiSearchField

Campo de búsqueda (Fase 3.2C). Solo presentación: **no** busca ni hace
debounce; quien lo usa le pasa un `controller` (y opcionalmente un
`focusNode`) y recibe `onChanged` / `onSubmitted`. `core/widgets/taki_search_field.dart`.

| Parte | Especificación |
|---|---|
| Forma | Píldora (`radiusFull`, `StadiumBorder`) |
| Fondo | `surface` (nivel 1) |
| Alto | Mínimo 48 (`TakiSearchField.minHeight`); crece con el tamaño de texto |
| Relleno | 16 a la izquierda; icono → 12 → texto; a la derecha, el botón «Borrar» o 16 |
| Icono | `search_rounded`, `iconMd`, `iconSecondary` (decorativo, fuera de la semántica) |
| Texto | `body` en `textPrimary`; cursor `primary` |
| Pista | `body` en `textMuted` |
| Teclado | Acción `search` |
| Sin colores, radios ni espacios nuevos | Solo tokens existentes |

### Estados

| Estado | Regla | Señal no cromática |
|---|---|---|
| **Reposo** | Contorno del mismo color que el fondo (invisible) | — |
| **Foco** | Anillo de 2 px en `focusRing` (`primary`). El contorno es **siempre** de 2 px, así que la fila no se mueve al enfocar | El anillo |
| **Con texto** | Aparece «Borrar búsqueda» (`TakiIconButton` `subtle`, `close_rounded`, 48 táctil) | El botón |
| **Borrar** | Vacía el campo, avisa con `onChanged('')` y deja el foco en el campo | — |
| **Deshabilitado** | Contenido al 38 % (`disabledContentOpacity`), sin botón de borrar, sin anillo | Semántica deshabilitada |

**Accesibilidad:** etiqueta por defecto = la pista (`semanticLabel` la
sustituye); «Borrar búsqueda» es también su tooltip.

---

## 10. TakiMiniPlayer

Resumen persistente de lo que suena, sobre la navegación inferior.

```
   ┌─ 8 ────────────────────────────────────────────────── 8 ─┐
   │ ┌──────┐ 12  Título de la canción                  ( ▶ ) │ 64
   │ │ art  │     Artista                                     │
   │ └──────┘                                                 │
   │▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔ progreso 2 px ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔│
   └──────────────────────────────────────────────────────────┘
   ─────────────── 8 ───────────────
   [      Biblioteca   Playlists   Favoritos   Ajustes       ]
```

| Parte | Especificación |
|---|---|
| Altura | 64 |
| Márgenes | 8 a los lados y 8 entre el mini player y la navegación (hoy 12 a los lados) |
| Fondo | `surfaceElevated` (nivel 2), sobre la navegación en `surface` (nivel 1): se distingue por luminosidad, sin borde ni sombra |
| Radio | `radiusLg` (16) |
| Artwork | `artworkRow` (48), `radiusSm`, a 8 del borde |
| Título / artista | `trackTitle` / `trackSubtitle`, 1 línea (unifica el 14 actual con las filas, I5) |
| Play / pausa | Botón de icono con contenedor: círculo de 40 en `textPrimary`, icono `onTextPrimary` (= `background`), área táctil 48 |
| Progreso | 2 px en el borde inferior, dentro del radio; pista `divider`, relleno `primary` |
| Favorito | Opcional, no por defecto (el espacio es para el título) |
| Siguiente | Opcional, `iconPrimary`, solo si el ancho ≥ 400 |
| Interacción | Tocar o deslizar hacia arriba abre Reproduciendo (actual). Sin canción no ocupa espacio |

**Por qué el play del mini player no es naranja (I9, regla explícita):** el
mini player aparece en todas las pantallas; en naranja competiría con la
acción primaria de cada una. El naranja del mini player es el progreso. En
Reproduciendo el play sí es naranja porque ahí es la acción principal.

---

## 11. Reproduciendo

Lenguaje de la pantalla completa del reproductor. No es un diseño cerrado.

### Jerarquía (de más a menos peso)

1. **Artwork** (`artworkHero`, `radiusXl`, `artworkShadow`). Ocupa la mitad
   superior. Es el único elemento con sombra.
2. **Título** (`headline`, hasta 2 líneas) y **artista** (`bodyLarge`,
   `textSecondary`), alineados a la izquierda. El **favorito** (`iconLg`) a la
   derecha del bloque, en la misma altura.
3. **Progreso:** pista de 4 px (`divider` → relleno `primary`), pulgar de 16
   en `textPrimary` que crece a 20 al arrastrar; tiempo transcurrido y total
   en `caption` tabular debajo, a los extremos.
4. **Controles de transporte** (`TakiPlaybackControls`), en una fila de 5:
   aleatorio (`iconMd`) · anterior (`iconXl`) · **play/pausa** (círculo de 72
   en `primary`, icono `iconHero` en `onPrimary`) · siguiente (`iconXl`) ·
   repetir (`iconMd`). Los extremos cambian de icono además de color cuando
   están activos (§6.2).
5. **Acciones secundarias:** botón secundario "Cola" y ⋯ para más acciones.
   Todo botón visible debe hacer algo (hoy "Más opciones" no hace nada, I14).

### Reglas

- **Contexto:** arriba, "REPRODUCIENDO DESDE" (`eyebrow`) y el origen real
  (Biblioteca, Favoritos, nombre de la playlist). Hoy es un texto fijo (I14).
- **Fondo:** `background`. **No** se tiñe toda la pantalla con el color de la
  carátula (patrón muy asociado a otros reproductores). Como mucho, un halo
  suave del color dominante de la carátula **detrás del artwork** (al 16 %
  como máximo, desenfocado), opcional y para una fase posterior.
- **Margen lateral:** 24. Separación entre bloques: 24; dentro de un bloque:
  8.
- **Cerrar:** botón `keyboard_arrow_down_rounded` arriba a la izquierda y
  gesto de deslizar hacia abajo (actual).

---

## 12. TakiPlaylistCard

Una colección de canciones: playlist local hoy; playlist online, álbum o mix
en el futuro. Dos variantes con el mismo contenido.

**Fila** (lista de Playlists, sheet "Añadir a playlist"):

| Parte | Especificación |
|---|---|
| Altura | Mínimo 72 (hoy 68) |
| Relleno | 16 a los lados |
| Artwork | `artworkCard` (56), `radiusSm`, mosaico según §7.3 |
| Nombre | `trackTitle`, `textPrimary`, 1 línea |
| Metadata | `trackSubtitle`, `textSecondary`: "12 canciones · 48 min"; "Vacía" si no tiene canciones |
| Final | `chevron_right_rounded` en `iconSecondary` si navega; ninguno si es una elección en un sheet |

**Tarjeta en cuadrícula** (futuro: discovery, secciones horizontales):

| Parte | Especificación |
|---|---|
| Ancho | Columna de la cuadrícula (2 columnas en móvil) o 144 en carrusel horizontal |
| Artwork | `artworkGrid`, `radiusMd`. **El artwork es la tarjeta:** sin contenedor ni fondo alrededor |
| Nombre | `titleMedium`, hasta 2 líneas, 8 por debajo del artwork |
| Metadata | `trackSubtitle`, `textSecondary`, 1 línea |
| Origen (futuro online) | Etiqueta pequeña en la metadata ("Taki", "Local"), nunca un logotipo sobre la carátula |

**Estados:** pulsada → capa de pulsado sobre el artwork + escala 0.98;
seleccionada → anillo de 2 px en `primary` alrededor del artwork y marca
`check_circle_rounded` en la esquina; sonando → `TakiPlayingIndicator` en la esquina
inferior del artwork.

---

## 13. TakiSectionHeader

Encabeza un grupo de contenido. Dos variantes:

| Variante | Título | Uso |
|---|---|---|
| **Grupo** | `eyebrow`, `textMuted` | Agrupar dentro de una lista: "TUS PLAYLISTS", "A CONTINUACIÓN". Unifica los estilos actuales (I5) |
| **Sección** | `titleLarge`, `textPrimary` | Secciones de contenido de una página: futuros "Escuchado recientemente", "Álbumes" |

| Parte | Especificación |
|---|---|
| Subtítulo opcional | `trackSubtitle`, `textSecondary`, 1 línea, 2 por debajo del título (solo variante Sección) |
| Acción opcional | Botón terciario ("Ver todo") o botón de icono, alineado con la línea base del título |
| Espaciado | 24 encima (8 si es la primera de la pantalla), 8 debajo (grupo) o 12 debajo (sección); 16 a los lados |

---

## 14. TakiEmptyState

Para cuando no hay contenido **y no es un error**. Un patrón común con
contenido propio de cada caso.

| Parte | Especificación |
|---|---|
| Visual | Icono de 32 en `iconSecondary`, dentro de un círculo de 80 en `surface` (el icono ya no va en naranja: el color lo aporta el botón). En estados de primer uso puede sustituirse por una ilustración con `brandGradient` |
| Título | `titleLarge`, `textPrimary`, centrado |
| Descripción | `body`, `textSecondary`, centrada, ancho máximo 320 |
| Acción opcional | Un botón primario; opcionalmente uno terciario debajo. En "sin resultados", la acción es terciaria |
| Espaciado | Relleno 32; visual → 16 → título → 8 → descripción → 24 → acción → 12 → acción terciaria |

### Dos tipos

| Tipo | Cuándo | Diferencia |
|---|---|---|
| **Primer uso** | Nunca hubo contenido: sin canciones, sin favoritos, sin playlists | Centrado en la pantalla, con acción que enseña qué hacer |
| **Sin resultados** | Hubo algo pero el filtro o búsqueda no encuentra nada | Arriba (48 desde la parte superior), sin círculo (solo el icono de 32), sin botón o con "Limpiar búsqueda" |

### Contenido por caso

| Caso | Icono | Título | Acción |
|---|---|---|---|
| Sin canciones | `music_off_rounded` | "No encontramos canciones" | Reintentar |
| Sin favoritos | `favorite_border_rounded` | "Sin favoritos" | — (explica el corazón y la pulsación larga) |
| Sin playlists | `queue_music_rounded` | "Aún no tienes playlists" | Nueva playlist |
| Playlist vacía | `playlist_add_rounded` | "Esta playlist está vacía" | — (explica cómo añadir) |
| Sin resultados de búsqueda *(implementado en 3.2C/3.2E)* | `search_off_rounded` | "No encontramos música" · "Prueba con otro título." | — |
| Búsqueda no disponible *(implementado)* | `cloud_off_rounded` | "Búsqueda no disponible" · "Esta función no está disponible en esta versión." | — |

---

## 15. TakiErrorState

Para cuando algo **falló** o **falta un permiso**. Misma estructura que
`TakiEmptyState`, distinto tono visual para que un error nunca parezca un
vacío (I6).

| Parte | Error | Permiso |
|---|---|---|
| Visual | Icono en `error` dentro de un círculo `errorContainer` | Icono en `iconPrimary` dentro de un círculo `surface` (no es un fallo: es un paso pendiente) |
| Título | `titleLarge`: qué no funcionó | `titleLarge`: qué necesita Taki |
| Mensaje | `body`, `textSecondary`: qué puede hacer el usuario, sin jerga técnica | `body`: para qué y qué no se hace ("Nada sale de tu dispositivo") |
| Acción principal | Primario "Reintentar" | Primario "Permitir acceso" o "Abrir ajustes" |
| Acción secundaria | Terciario opcional (p. ej. "Ver detalles") | — |

### Por tipo de error

| Situación | Forma |
|---|---|
| Error recuperable de pantalla (no se leyó la biblioteca, favoritos o playlists no disponibles) | `TakiErrorState` a pantalla completa con Reintentar |
| Permiso denegado / denegado para siempre | `TakiErrorState` variante permiso |
| Canción no disponible (borrada, SD retirada) | **En línea:** `TakiSongTile` en estado "No disponible" + SnackBar al intentar reproducirla |
| Fallo de una acción puntual (no se pudo crear la playlist) | SnackBar con el mensaje y, si aplica, "Reintentar" |
| Error de artwork | No se muestra: placeholder (§7.2) |

**SnackBar:** fondo `surfaceElevated`, texto `body` en `textPrimary`, acción
terciaria, radio `radiusMd`, 8 sobre el mini player o la navegación.

---

## 16. Navegación inferior

Hoy: 4 destinos (Biblioteca, Playlists, Favoritos, Ajustes) y, **solo si hay
algún catálogo disponible**, un 5.º: **Buscar** (`search_rounded`), entre
Biblioteca y Playlists (Fase 3.2C). Sin catálogo, la barra es la de siempre.

| Parte | Especificación |
|---|---|
| Altura | 72 (actual), más el inset inferior del sistema |
| Fondo | `surface` (nivel 1), sin borde superior ni sombra |
| Icono | `iconMd`; inactivo en contorno y `iconSecondary`; activo relleno y `primary` |
| Etiqueta | `labelSmall`, **siempre visible**; inactiva `textSecondary`, activa `textPrimary` con peso 600 |
| Indicador | Píldora de 64×32 en `primaryContainer` detrás del icono activo |
| Interacción | Tocar la pestaña activa vuelve a su raíz (actual); pulsado con capa sobre el indicador; cambio de pestaña sin animación de página (cada rama conserva su estado) |

La pestaña activa se distingue por **cuatro señales**: indicador, icono
relleno, color y peso de la etiqueta.

**Con el mini player:** el mini player se apoya en la navegación (8 de
separación) y no la tapa; juntos forman un único bloque inferior. Las listas
reservan en su final el alto de ese bloque.

**Máximo 5 destinos.** Buscar ya es el 5.º (Fase 3.2C); un destino nuevo exigiría
decidir cuál sale (decisión de producto); el estilo no cambia.

---

## 17. Estados de interacción

Un solo lenguaje para toda la app. Las capas se aplican **encima** del
componente (no cambian su color de fondo).

| Estado | Regla general | Señal no cromática |
|---|---|---|
| **Default** | Tokens del componente | — |
| **Pressed** | Capa de `textPrimary` al 10 %; sobre fondos naranjas, `primaryPressed`. Las tarjetas y el botón primario además escalan a 0.98 | Respuesta táctil inmediata (≤ 100 ms) |
| **Selected** | Fondo `primaryContainer` o anillo `primary` | Marca `check_circle_rounded` |
| **Active** (toggle encendido, pestaña actual, canción que suena) | Icono o texto en `primary` | Variante de icono (relleno), círculo `primaryContainer` (aleatorio, repetir) o indicador (`TakiPlayingIndicator`, píldora) |
| **Focused** (teclado, D-pad, accesibilidad) | Anillo de 2 px en `primary` (en `textPrimary` sobre componentes naranjas), a 2 px del componente | El anillo |
| **Disabled** | Contenido al 38 %, contenedor al 12 %; no responde | Semántica `enabled: false` |
| **Loading** | Spinner del tamaño del icono que sustituye; el componente mantiene su tamaño | Semántica "Cargando" |
| **Error** | Color `error` en icono y texto | Icono de error + mensaje |

### Por componente

| Componente | Pressed | Selected / Active | Disabled | Loading |
|---|---|---|---|---|
| Botones | Tabla §9 | — | 38 % | Spinner |
| `TakiSongTile` | Capa en toda la fila | Seleccionada: `primaryContainer` + marca; sonando: `primary` + barras | "No disponible" al 38 % | — (la lista entera carga) |
| `TakiPlaylistCard` | Capa + 0.98 | Anillo + marca; sonando: barras | 38 % | — |
| Botones de icono | Capa circular | `primary` + variante de icono | 38 % | Spinner |
| Navegación | Capa sobre el indicador | Indicador + relleno + etiqueta 600 | — | — |
| Controles de reproducción | Capa circular; play: `primaryPressed` | Aleatorio y repetir: `primary` sobre círculo `primaryContainer` | 38 % sin canción | Play: spinner en lugar del icono mientras carga; sigue respondiendo (se puede pausar) |

---

## 18. Movimiento

Rápido, natural y funcional: una animación existe solo si explica un cambio
(de dónde viene algo, qué cambió de estado).

### Tokens

| Token | Duración | Uso |
|---|---|---|
| `motionInstant` | 100 ms | Respuesta al pulsar (capa, escala) |
| `motionShort` | 150 ms | Fundidos de icono (play ↔ pausa, favorito), aparición de artwork |
| `motionMedium` | 250 ms | Bottom sheets, SnackBars, aparición del mini player |
| `motionPlayingLoop` | 900 ms | Un ciclo del indicador "sonando"; se repite solo mientras suena |
| `motionLong` | 320 ms entrada / 260 ms salida | Pantallas completas que suben (Reproduciendo, Cola). Valores actuales |

| Curva | Uso |
|---|---|
| `easeOutCubic` | Entradas (algo aparece o llega) |
| `easeInCubic` | Salidas (algo se va) |
| `easeInOutCubic` | Cambios de estado de un elemento que permanece |

### Por caso

| Caso | Movimiento |
|---|---|
| Transiciones de página | Entre pestañas: ninguna. Pantallas del reproductor: suben desde abajo (actual). Detalle (playlist, futuros álbum y artista): entrada lateral estándar de Android |
| Bottom sheets | Suben con `motionMedium`; el scrim aparece con fundido |
| Mini player | Aparece la primera vez que suena algo: subida de 16 px + fundido, `motionMedium`. Al cambiar de canción: fundido cruzado del contenido, sin mover el contenedor |
| Estado de reproducción | Play ↔ pausa con fundido y escala (`motionShort`); `TakiPlayingIndicator` en bucle de 900 ms solo mientras suena, quietas en pausa (actual) |
| Favorito | Al marcar: el corazón escala 1 → 1.2 → 1 y se rellena (`motionShort`). Al desmarcar: solo fundido |
| Carga | Los indicadores aparecen tras 300 ms de espera (si carga antes, no se ven); el contenido entra con fundido |

**Movimiento reducido:** si el sistema pide reducir animaciones, los
desplazamientos se sustituyen por fundidos y `TakiPlayingIndicator` queda quieta
(sigue marcando la canción, porque la barra es visible aunque no se mueva).

---

## 19. Accesibilidad

### Contraste (medido)

| Combinación | Ratio | Requisito |
|---|---|---|
| `textPrimary` sobre niveles 0–3 | 12.4–16.7 | ✅ AA/AAA |
| `textSecondary` sobre niveles 0–3 | 5.8–7.8 | ✅ AA |
| `textMuted` sobre niveles 0–2 | 4.6–5.5 | ✅ AA; **no** usar sobre nivel 3 (4.1) |
| `primary` sobre `background` | 8.1 | ✅ AA (texto e iconos) |
| `onPrimary` sobre `primary` | 8.1 | ✅ AA |
| `onPrimary` sobre `primaryPressed` | 6.6 | ✅ AA |
| `primary` sobre `primaryContainer` | 6.2 | ✅ AA |
| `error` sobre `background` | 6.9 | ✅ AA |
| Anillo de foco `primary` sobre nivel 2 | 6.8 | ✅ ≥ 3:1 (componentes) |
| `outline` y `divider` | 1.3–1.5 | Decorativos: ningún componente depende solo de ellos |

### Reglas mínimas

- **Tamaño táctil:** ≥ 48×48 en todo lo pulsable, aunque el icono o el
  círculo visible sean menores.
- **Texto:** ningún texto por debajo de 12, salvo `eyebrow` (11, mayúsculas y
  espaciado). La interfaz funciona con el texto del sistema al 200 %: las
  filas crecen en lugar de recortar (I13).
- **Iconos:** todo botón de icono tiene `tooltip` (hoy se cumple) y ese texto
  es su etiqueta semántica. Los iconos decorativos se excluyen de la
  semántica.
- **Etiquetas semánticas:** las filas se leen como una unidad ("Título,
  Artista, 3:45"), con acciones de accesibilidad para ⋯ y reordenar.
- **Nada depende solo del color:**

| Estado | Señal de color | Señal adicional obligatoria |
|---|---|---|
| Favorito | `primary` | Corazón relleno vs contorno; semántica "Favorita" / `toggled` |
| Sonando | Título en `primary` | `TakiPlayingIndicator` visible; semántica "Reproduciendo" |
| Seleccionado | `primaryContainer` | Marca de verificación; semántica `selected` |
| Toggle activo (aleatorio, repetir) | `primary` | Círculo `primaryContainer` detrás del icono ("repetir una" con su icono); semántica `toggled` / valor |
| Deshabilitado | 38 % | Semántica `enabled: false` |
| Error | `error` | Icono de error + mensaje en texto |
| Pestaña activa | `primary` | Indicador, icono relleno, etiqueta en 600; semántica `selected` |

---

## 20. Do / Don't

**DO**

- Usar tokens semánticos (`TakiColors.textSecondary`, `TakiSpacing.lg`),
  nunca HEX ni números sueltos en un widget.
- Mantener la jerarquía: un botón primario por pantalla o sección y el resto
  secundarios, terciarios o de icono.
- Reutilizar los componentes `Taki*` antes de crear uno nuevo; si falta una
  variante, añadirla al componente.
- Dar protagonismo al artwork: siempre visible en filas y tarjetas, grande
  donde la canción es el tema.
- Separar con espacio y luminosidad antes que con bordes y divisores.
- Acompañar cada estado de color con una señal de forma, icono o texto.
- Escribir en español claro y cercano ("No encontramos canciones", no "Error
  al consultar MediaStore").
- Probar cada pantalla con texto al 200 % y con TalkBack.

**DON'T**

- Introducir colores fuera de la paleta, ni "variantes" de un token a ojo.
- Usar radios distintos a los de §4 para un mismo tipo de componente.
- Crear botones ad hoc con `styleFrom` en una pantalla.
- Usar el naranja en todo: fondos, iconos decorativos, bordes, texto largo o
  varios botones primarios juntos.
- Indicar un estado solo con color.
- Mostrar un icono de "imagen rota" o un error cuando falta una carátula.
- Teñir la pantalla entera con el color de la carátula, ni usar el verde, el
  rosa o los degradados característicos de Spotify, Deezer o Apple Music, ni
  copiar su disposición de controles de forma literal.
- Ajustar `fontSize` a mano en lugar de elegir un rol tipográfico.
- Añadir animaciones decorativas o de más de 320 ms.
- Usar el degradado de marca en elementos de interfaz.

---

## 21. Inventario de componentes

No se implementan en esta actividad. La columna "Ubicación" sigue las reglas
de [ARCHITECTURE.md](ARCHITECTURE.md): lo que no depende de ninguna feature
va a `core/`; lo que necesita providers de una feature se queda en ella.

### Foundation

| Componente | Contenido | Ubicación | Parte de |
|---|---|---|---|
| `TakiColors` | Tokens de §1 | `core/theme/` | `AppColors` (eliminado en 1.9B) |
| `TakiTypography` | Roles de §2 | `core/theme/` | Escala de `AppTheme._textTheme` |
| `TakiSpacing` | Escala de §3 | `core/theme/` | — |
| `TakiRadius` | Radios de §4 | `core/theme/` | — |
| `TakiElevation` | Niveles de §5, `artworkShadow` (`scrim` está en `TakiColors`) | `core/theme/` | `AppColors.artworkShadow` (eliminado en 1.9B) |
| (tema) | `AppTheme` construye el `ThemeData` a partir de los tokens | `app/theme/` | `AppTheme` |

**Implementado en Fase 1.3** (las cinco foundations; entonces la UI aún usaba
`AppColors`, eliminado en la Fase 1.9B, y el tema anterior hasta el paso 1 de §22). Representación en
código:

| Foundation | Archivo | API |
|---|---|---|
| `TakiColors` | `taki_colors.dart` | Un campo por token de §1 con el mismo nombre (`TakiColors.surfaceElevated`, `TakiColors.primary`…). Los estados derivados (`selected`, `active`, `pressedOverlay`, `focusRing`, `disabledContent`, `disabledContainer`) y `scrim` están calculados a partir de la paleta. `brandGradient` es un `LinearGradient` |
| `TakiTypography` | `taki_typography.dart` | Un `TextStyle` por rol de §2.2 con el mismo nombre (`TakiTypography.trackTitle`…), sin color; `roles` los lista todos. `eyebrow` no cambia el texto: las MAYÚSCULAS las aplica quien lo muestra |
| `TakiSpacing` | `taki_spacing.dart` | `xxs`, `xs`, `sm`, `md`, `lg`, `xl`, `xxl`, `xxxl` = `space2xs` … `space3xl` (un identificador de Dart no puede contener `2xs`). Reglas con nombre: `pageGutter`, `pageGutterImmersive`, `sectionGap` |
| `TakiRadius` | `taki_radius.dart` | `sm`, `md`, `lg`, `xl` (y `smAll` … `xlAll` como `BorderRadius`), `pill` (`StadiumBorder`) y `forArtwork(side)` con la regla de §4 |
| `TakiElevation` | `taki_elevation.dart` | Enum `integrated`, `raised`, `floating`, `modal` (niveles 0–3) con su `surface` y `hasScrim`; `borderWidth`; `artworkShadow` como única sombra |
| `TakiIconSize` (Fase 1.4A) | `taki_icon_size.dart` | Enum `sm`, `md`, `lg`, `xl`, `hero` = `iconSm` … `iconHero` de §6.1, con su `value` |
| `TakiMotion` (Fase 1.4A) | `taki_motion.dart` | `instant`, `short`, `medium`, `longEnter`, `longExit` (§18); curvas `enter`, `exit`, `change`; `pressedScale` (0.98, §17) |

Los tests de `test/core/theme/` comparan estos valores con las tablas de este
documento: si cambia uno de los dos, fallan.

### Components

| Componente | Ubicación | Parte de |
|---|---|---|
| `TakiArtwork` · **implementado (1.4A)** | `core/widgets/` | `ArtworkImage` + `PlaylistCover` (ambos eliminados en 1.8; el mosaico es `TakiArtwork.mosaic`) |
| `TakiSongTile` · **implementado (1.4B)** | `core/widgets/` | `SongTile` |
| `TakiButton` (primario, secundario, terciario, destructivo) · **implementado (1.4A)** | `core/widgets/` | `PlayShuffleButtons`, botones del tema |
| `TakiIconButton` · **implementado (1.4A)** | `core/widgets/` | `_CircleButton`, `_ControlButton` (Reproduciendo) |
| `TakiSectionHeader` · **implementado (1.4A)** | `core/widgets/` | `_SectionLabel` (Playlists y Cola; hoy son dos clases con estilos distintos) |
| `TakiPlaylistCard` · **implementado (1.4B), variante fila** | `core/widgets/` (recibe datos, no providers) | `_PlaylistRow` (Playlists) |
| `TakiEmptyState` · **implementado (1.4B)** | `core/widgets/` | `MessageView` (casos vacíos) |
| `TakiErrorState` · **implementado (1.4B)** | `core/widgets/` | `MessageView` (casos de error y permiso) |
| `TakiSearchField` · **implementado (3.2C)** | `core/widgets/` | — (componente nuevo; lo usa la pantalla Buscar) |
| `TakiMiniPlayer` · **implementado (1.4B), en el App Shell (1.6E)** | `core/widgets/`: presentacional, recibe estado y callbacks; lo conecta con los providers del reproductor la feature `player` | `MiniPlayer` |
| `TakiPlayingIndicator` · **implementado (1.4B)** | `core/widgets/` | `PlayingBars` (lo necesitan filas y tarjetas de todas las features) |

**API de los componentes implementados (Fase 1.4A).** Entonces coexistían
con los widgets anteriores y ninguna pantalla los usaba (histórico); hoy las
pantallas ya están migradas.

| Componente | API |
|---|---|
| `TakiArtwork` | `size`, `image` (`ImageProvider?`), `kind` (`song`, `playlist`, `artist`, `genre`), `hero`, `semanticLabel`. Solo presentación; la carátula local llega como `ImageProvider?` desde `AlbumArtworkBuilder` (`core/artwork/`: `ArtworkCache` → `MemoryImage` + `ResizeImage`) |
| `TakiIconButton` | `icon`, `semanticLabel` (obligatorio, también tooltip), `onPressed` (`null` = deshabilitado), `variant` (`standard`, `subtle`, `tonal`, `inverse`), `iconSize` (`TakiIconSize`), `selected` + `selectedIcon` (toggle), `tooltip` |
| `TakiButton` | `label`, `onPressed`, `variant` (`primary`, `secondary`, `tertiary`, `destructive`, `destructiveTertiary`), `icon`, `loading`, `semanticLabel` |
| `TakiSectionHeader` | `title`, `variant` (`group`, `section`), `subtitle` (solo sección), `action` (`TakiSectionHeaderAction.text` o `.icon`), `isFirst` |
| `TakiSettingsTile` | `icon`, `title`, `subtitle`, `trailing`, `onTap` (`null` = informativa, no se anuncia como botón), `destructive` (título en `error`). Alto mínimo 64, anillo de foco interior, un solo nodo semántico `título, subtítulo` |

**API de los componentes musicales (Fase 1.4B).** Solo presentación: reciben
datos (`Song` de `core/domain` o valores simples) y callbacks; ninguno importa
providers, repositorios ni el motor de audio. Tampoco los usa ninguna pantalla
todavía.

| Componente | API |
|---|---|
| `TakiSongTile` | `song`, `artwork` (`ImageProvider?`), `onTap`, `onLongPress`, `onMore` (muestra ⋯), `showAlbum`, `showDuration`, `playback` (`TakiNowPlaying`: `none`, `playing`, `paused`), `isFavorite` (indicador, no botón: el favorito se cambia desde el menú o Reproduciendo), `selected`, `available`, `trailing` (p. ej. asa de arrastre) |
| `TakiPlaylistCard` | `title`, `artwork` (lista para el mosaico; vacía = colección vacía), `songCount` ("N canciones"; 0 → "Vacía"), `subtitle` (resto de la metadata), `onTap`, `onLongPress`, `showChevron`, `selected`, `nowPlaying` |
| `TakiMiniPlayer` | `song`, `artwork`, `isPlaying`, `onPlayPause`, `onOpen` (tocar o deslizar hacia arriba), `progress` (0–1), `onNext` (visible con ancho ≥ 400), `isFavorite` + `onToggleFavorite` (visible solo con callback) |
| `TakiEmptyState` | `icon`, `title`, `description`, `action`, `secondaryAction` (`TakiStateAction`), `kind` (`firstUse`, `noResults`), `illustration` (solo primer uso) |
| `TakiErrorState` | `title`, `message`, `kind` (`error`, `permission`), `icon` (por defecto el del tipo), `action`, `secondaryAction` |
| `TakiPlayingIndicator` | `animate`, `size` (`TakiIconSize`, por defecto `xs`); quieto en pausa o con animaciones reducidas |
| `TakiArtwork.mosaic` | `size`, `images` (≥ 4 → mosaico 2×2; menos → la primera; ninguna → vacía con borde `outline`), `kind`, `hero`, `semanticLabel` |

`TakiEmptyState` y `TakiErrorState` comparten `TakiStateView`
(`core/widgets/taki_state_view.dart`), con las medidas de §14
(`TakiStateMetrics`: círculo de 80, texto de 320 como máximo).

**Pendiente (gaps documentados, sin inventar valores):**

- **Umbral para ocultar la duración** en `TakiSongTile` (§8, prioridad 2): el
  documento no lo fija. Hoy la duración se mantiene; título y artista se
  recortan con elipsis y el álbum, al ir al final del subtítulo, es lo
  primero que se pierde.
- **Variante en cuadrícula de `TakiPlaylistCard`** (§12): §12 pide
  `radiusMd` para su artwork, pero la regla de §4 (`TakiRadius.forArtwork`)
  daría `radiusXl` a las columnas de más de 160 px de un móvil. Hay que
  decidir cuál manda antes de implementarla.
- **Transición play ↔ pausa** del mini player (§18: fundido y escala): el
  icono cambia sin animación.
- **Tamaño de la marca de seleccionada** en `TakiSongTile`: §8 no lo fija; se
  usa `iconMd` (24) centrado en el hueco de 48 de la carátula.

Piezas de apoyo en `core/widgets/taki_interaction.dart`: `TakiPressable`
(pulsado, foco de teclado, activación con Enter, acción de tap y de
pulsación larga para TalkBack) y `TakiFocusRing` (anillo de §17; en las
filas a ancho completo va por dentro, `inset`, para que la pantalla o las
filas vecinas no lo tapen), con las medidas
`TakiInteraction.minTouchTarget` (48), `focusRingWidth` y `focusRingGap` (2).

### Player

| Componente | Ubicación | Parte de |
|---|---|---|
| `TakiPlaybackControls` · **implementado (1.6B), en Reproduciendo (1.6C)** | `core/widgets/` (presentacional: estado y callbacks desde fuera) | `_Controls` y `_PlayPauseButton` (Reproduciendo) |
| `TakiProgressBar` · **implementado (1.6B), en Reproduciendo (1.6C)** | `core/widgets/` (recibe posición y duración) | `_SeekBar` (Reproduciendo). La barra de 2 px del mini player no lo usa: es decorativa y no se arrastra |
| `TakiQueueItem` · **no hace falta (1.6D)** | — | `_QueueRow` y `_NowPlayingCard` (Cola) componen `TakiSongTile` directamente (asa y quitar van en `trailing`) |

---

## 22. Estrategia de migración

Propuesta técnica, no orden de implementación. Principio: **incremental**,
cada paso es un commit propio que deja la app funcionando, con los tests en
verde y una revisión en dispositivo. Nunca se reescribe toda la UI de golpe.

| Paso | Qué | Cambio visible |
|---|---|---|
| **1. Foundations** | `TakiColors`, `TakiTypography`, `TakiSpacing`, `TakiRadius`, `TakiElevation` en `core/theme`. `AppTheme` los consume y define los temas que faltan (SnackBar, slider, indicadores de progreso). Las fuentes ya están empaquetadas (Fase 1.2, I1). `AppColors` quedó como alias temporal y se eliminó en la Fase 1.9B | El acento pasa de ámbar a Taki Orange y cambian los niveles de superficie, en un único punto |
| **2. Componentes compartidos** | `TakiArtwork`, `TakiButton`, `TakiIconButton`, `TakiSongTile`, `TakiSectionHeader`, `TakiEmptyState`, `TakiErrorState`, `TakiPlayingIndicator`, con widget tests y, si se decide, golden tests | Ninguno hasta que las pantallas los usen |
| **3. Navegación** | Barra inferior (§16) y `TakiMiniPlayer` (§10) como un solo bloque inferior | Indicador, márgenes, play del mini player |
| **4. Biblioteca** | Biblioteca y Favoritos con `TakiSongTile` (estado "sonando" con barras, I2), cabeceras y estados vacío/error | Marca "sonando", estados vacíos |
| **5. Playlists** | Lista, detalle y sheets con `TakiPlaylistCard`, `TakiSongTile` y estados | Filas de playlist, cabecera |
| **6. Reproductor** | Reproduciendo (§11), Cola, `TakiPlaybackControls`, `TakiProgressBar`, `TakiQueueItem`; iconos `_on` en aleatorio y repetir (I3); origen real (I14) | Controles y jerarquía |
| **7. Ajustes** | Primera pantalla real de Ajustes construida ya con el sistema | Nueva pantalla |
| **8. Pulido** | Movimiento (§18), movimiento reducido, revisión de accesibilidad (texto 200 %, TalkBack), limpieza de tokens antiguos | Detalles |

**Estado del App Shell (Fase 1.5, pasos 1 y 3 en parte):**

- `AppTheme` usa los tokens Taki: esquema de color, superficies por nivel,
  navegación inferior (§16), botones del tema (§9), sheets y diálogos
  (nivel 2 con `scrim`, radio `xl`), menús (`lg`), SnackBar (§15: flotante,
  `surfaceElevated`, radio `md`, 8 sobre el bloque inferior; a los lados el
  margen de página de 16, que §15 no fija) y tooltips (`surfaceHighest`,
  radio `sm`, texto `textPrimary` para que se lea sobre fondo oscuro).
- `AppColors` fue un **alias** temporal de `TakiColors` (las pantallas legacy usaban
  la paleta Taki sin tocar su código); se eliminó en la Fase 1.9B y
  `TakiColors` es la fuente vigente de los tokens de color.
- Tipografía del tema: los estilos de Material con equivalente directo usan
  el rol de §2.2 (`headlineSmall` → `headline`, `titleLarge`,
  `titleMedium`, `bodyLarge`, `bodyMedium` → `body`, `labelLarge` →
  `label`). **Sin rol definido todavía** (conservan el tamaño de Material con
  las familias Taki): `display*`, `headlineLarge`, `headlineMedium`,
  `titleSmall`, `bodySmall`, `labelMedium`, `labelSmall`.
- **Pendiente:** el mini player sigue siendo el widget legacy de
  `features/player` (sus márgenes de 12, la carátula de 44 y la barra de 3 px
  viven dentro de él); pasará a `TakiMiniPlayer` con la migración del
  reproductor. Los iconos de la navegación siguen siendo los actuales (no la
  variante `_rounded` de §6.1). No hay tema de campos de texto
  (`InputDecorationTheme`) ni de slider global; `onErrorContainer` sale del
  esquema por defecto de Material.

**Estado de Reproduciendo (Fase 1.6A):** migrada a tokens y componentes
Taki (`TakiArtwork` hero, `TakiIconButton` para cerrar, más, favorito,
aleatorio, repetir, anterior y siguiente; `TakiButton` secundario para
"Cola"). Aleatorio y repetir activos usan los iconos `_on` de §6.2. La
carátula salía de `ArtworkCache` como `MemoryImage` (histórico; hoy la
resuelve `AlbumArtworkBuilder`, ver «Estado del artwork»). Huecos:

- **Play/pausa:** círculo de 72 en `primary` que `TakiIconButton` no
  cubre (su contenedor mide 40 y no es naranja); queda como botón propio de
  la pantalla hasta `TakiPlaybackControls`. El grosor del spinner (3) no está
  definido.
- **Barra de progreso:** sigue siendo el `Slider` de Material con los tokens
  de §11, a la espera de `TakiProgressBar`.
- **Origen ("Biblioteca")** bajo el eyebrow: §11 no le asigna rol; conserva
  su tamaño (14, peso 600) con `body`.
- **Repetir** no tiene valor semántico propio en `TakiIconButton`: el modo
  va en la etiqueta ("Repetir, una").
- **Los iconos `_on`** de Material se dibujan como un cuadrado relleno: en
  naranja pesan más de lo que sugiere §6.2. Pendiente de revisión visual.
- La cabecera conserva su alto de 56 (no definido en §11).

**Componentes de reproducción (Fase 1.6B):** creados en `core/widgets/`,
todavía sin usar en ninguna pantalla.

- `TakiPlaybackControls`: `isPlaying`, `isLoading`, `isShuffleEnabled`,
  `repeatMode` (`TakiRepeatMode`: `off`, `all`, `one`) y los callbacks
  `onPlayPause`, `onPrevious`, `onNext`, `onShuffle`, `onRepeat` (`null` =
  deshabilitado). Incluye `TakiPlayPauseButton` (círculo de 72, icono de 40,
  `primaryPressed`, spinner y "Cargando" mientras carga, fundido con escala
  de §18). Mientras carga **sigue respondiendo** al toque (se puede pausar
  sin esperar; ajustado en 1.6C para conservar el comportamiento de
  Reproduciendo).
- `TakiProgressBar`: `position`, `duration`, `onSeek`, `enabled`. Normaliza
  valores fuera de rango; con duración 0 o sin `onSeek` no se mueve. El seek
  se avisa al soltar (también desde TalkBack). Se anuncia como "Progreso de
  la canción" con valor "1:05 de 3:20".
- **Huecos de 1.6A resueltos en los componentes:** play/pausa de 72, barra
  de progreso, valor semántico de repetir e iconos activos (círculo
  `primaryContainer` en lugar de `_on`). Reproduciendo los aprovechará al
  integrarlos.
- **Siguen abiertos:** grosor del spinner (se usa el de Flutter, 4; §17 no lo
  fija), y los controles necesitan 264 px de ancho (5 controles): la Cola o
  el mini player, si los usan, necesitarán su propia variante compacta.

**Integración en Reproduciendo (Fase 1.6C):** `_Controls` y `_SeekBar` son
ahora adaptadores finos sobre `TakiPlaybackControls` y `TakiProgressBar`
(el `_PlayPauseButton` propio desaparece). Mismas acciones del reproductor;
`RepeatMode` se traduce a `TakiRepeatMode` en la página (el del reproductor
no sale de `player`). Mientras el seek está en curso, la página pasa el
destino como posición para que la barra no vuelva un instante atrás (como
hacía `_SeekBar`). Resuelve en pantalla los huecos de 1.6A de play/pausa,
barra, valor semántico de repetir ("Repetir", valor "una") e iconos `_on`.

**Estado de la Cola (Fase 1.6D):** migrada a componentes Taki sin cambiar
su comportamiento (reproducir, quitar con Deshacer, reordenar, Limpiar con
confirmación, cerrar).

- **Filas:** `TakiSongTile` (carátula 48, `trackTitle` / `trackSubtitle`) con
  quitar (`TakiIconButton` subtle) y el asa de arrastre en `trailing`. Sin
  duración por fila, como antes (el total va en el resumen). El alto se mide
  con una fila real (`prototypeItem`): crece con el tamaño de texto (I13) y
  la lista sigue siendo perezosa.
- **Canción actual:** `TakiSongTile` en estado sonando/en pausa (título en
  `primary`, barras sobre la carátula, "Reproduciendo" / "En pausa") sobre
  una zona de nivel 1 (`surface`) con radio `md` (§4), 8 dentro del borde.
  Sustituye a `PlayingBars` a la derecha y al fondo `surfaceElevated`.
- **Cabecera:** barra de 56 como Reproduciendo: `TakiIconButton` tonal
  (cerrar), "Cola" en `titleLarge` y "Limpiar" como `TakiButton` terciario.
  Grupos con `TakiSectionHeader` (grupo); el resumen ("2 canciones · 5 min")
  va a su derecha en `caption` / `textMuted`.
- **Carátulas:** `ArtworkCache` → bytes → `MemoryImage` (como
  Reproduciendo), a 48 px: comparte entradas de caché con las filas de la
  Biblioteca. *(Histórico: hoy lo resuelve `AlbumArtworkBuilder`; ver «Estado del artwork».)*
- **Fila arrastrada:** `surfaceElevated` (nivel 2) con radio `md`, sin la
  sombra de antes (§5).
- **Huecos:** `TakiSectionHeader` (grupo) no admite metadata a la derecha:
  el resumen se compone al lado. Los mensajes "No está sonando nada" y "No
  hay más canciones en la cola" son avisos en línea (`body`,
  `textSecondary`), no pantallas vacías: `TakiEmptyState` (icono, título
  `titleLarge`) no encaja y no se inventa uno. Con la fila actual
  enmarcada, su carátula queda 8 px más adentro que las de la lista.

**Estado del mini player (Fase 1.6E):** `MiniPlayer` (feature `player`)
es ahora un adaptador sobre `TakiMiniPlayer`; el App Shell no cambia.

- Mismo comportamiento: sin canción no ocupa espacio; tocar o deslizar
  hacia arriba abre Reproduciendo; play/pausa con `TogglePlayPause`; el
  progreso es posición / duración (sin duración, 0). Como antes, **sin
  siguiente ni favorito** (el componente los admite, pero no se añaden).
- Márgenes de §10: 8 a los lados (antes 12) y 8 hasta la navegación.
  Carátula de 48 (antes 44), play/pausa `inverse` (círculo de 40, antes 44),
  `trackTitle` / `trackSubtitle` y barra de 2 px en `divider` → `primary`
  (antes 3 px), decorativa: no es un control de seek.
- Carátula: `ArtworkCache` → bytes → `MemoryImage`, como Reproduciendo y la
  Cola. *(Histórico: hoy lo resuelve `AlbumArtworkBuilder`; ver «Estado del artwork».)* Solo la parte que dibuja el componente escucha la posición; la
  carátula no se vuelve a resolver.
- Semántica: se anuncia la canción ("título, artista"), el estado
  ("Reproduciendo" / "En pausa") y la pista "Abrir Reproduciendo"; antes
  solo "Abrir Reproduciendo".
- **Huecos:** `TakiMiniPlayer` recibe el progreso como valor, así que con
  cada posición se reconstruye el componente entero (antes solo la barra);
  el coste es bajo, pero un `ValueListenable` lo evitaría. La resolución de
  carátulas (bytes → `MemoryImage`) estaba repetida en Reproduciendo, la Cola
  y el mini player (**resuelto en 1.8B–1.8D** con `AlbumArtworkBuilder`). El
  mini player no muestra carga (no la mostraba antes). `AppColors
  .miniProgressTrack` quedaba sin uso en `lib` (`AppColors` se eliminó en 1.9B).

**Estado de la Biblioteca (Fase 1.7A, paso 4 en parte):** `LibraryPage`
migrada; Favoritos todavía no.

- **Filas:** `TakiSongTile` con duración (como antes); tocar reproduce la
  lista visible y mantener pulsado abre las acciones (sin cambios). Alto
  medido con una fila real (`SliverPrototypeExtentList`): crece con el
  tamaño de texto y la lista sigue siendo perezosa.
- **Canción actual:** estado sonando/en pausa de `TakiSongTile` (título en
  `primary`, barras sobre la carátula, "Reproduciendo" / "En pausa"). Antes
  solo el color (I2 resuelto en la Biblioteca).
- **Cabecera:** "Tu música" en `headline` (encabezado semántico) y el resumen
  en `trackSubtitle` / `textSecondary`. La barra superior "Biblioteca" sigue
  siendo la del tema.
- **Estados:** sin permiso → `TakiErrorState` de permiso; error →
  `TakiErrorState` con Reintentar; vacío → `TakiEmptyState` de primer uso
  (`music_off_rounded`, §14) con Reintentar. Mismos textos y acciones; error
  y vacío conservan el pull-to-refresh. La carga sigue siendo el spinner.
- **Carátulas:** `ArtworkCache` → bytes → `MemoryImage` a 48, como antes
  (un adaptador privado más; ver el hueco de 1.6E). *(Histórico: hoy lo resuelve `AlbumArtworkBuilder`; ver «Estado del artwork».)*
- **Huecos:** sin ⋯ en las filas ni corazón de favorita (§8 los prevé, pero
  la Biblioteca no los tenía; las acciones siguen en la pulsación larga).
  `TakiButton` no ajusta ni recorta su texto: con etiquetas largas y texto
  muy grande puede desbordar (con las fuentes reales, las de estos estados
  caben al 200 %). Sin filtros ni búsqueda (no existían).

**Estado de Favoritos (Fase 1.7B, completa el paso 4):** `FavoritesPage`
migrada; solo cambia la presentación.

- **Filas:** `TakiSongTile` con duración, en el orden de
  `favoriteSongsProvider` (más recientes primero; la pantalla no reordena).
  Sin ⋯ ni corazón (aquí todas son favoritas, §8) y sin "No disponible" (las
  que faltan en el teléfono no aparecen). Tocar reproduce los favoritos desde
  esa fila y mantener pulsado abre el mismo menú de acciones. Lista perezosa
  con `SliverPrototypeExtentList`, como la Biblioteca.
- **Canción actual:** estado sonando/en pausa de `TakiSongTile`, como en la
  Biblioteca (I2 resuelto también aquí).
- **Cabecera:** la barra "Favoritos" (encabezado) sigue siendo la del tema;
  debajo, el resumen en `trackSubtitle` / `textSecondary` y Reproducir
  (`TakiButton` primario) y Aleatorio (secundario), con icono, en un `Wrap`:
  con texto grande Aleatorio baja de línea. Sustituyen a
  `PlayShuffleButtons` (que entonces seguía en uso en el detalle de
  playlist; eliminado en la Fase 1.7E).
- **Estados:** sin permiso → `TakiErrorState` de permiso (mismos textos;
  "Permitir acceso" / "Abrir ajustes" con `requestPermission`); error de la
  base o de la biblioteca → `TakiErrorState` con Reintentar
  (`retryFavorites`); vacío → `TakiEmptyState` de primer uso
  (`favorite_border_rounded`, "Sin favoritos", sin acción). Solo la lista y
  el vacío tienen pull-to-refresh, como antes. La carga sigue siendo el
  spinner y, con `skipLoadingOnReload`, un recálculo mantiene la lista.
- **Carátulas:** `ArtworkCache` → bytes → `MemoryImage` a 48. *(Histórico: hoy lo resuelve `AlbumArtworkBuilder`; ver «Estado del artwork».)*
- **Huecos:** el adaptador de carátulas era una copia del de la Biblioteca
  (ver 1.6E; **resuelto en 1.8C**). `TakiButton` no recorta su texto: al 150 % con la fuente de
  pruebas no cabe "Permitir acceso" (con las fuentes reales sí). La carga es
  el spinner genérico, sin componente Taki. El resumen no es un
  `TakiSectionHeader` (no encaja: no hay título de sección).

**Estado de Playlists — Fase 1.7C-1 (paso 5, lista principal):**
`PlaylistsPage` migrada; el detalle (`PlaylistDetailPage`), el sheet "Añadir
a una playlist" y los diálogos siguen como estaban.

- **Tarjetas:** `TakiPlaylistCard` (fila de §12, chevron) en lugar de
  `_PlaylistRow` + `PlaylistCover`. Tocar abre el detalle (`onOpenPlaylist`)
  y mantener pulsado abre el mismo sheet Renombrar / Eliminar, con la pista
  "Renombrar o eliminar". El resumen va entero en `subtitle`
  (`formatSongsSummary`) y `songCount` no se pasa: así se conserva
  "0 canciones" y el conteo de la base (que incluye canciones ausentes).
  Mismo orden que `playlistsProvider` (la modificada más reciente primero).
- **Portada:** `TakiArtwork.mosaic` (`kind: playlist`). La página elige hasta
  4 álbumes distintos de `coverSongIds` → `libraryAlbumIdsProvider`, como
  antes; vacía → mosaico sin imágenes (placeholder con borde); con canciones
  pero sin carátulas → una pieza sin imagen.
- **Grupo:** `TakiSectionHeader` de grupo ("Tus playlists", se muestra
  "TUS PLAYLISTS"; encabezado semántico).
- **Nueva playlist:** `TakiButton` secundario con icono (48), alineado al
  inicio con su ancho natural: el área táctil es la píldora visible (la
  lista da a cada elemento todo el ancho; un `Align` lo afloja). No hay
  equivalente Taki del botón de borde
  discontinuo (64) y no se crea uno. Mismo flujo: diálogo → crear → abrir el
  detalle; si falla, "No se pudo crear la playlist".
- **Estados:** sin playlists → `TakiEmptyState` de primer uso en línea, bajo
  "Nueva playlist" y sin acción propia (no repite la de arriba); error →
  `TakiErrorState` con Reintentar (`retryPlaylists`), sin pull-to-refresh.
  La carga sigue siendo el spinner (`skipLoadingOnReload`). Sin estado de
  permiso (no lo había).
- **Huecos:** `TakiPlaylistCard` con `songCount: 0` diría "Vacía"; aquí se
  evita pasando el resumen como `subtitle`, sin cambiar el componente.
  `TakiButton` no recorta su texto: con la fuente de pruebas (cada letra tan
  ancha como alta) "Nueva playlist" no cabe a 360 px con el texto al 150 %
  (con las fuentes reales sí). `TakiButton` no tiene variante de ancho
  completo: si recibe restricciones ajustadas, su área táctil las ocupa
  pero la píldora (dentro del `Stack` de `TakiFocusRing`) se dibuja a su
  ancho natural; quien lo use debe aflojarlas. Tercera copia del adaptador
  bytes →
  `MemoryImage` (ver 1.6E), aquí para varias carátulas (**resuelto en
  1.8F** con `PlaylistCoverImages`). El sheet de acciones
  de la playlist, el sheet "Añadir a una playlist" y los diálogos siguen en
  Material. `PlaylistCover` seguía en uso en el detalle y en el sheet (histórico; eliminado en 1.8).

**Estado de Playlist Detail — Fase 1.7C-2 (completa el paso 5):**
`PlaylistDetailPage` migrada; solo cambia la presentación. La barra superior
y su menú ⋮ (Renombrar / Eliminar playlist) siguen siendo Material.

- **Cabecera:** zona agrupada (nivel 1, `TakiElevation.raised`) con la
  portada `TakiArtwork.mosaic` de 128 (`artworkHeader`), "PLAYLIST" en
  `eyebrow` / `textMuted`, el nombre en `headline` (2 líneas, encabezado
  semántico) y el resumen de las canciones visibles en `trackSubtitle`.
  Portada como antes: álbumes distintos de las 4 primeras canciones
  visibles; vacía → placeholder con borde; sin carátulas → una pieza sin
  imagen. Sin la sombra hero.
- **Reproducir / Aleatorio:** `TakiButton` primario y secundario con icono,
  en un `Wrap` (con texto grande Aleatorio baja de línea); deshabilitados
  si la playlist no tiene canciones visibles. Sustituyen a
  `PlayShuffleButtons`, que quedó sin consumidores y se eliminó en la
  Fase 1.7E.
- **Filas:** `TakiSongTile` con duración, ⋯ (`onMore`) y el asa de arrastre
  en `trailing` (48, tooltip "Arrastrar para reordenar"), como en la Cola.
  Tocar reproduce la lista visible desde esa fila; mantener pulsado y ⋯
  abren el mismo menú con "Quitar de la playlist". Canción actual: estado
  sonando / en pausa de `TakiSongTile` (antes solo color; I2 resuelto). Se
  marca por id de canción, así que un duplicado de la actual se marca en
  todas sus apariciones, como antes. Sin corazón de favorita.
- **Reordenar:** mismo `ReorderableListView` con `ValueKey(entry.id)`
  (duplicados), traducción fila visible → posición real, estado optimista
  hasta que la base emite y `MovePlaylistSong`. El alto fijo de 64
  (`itemExtent`) pasa a `prototypeItem` con una fila real (⋯ y asa
  incluidos): crece con el texto y la lista sigue siendo perezosa. La fila
  arrastrada flota en `surfaceElevated` con radio `md`, sin sombra (antes
  elevación 6), como en la Cola.
- **Quitar:** optimista, SnackBar "Quitada de la playlist" con Deshacer, sin
  cambios.
- **Estados:** sin permiso → `TakiErrorState` de permiso (mismos textos,
  "Permitir acceso" / "Abrir ajustes"); error de la base o de la biblioteca
  → `TakiErrorState` con Reintentar (`retryPlaylists`); playlist
  inexistente → `TakiEmptyState` de primer uso sin acción
  (`playlist_remove_rounded`): se eliminó, no es un fallo, y si se borra
  mientras está abierta se vuelve atrás como antes; vacía → `TakiEmptyState`
  en el pie de la lista (`playlist_add_rounded`, "Sin canciones", mismo
  texto, sin acción). La carga sigue siendo el spinner. Pull-to-refresh
  solo con datos (también vacía), como antes.
- **Carátulas:** `ArtworkCache` → bytes → `MemoryImage`, a 128 en la
  portada y a 48 en las filas, con un adaptador privado de la página. *(Histórico: hoy lo resuelve `AlbumArtworkBuilder`; ver «Estado del artwork».)*
- **Huecos:** cuarta copia del adaptador bytes → `MemoryImage` (ver 1.6E; **resuelto en
  1.8G**).
  `TakiEmptyState` trae su propio scroll: en el pie de una lista se envuelve
  en `IgnorePointer` para que el arrastre llegue al pull-to-refresh (no tiene
  acciones). El asa no es un componente Taki (icono + `Tooltip`, igual que
  en la Cola). `TakiButton` no recorta su texto: con la fuente de pruebas
  "Permitir acceso" no cabe al 150 % (con las fuentes reales sí). Con la
  playlist vacía, Aleatorio (secundario deshabilitado) solo cambia el color
  del texto y se distingue poco del habilitado (estilo de `TakiButton`).
  Con texto al 150 % a 360 px, ⋯ y el asa (96) dejan poco ancho al título,
  que se recorta pronto. Barra
  superior, menú ⋮, diálogos y el sheet de acciones siguen en Material.
  `PlaylistCover` (aún en el sheet "Añadir a una playlist") quedaba para la
  limpieza (eliminado en 1.8H–1.8I); `PlayShuffleButtons` ya se eliminó en la
  Fase 1.7E.

**Estado del artwork — Fases 1.8A–1.8M (vigente):** todas las pantallas
resuelven las carátulas locales por el mismo camino; las entradas «Estado de
…» anteriores son el registro histórico de cada fase. *(Nota posterior, Fases
2.x–3.7: el mismo camino resuelve también las `ArtworkReference` remotas —
`ArtworkCache` pide a un `RemoteArtworkLoader`—, y las portadas de playlist
incluyen canciones remotas; ver `docs/ARCHITECTURE.md`, «Artwork».)*

```text
ArtworkRepository → ArtworkCache → AlbumArtworkBuilder → MemoryImage + ResizeImage → TakiArtwork
```

- **Resolución:** `AlbumArtworkBuilder` (una carátula) y
  `AlbumArtworkMosaicBuilder` (varias, para mosaicos) en `core/artwork/`. El
  tamaño que reciben es **lógico**; piden a `ArtworkCache` `(size × dpr)`
  píxeles y entregan `ResizeImage(MemoryImage(bytes))`, o `null` mientras
  carga, sin `albumId`, sin carátula o si falla la lectura. `TakiArtwork`
  pinta entonces su placeholder (§7.2).
- **Decodificación:** `ResizeImage` limita la decodificación al ancho físico
  pedido, no amplía las imágenes menores y conserva la relación de aspecto; el
  recorte a cuadrado sigue siendo de `TakiArtwork` (§7.1). Medición en
  Android 15 (emulador) en `docs/PHASE_1_8K_ARTWORK_DEVICE_MEASUREMENT.md`.
- **Consumidores:** Biblioteca, Favoritos, Cola, mini player y Reproduciendo
  (una carátula); lista de playlists, cabecera del detalle y sheet "Añadir a
  una playlist" (mosaico). Ya no hay adaptadores privados por pantalla.
- **Mosaico de playlist:** `playlistCoverAlbumIds` toma las primeras 4
  canciones y deja los álbumes distintos, en orden; `PlaylistCoverImages` los
  resuelve. Con 4 álbumes, `TakiArtwork.mosaic` dibuja el 2×2 (cada tesela se
  pide a `floor(size / 2)`); con 1–3, la primera carátula a lado completo; sin
  canciones, placeholder con borde; con canciones sin carátula, una pieza sin
  imagen.
- **Sheet "Añadir a una playlist" (1.8H):** portada de 44 con `TakiArtwork`
  (radio `sm` = 8 en lugar de 10 y placeholder de Taki); el mosaico usa las 4
  carátulas (antes se reescalaban).
- **Retirado:** `ArtworkImage`, `PlaylistCover`, `AlbumArtworkImage` y los
  adaptadores privados de cada pantalla.
- **Independiente:** `ArtworkFileCache` (notificación y pantalla de bloqueo)
  no forma parte de este camino.
- **Límite conocido (sin resolver):** `ResizeImage` usa solo `width`, así que
  una carátula no cuadrada conserva su relación de aspecto pero su lado corto
  queda por debajo del ancho pedido (1000×600 a 512 → 512×307). `TakiArtwork`
  la dibuja con `BoxFit.cover` y amplía ese lado para llenar el cuadrado, por
  lo que puede verse menos nítida que con una política basada en el lado corto.
  No se ha medido con carátulas reales ni en pantalla.

**Para cada paso:**

- `flutter test`, `flutter analyze` y el test de arquitectura en verde.
- Revisión en dispositivo de las pantallas tocadas.
- Sin cambios de comportamiento funcional salvo los que se decidan de forma
  explícita en ese paso.
- Actualizar este documento si una decisión cambia al implementarla.
