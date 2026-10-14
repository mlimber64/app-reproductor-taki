# Arquitectura de Taki

Taki es un reproductor de música para Android. Reproduce la **biblioteca local**
del teléfono (MediaStore) y, si la build se compila con un `client_id` de Jamendo,
también un **catálogo remoto** (Jamendo: búsqueda y reproducción en línea). Sin
backend propio, sin cuentas, sin anuncios y sin telemetría. Solo se conecta a
Jamendo (si está configurado), a las URL de carátula/audio que este devuelve y a
los enlaces que abre el usuario.

El código sigue una **arquitectura hexagonal (ports & adapters) organizada por
features**, con tres capas a nivel de app (`app`, `features`, `core`) y tres
capas dentro de cada feature (`domain`, `infrastructure`, `presentation`).

> Estado de las fases y validación en dispositivo: ver
> `docs/PHASE_3_10_DOCUMENTATION_SYNC.md`, `PHASE_3_9_ANDROID_VALIDATION_RELEASE.md`
> y `PHASE_3_9B_PRODUCTION_SIGNING.md`.

## Estructura

Árbol real de `lib/` (se omiten los `.gitkeep`):

```
lib/
├── main.dart                     Composition root: crea lo que debe existir antes
│                                 de runApp y lo inyecta con overrides
├── app/                          Composición de la app
│   ├── app.dart                  TakiApp: MaterialApp.router, locale es, tema y
│   │                             PlaybackErrorListener (aviso de errores)
│   ├── router.dart               Rutas (go_router) y shell con barra inferior
│   ├── jamendo_wiring.dart       Cablea Jamendo (lookup, reproducción, búsqueda,
│   │                             atribución, carátulas) en los registros de core
│   ├── song_lookup_wiring.dart   SourceSongLookup: local + Jamendo
│   ├── theme/app_theme.dart      AppTheme: ThemeData global
│   └── widgets/song_actions_sheet.dart   Menú de acciones de una canción
├── core/                         Piezas compartidas, sin lógica de una feature
│   ├── domain/                   Núcleo de dominio musical (Dart puro)
│   │   ├── entities/             Song, LocalSong, MusicIdentity, SongReference,
│   │   │                         ArtworkReference, PlaybackResource,
│   │   │                         ProviderAttribution, CatalogSearch*, resultados y
│   │   │                         fallos de lookup/atribución, excepciones
│   │   ├── ports/                SongLookup, PlaybackResolver, ArtworkRepository,
│   │   │                         ArtworkResolver, RemoteArtworkLoader,
│   │   │                         ArtworkHttpClient, CatalogSearch, CatalogSources,
│   │   │                         AttributionLookup, ExternalLinkOpener
│   │   └── services/             Source* (enrutado por fuente), Local*Resolver,
│   │                             SongMatcher, findAllIsolatingSources,
│   │                             external_url (openableUrl)
│   ├── artwork/                  ArtworkCache, AlbumArtworkBuilder, providers,
│   │                             HttpRemoteArtworkLoader, IoArtworkHttpClient
│   ├── catalog/                  catalogSourcesProvider
│   ├── lookup/                   songLookupProvider, attributionLookupProvider
│   ├── links/                    externalLinkOpenerProvider (url_launcher)
│   ├── theme/                    Tokens Taki (TakiColors, TakiTypography, …)
│   ├── widgets/                  Taki* (Design System), PlaceholderPage,
│   │                             song_actions
│   ├── database/                 TakiDatabase (taki.db, v3) y takiDatabaseProvider
│   ├── constants/                LibraryConstants
│   └── utils/                    duration_format, LruCache
└── features/
    ├── library/                  Biblioteca local (MediaStore), permiso de audio y
    │                             Favoritos (domain, infrastructure, presentation)
    ├── player/                   Reproducción, cola, notificación/MediaSession,
    │                             Reproduciendo, mini reproductor, atribución,
    │                             aviso de errores de reproducción
    ├── playlists/                Playlists locales y remotas (mixtas)
    ├── search/                   Búsqueda de catálogo (neutral al proveedor)
    ├── jamendo/                  Proveedor remoto actual (domain + infrastructure,
    │                             sin presentation)
    └── settings/                 Ajustes: biblioteca, almacenamiento, catálogos,
                                  privacidad y Acerca de (domain, infrastructure,
                                  presentation)
```

Pestañas: **Biblioteca**, **Buscar** (solo si hay algún catálogo disponible,
entre Biblioteca y Playlists), **Playlists**, **Favoritos** y **Ajustes**.
Favoritos vive en `library`. **Reproduciendo** y **Cola** son pantallas completas
fuera del shell.

## Capas

### `app`: composición

- Arranca la app (`TakiApp`), fija el locale (`es`), aplica el tema y monta
  `PlaybackErrorListener` en el `builder` de `MaterialApp.router`.
- Navegación: `router.dart` con `StatefulShellRoute.indexedStack` y las rutas
  `/now-playing` y `/queue`. La pestaña Buscar solo existe si
  `catalogSourcesProvider.isAvailable`.
- `AppTheme` construye el `ThemeData` Material 3 oscuro con los tokens de
  `core/theme` (Sora para títulos, DM Sans para el resto; ambas son assets
  locales).
- **Wiring de proveedores** (`jamendo_wiring.dart`, `song_lookup_wiring.dart`): es
  el único sitio donde se enlazan las piezas concretas de Jamendo con los
  registros neutrales de `core` (`SourceSongLookup`, `SourcePlaybackResolver`,
  `SourceCatalogSources`, `SourceAttributionLookup`, `SourceArtworkResolver`).
- UI que coordina varias features: `showSongActions` / `SongActionsSheet` combina
  cola (`player`), favoritos (`library`) y playlists (`playlists`); el router lo
  inyecta en `LibraryPage`, `FavoritesPage`, `PlaylistDetailPage` y `SearchPage`.

### `core`: piezas compartidas

Solo lo que usan varias features o la app entera: el dominio musical, los
contratos entre capas, las cachés de carátulas, los tokens visuales, los widgets
reutilizables y la base de datos. **No contiene lógica de una feature ni
nombra a ningún proveedor concreto** (lo comprueban los tests).

### `features`: funcionalidad

Cada feature se divide en `domain/` (`entities/`, `ports/` como
`abstract interface class`, `usecases/`, `services/`), `infrastructure/`
(adapters con paquetes externos o canales nativos) y `presentation/` (`pages/`,
`widgets/`, `providers/` de Riverpod). `jamendo` no tiene `presentation`.

## Reglas de dependencia

```
app ──────► features ──────► core ──────► paquetes externos permitidos
 └──────────────────────────► core
```

Permitido: `app → features`, `app → core`, `features → core`.
Prohibido: `features → app`, `core → features`, `core → app` y
`feature → otra feature` salvo las excepciones de abajo.

### Dentro de una feature

1. **`domain` es Dart puro** (solo `equatable` y `dart:*`; puede importar
   `core/domain`). Se comprueba en `core/domain`; en las features se revisa a mano.
2. **`infrastructure` implementa los ports**: aquí viven `just_audio`,
   `audio_service`, `audio_session`, `sqflite`, `permission_handler`,
   `device_info_plus`, `path_provider`, el canal `taki/media_store` y el HTTP de
   Jamendo.
3. **`presentation` usa los casos de uso por providers de Riverpod.**
4. Dirección hacia adentro: `presentation ─► domain ◄─ infrastructure`. El cableado
   se hace en `presentation/providers/*_providers.dart`, el único lugar de
   presentation que importa `infrastructure`.

### Reglas específicas de proveedores

- `features/search`, `features/player` y `features/playlists` **no importan
  `features/jamendo` ni mencionan «jamendo»** (tests de arquitectura).
- `features/search` no depende de `app`, y solo importa de otra feature el
  provider del Player.
- `core` no importa Jamendo (`jamendo_security_test`).
- Jamendo depende solo de `core`; lo conecta `app/`.

### Excepciones feature → feature (8)

Son 8 imports `presentation → presentation/providers` de otra feature. Ninguna
feature importa el `domain`, la `infrastructure`, las páginas ni los widgets de
otra. `test/architecture/dependency_rules_test.dart` las enumera.

| # | Origen | Destino | Motivo |
|---|---|---|---|
| 1 | `library/…/library_page.dart` | `player/…/player_providers.dart` | Reproducir, resaltar la que suena, pedir el permiso de notificaciones |
| 2 | `library/…/favorites_page.dart` | `player/…/player_providers.dart` | Ídem + Reproducir/Aleatorio |
| 3 | `player/…/now_playing_page.dart` | `library/…/favorites_providers.dart` | El corazón de Reproduciendo (los favoritos viven en `library`) |
| 4 | `playlists/…/playlists_providers.dart` | `library/…/songs_notifier.dart` | Reencuentro de canciones **locales** con la biblioteca escaneada (`localLibrarySongs`) |
| 5 | `playlists/…/playlist_detail_page.dart` | `library/…/songs_notifier.dart` | Estado de permiso local y rescan |
| 6 | `playlists/…/playlist_detail_page.dart` | `player/…/player_providers.dart` | Reproducir, mezclar, resaltar |
| 7 | `search/…/search_page.dart` | `player/…/player_providers.dart` | Tocar un resultado lo reproduce (única dependencia de `search` hacia otra feature) |
| 8 | `settings/…/settings_page.dart` | `library/…/songs_notifier.dart` | Estado de la biblioteca (permiso, recuento) y volver a escanear |

Son dependencias de composición entre providers, no de modelo ni de UI. Las
número 4 y 5 son **provisionales**: dependen de la biblioteca local escaneada.

## `core/domain`: núcleo de dominio compartido

| Elemento | Qué es |
|---|---|
| `Song` | **Modelo universal** de canción de cualquier fuente: `musicIdentity`, `title`, `artist?`, `album?`, `artwork` (`ArtworkReference`) y `durationMs`. No tiene datos locales ni de proveedor |
| `LocalSong` | `Song` **específica de la biblioteca local**: añade `id` (MediaStore), `albumId`, `path`, `contentUri`, `folder`, fecha. Solo código local la usa (`LocalPlaybackResolver`, `LocalArtworkResolver`, `SongFilter`, `SongMatcher`, `localPathOf`) |
| `MusicIdentity` | `(source, externalId)`: **qué canción es**. Texto opaco, igualdad exacta (`local:42 ≠ jamendo:42 ≠ jamendo:0042`); no depende de un id entero local ni se interpreta |
| `SongReference` | Referencia guardada (identidad + copia de respaldo de título/artista/duración/ruta); la implementan `FavoriteEntry` y `PlaylistEntry` |
| `ArtworkReference` | Sellada: `LocalArtworkReference(albumId)`, `RemoteArtworkReference(url, w, h)`, `UnavailableArtworkReference` |
| `PlaybackResource` | Sellada: cómo reproducir (ver «Reproducción») |
| `ProviderAttribution` | Atribución de un proveedor por canción (ver «Atribución») |
| `CatalogSearchQuery/Page/Failure`, `CatalogProviderInfo` | Contrato de búsqueda de catálogo |

`core/domain` es **Dart puro** (solo `equatable` y `dart:*`). `Song` y
`LocalSong` se comparan por valor **y por tipo en ejecución**.

## Identidad y persistencia

`MusicIdentity` es lo que se **persiste**: favoritos y playlists guardan
`source` + `external_id` (texto) en `taki.db` (v3). La fuente local es
`localMusicSource = 'local'` (`localMusicIdentity(id)`), la de Jamendo es
`'jamendo'`. Ninguna capa convierte `externalId` a número ni usa `Song.id` como
identidad universal. El id del `MediaItem` de audio_service es
`encode(source)/encode(externalId)`.

## Reproducción

```
Song ─► PlaybackResolver ─► PlaybackResource ─► JustAudioPlayerAdapter (AudioSource)
                                                   ▲
notificación / bloqueo / auriculares ─► audio_service ─► TakiAudioHandler
```

- `PlaybackResolver.resolve(Song)` devuelve un `PlaybackResource` o lanza
  `IdentityNotFound` / `PlaybackResolutionError`. `SourcePlaybackResolver` enruta por
  `identity.source`; una fuente sin resolver lanza `IdentityNotFound`.
  Resolvers: `LocalPlaybackResolver` (usa `LocalSong.contentUri`) y
  `JamendoPlaybackResolver`.
- **Variantes de `PlaybackResource`:** `LocalUriResource(uri)`;
  `RemoteUriResource(uri, expiresAt?)` (hoy Jamendo no informa `expiresAt`);
  `ProviderPlaybackResource(engine, reference?)` (motor propio de una fuente; sin
  productor hoy); `UnavailableResource(reason)`.
- `JustAudioPlayerAdapter` convierte `Local/RemoteUriResource` en
  `AudioSource.uri`; `Provider…`/`Unavailable…` o un fallo de resolución en una fuente
  no reproducible que falla al llegar su turno. Resuelve **todas** las canciones al
  encolar (con `Future.wait`).
- Si una canción falla se emite por `errors` (`PlaybackError`) y se salta a la
  siguiente (hasta 10 seguidas; después pausa). `PlaybackErrorListener` (en
  `player/presentation`, montado en `app.dart`) muestra un SnackBar discreto: «No se
  pudo reproducir. Pasando a la siguiente.» o «No se pudo reproducir esta canción»;
  nunca detalles técnicos. No reintenta.
- `TakiAudioHandler` (`BaseAudioHandler`) publica `MediaItem` y `PlaybackState` y
  reenvía los comandos del sistema al port; la carátula llega después de la
  metadata (con guarda por `id` contra respuestas tardías).
- `MainActivity` extiende `AudioServiceActivity`.

### Cola

- `PlaybackState.queue` es la **cola real** (con aleatorio, el orden mezclado);
  todos los índices del port se refieren a ella.
- Solo se edita lo que viene después de la actual. `AddToQueue` y `PlayNext`
  empiezan a reproducir si no suena nada.
- El adapter mantiene el orden de las fuentes de just_audio y el de reproducción
  (`QueueShuffleOrder`). Solo se publica la canción actual en la MediaSession.
- `PlaySongs` reemplaza la cola; tocar un resultado de Search reproduce **solo esa
  canción** (las acciones «a continuación» / «a la cola» están en el menú ⋯).

## Lookup: de la identidad a la `Song`

`SongLookup.findAll(identidades)` → `SongLookupResult`: cada identidad cae en
exactamente un cubo: `found`, `missing` (la fuente existe pero no tiene esa
canción; puede volver) o `unsupported` (ninguna fuente registrada). Un fallo real
se lanza como `SongLookupFailure` y **nunca** se convierte en `missing`.

- `SourceSongLookup` enruta por fuente (una consulta por fuente, en paralelo);
  implementaciones: `LocalSongLookup` (biblioteca ya filtrada) y `JamendoSongLookup`
  (`tracksByIds` en lote).
- **Aislamiento por fuente:** `findAllIsolatingSources` consulta una fuente a la
  vez; si una falla, solo sus identidades quedan en `failed` (se ocultan, sin
  reencuentro ni borrado) y las demás se resuelven; si fallan todas se relanza el
  fallo. Lo usan `GetFavoriteSongs` y `GetPlaylistSongs`. El contrato de
  `SongLookup`/`SourceSongLookup` no cambió (el lote de `SourceSongLookup` sigue
  fallando entero para otros consumidores).
- **Favoritos y playlists** resuelven canciones de varias fuentes con ese lookup.
  El permiso de música ya no bloquea las remotas: se pide solo si no hay nada que
  mostrar. El reencuentro (`SongMatcher`) aplica **solo** a identidades locales
  `missing`. `localLibrarySongs(ref)` entrega la biblioteca sin que su estado
  afecte a otras fuentes.

## Artwork

Una carátula es una `ArtworkReference` que `Song.artwork` trae tal como la fuente
la entrega.

```text
Song.artwork (ArtworkReference)
   ↓
ArtworkCache            LRU (200) en memoria por (referencia, px); deduplica;
   │                    local → ArtworkRepository (MediaStore, albumId)
   │                    remota → RemoteArtworkLoader (HttpRemoteArtworkLoader)
   ↓
AlbumArtworkBuilder     resuelve el ImageProvider (ResizeImage, sin ampliar)
   ↓
TakiArtwork             solo presentación
```

- **Local:** `MediaStoreArtworkRepository` lee las miniaturas por el canal
  `taki/media_store`.
- **Remota:** `HttpRemoteArtworkLoader` (sobre `ArtworkHttpClient`/`IoArtworkHttpClient`
  de `dart:io`) valida `http(s)` con host, 10 s, 5 MB y firma de imagen
  (JPEG/PNG/GIF/WebP). Un fallo remoto no se memoiza como ausencia. Una referencia
  remota sin cargador se trata como ausente.
- **Playlists:** `playlistCoverArtworkProvider` combina la biblioteca local (con
  prioridad) con las carátulas de las canciones resueltas por `SongLookup`
  (`remoteCoverArtworkProvider`, una consulta en lote por cambio del conjunto).
  `PlaylistCoverImages` pide las imágenes a los builders.
- **MediaSession / notificación / pantalla de bloqueo:** `ArtworkFileCache`
  (`features/player/infrastructure`) es **independiente** del flujo anterior:
  guarda carátulas como archivo en el cache dir porque el sistema necesita una URI
  `file://`. Local: `album_<id>_<size>.jpg` (por el repositorio). Remota:
  `remote_<FNV-1a 64 de la URL>.img`, con los bytes del mismo `RemoteArtworkLoader`,
  escritura atómica y deduplicación de descargas en vuelo. Sin limpieza propia.
  `main.dart` comparte **una** instancia del cargador entre la UI y esta caché.
- `ArtworkResolver`/`SourceArtworkResolver` existen y están cableados pero **ninguna
  pantalla los consume** (la UI usa `song.artwork`).

## Catálogo y búsqueda

- **Contrato (`core`):** `CatalogSearch.search(CatalogSearchQuery)` →
  `CatalogSearchPage(songs, hasMore, attributions)`; fallo = `CatalogSearchFailure`.
  `CatalogSources` / `SourceCatalogSources` registran las fuentes
  (`CatalogProviderInfo`); `searchIn(source)` devuelve su `CatalogSearch`.
- **`features/search`:** `SearchCatalog` (caso de uso), `CatalogSearchNotifier`
  (controlador) y `CatalogSearchState` (`Idle`, `Typing`, `Loading`, `Results`,
  `Empty`, `Failed`, `Unavailable`). Mínimo 2 caracteres, debounce de 400 ms
  (`SearchScheduler`), páginas de 20, **generación** para descartar respuestas
  obsoletas, deduplicación por `MusicIdentity` (primera aparición gana) y `loadMore`
  por scroll. No reintenta por su cuenta. Con varias fuentes usa la primera
  registrada (**provisional**; no hay selector, mezcla ni ranking).
- `SearchPage` no conoce proveedores: el menú ⋯ de cada fila es el
  `showSongActions` inyectado por el router.
- **Descubrimiento (`core`):** `CatalogBrowse.section(CatalogSection, {limit})` →
  `CatalogSearchPage`; es un puerto aparte porque una fuente puede ser buscable y
  no tener «populares». `CatalogSection` es un valor neutral (`popularThisWeek`,
  `popularThisMonth`, `newReleases` y `genre(tag)`); una fuente que no sabe
  responder una sección devuelve una página vacía, no un fallo.
  `CatalogSourceRegistration` lleva un `browse` opcional y
  `CatalogSources.browseIn(source)` devuelve `null` si la fuente no se puede
  explorar. `GetFeaturedSongs` (caso de uso) pide una sección, deduplica y traduce
  los fallos a `CatalogSearchFailure`.
- **Carruseles:** antes de buscar (`SearchIdle`, o escribiendo sin resultados
  previos), `FeaturedView` muestra una lista vertical de carruseles horizontales
  de `TakiSongCard`, uno por `FeaturedSection` (`defaultFeaturedSections`:
  populares de la semana, del mes, novedades y los géneros rock, electrónica,
  pop, hip hop, jazz y chill). Cada carrusel carga **por separado y de forma
  perezosa** (`featuredSectionSongsProvider`, una familia por `CatalogSection`,
  en caché durante la sesión): uno que falla muestra su propio mensaje con
  «Reintentar» sin afectar a los demás, y uno que llega vacío no se pinta.
  Tocar una card reproduce **la lista de ese carrusel** desde esa canción;
  mantener pulsado abre el menú de acciones; arrastrar hacia abajo refresca todo.
  Si el primer carrusel llega vacío, o no hay fuente explorable, la pantalla
  conserva su vista inactiva de siempre. El estado de reproducción se inyecta
  desde `search_page.dart` (la única excepción entre features sigue siendo ese
  import).
- **Teclado:** al entrar en Buscar el campo **no** pide el foco, para que el
  teclado no tape los carruseles; se abre cuando el usuario toca el campo. Al
  salir de la pestaña el foco se suelta, y al volver no se vuelve a pedir.

## Atribución

- `ProviderAttribution(identity, providerName, pageUrl?, licenseUrl?, licenseName?)`
  es neutral al proveedor y **no** vive en `Song`.
- `AttributionLookup.findAll(identidades)` → `AttributionLookupResult{found, absent}`;
  un fallo real es `AttributionLookupFailure` (nunca se disfraza de ausencia).
  `SourceAttributionLookup` enruta por fuente; `JamendoAttributionLookup` usa
  `tracksByIds`. Nada se persiste.
- `attributionProvider` (familia por `MusicIdentity`, en `player`) alimenta
  `AttributionSection` en Reproduciendo: origen, licencia y los botones «Ver
  canción» / «Ver licencia», solo con URL `http(s)`. Cargando, ausente o fallo: no
  se muestra nada y no se bloquea la reproducción.
- `ExternalLinkOpener` (puerto) / `UrlLauncherLinkOpener` abre el navegador del
  sistema; `openableUrl` solo admite `http(s)` con host.

## Reproduciendo: color, letra, temporizador y ecualizador

Todo cuelga de `features/player` salvo lo que otras features también necesitan.

- **Color dinámico.** `core/utils/dominant_color.dart` (`dominantColor`,
  `backdropTint`) elige el color de una carátula a partir de sus píxeles RGBA
  (cubos de 16 niveles, más peso a lo vivo, sin casi negro ni casi blanco).
  `ArtworkTint` (`core/widgets`) lo lee de la **misma** imagen que ya se dibuja:
  no pide nada más a la caché de carátulas. `NowPlayingPage` lo usa de fondo
  con un degradado animado.
- **Letra.** El puerto `LyricsSource` y `Lyrics`/`LyricLine`/`LyricsQuery`, junto
  con `parseLrc`, viven en `core/domain`; `lyricsProvider` (`core/lyrics`) es un
  `FutureProvider.family` que se sobrescribe en `main`. `features/lyrics`
  solo tiene infraestructura: `LrclibLyricsSource` (`/api/get` y, si no hay
  coincidencia, `/api/search` con tolerancia de duración, prefiriendo la
  sincronizada) sobre el `ArtworkHttpClient` genérico. **Solo se consulta al
  abrir la hoja de letra**, porque envía título y artista a un tercero; la
  pantalla de Ajustes lo declara. La hoja resalta la línea actual con la
  posición del reproductor y un toque en una línea hace seek.
- **Temporizador de sueño.** `SleepTimerController` (`player/presentation`)
  cuenta atrás por segundos o espera el final de la canción (cambio de pista o
  posición a menos de 600 ms del final) y entonces llama a `pause`. No
  persiste: es una acción puntual.
- **Ecualizador.** `EqualizerPort` (dominio del reproductor) y
  `JustAudioEqualizer` sobre `AndroidEqualizer`, que se declara en el
  `AudioPipeline` del `AudioPlayer` creado en `initPlayer`. Android solo informa
  de las bandas tras empezar a reproducir, así que `load()` puede dar `null`
  («no disponible aún») y el controlador vuelve a leer cuando suena una canción.
  `EqualizerPreset` es una curva de cinco puntos que se interpola al número de
  bandas del dispositivo. Los ajustes se guardan en `preferences`.
- **Preferencias.** `PreferencesStore` (`core/domain/ports`) es un
  clave/valor de texto sobre la tabla `preferences` (`SqflitePreferencesStore`).
  Su uso es de mejor esfuerzo: un fallo nunca deshace lo que el usuario oye.

## Historial

La base pasa a v4 con `play_history` (una fila por identidad: última
reproducción y recuento, máximo 200) y `preferences`. `features/library` guarda
el puerto `PlayHistoryRepository`, `SqflitePlayHistoryRepository` y
`GetRecentSongs` (identidades → canciones con el `SongLookup`, de cualquier
fuente; lo que no se resuelve se oculta, no se olvida). El carrusel
«Escuchado recientemente» (`RecentlyPlayedSection`) no ocupa espacio sin
historial. **Quién escribe** es `app/play_history_wiring.dart`, porque solo la
raíz de composición conoce a la vez el reproductor y la biblioteca: así no hace
falta otra excepción entre features.

## Ajustes

`features/settings` sigue la misma estructura hexagonal que el resto. **No hay
preferencias persistidas propias**: cada fila es una acción o información de solo
lectura. (El almacén `preferences` existe, pero hoy solo lo usa el ecualizador.)

- **Dominio** (`domain/`): `AppInfo` (versión, build, plataforma),
  `StorageUsage` (bytes y archivos), los puertos `AppInfoPort` y
  `ArtworkCacheStoragePort` y los casos de uso `GetArtworkCacheUsage` y
  `ClearArtworkCache`. `buildDiagnosticsReport` arma el texto de diagnóstico:
  solo versión, sistema y contadores; nunca títulos, rutas, favoritos,
  nombres de playlist ni credenciales.
- **Infraestructura**: `PackageInfoAppInfo` (`package_info_plus` +
  `device_info_plus`), `FileArtworkCacheStorage` (la carpeta `artwork` del
  directorio temporal, la misma que escribe `ArtworkFileCache`) y
  `registerFontLicenses` (añade las licencias OFL de Sora y DM Sans a la
  pantalla de licencias; se llama en `main`).
- **Presentación**: `SettingsPage` compone cinco secciones con
  `TakiSectionHeader` (grupo) y `TakiSettingsTile` (`core/widgets`): Biblioteca
  (resumen y volver a escanear), Almacenamiento (tamaño y vaciar la caché de
  carátulas, con confirmación), Catálogo en línea (las fuentes de
  `CatalogSources.available` por su etiqueta, sin nombrar a ningún proveedor),
  Privacidad y Acerca de (versión, licencias de código abierto y copiar
  diagnóstico).

Vaciar la caché de carátulas solo borra archivos regenerables: no toca
canciones, favoritos ni playlists.

## Jamendo

`features/jamendo` (domain + infrastructure) es uno de los dos proveedores remotos
(el otro es Audius, abajo). Toda la lógica específica vive ahí; `core` no la
conoce.

- **Credencial:** `JAMENDO_CLIENT_ID` por `--dart-define` (formato validado: 4–64
  `[A-Za-z0-9_-]`). Sin él, Jamendo **no se registra**: no hay pestaña Buscar y la
  app funciona solo con la biblioteca local. El id queda dentro del binario y
  nunca se persiste ni se escribe en logs ni errores.
- **API:** `HttpJamendoApi` (`Uri.https('api.jamendo.com', …)`), 10 s, 4 MB,
  reintenta hasta 3 veces una respuesta vacía; `tracksByIds` en lotes de 50.
  Reutiliza el `ArtworkHttpClient` existente como transporte GET.
- **Descubrimiento:** `JamendoCatalogBrowse` implementa `CatalogBrowse` con
  `JamendoApi.listTracks(order, tag)`: `popularity_week`, `popularity_month`,
  `releasedate_desc` y, para un género, `popularity_week` con `tags=<género>`.
  Pasa por el mismo reintento de respuestas vacías y por la caché de URLs de
  audio.
- **Parser:** decodifica entidades HTML de título/artista/álbum (no de URLs ni ids).
- **Reproducción remota:** `JamendoPlaybackResolver` devuelve `RemoteUriResource`
  con la URL de audio; `JamendoAudioCache` (solo memoria, TTL 10 min, 500) evita
  repetir consultas; **no hay audio ni URLs en disco ni en SQLite** y no hay modo
  offline.
- **Artwork:** `RemoteArtworkReference` con `width=300`.
- **Atribución:** `JamendoTrack.attribution` (`shareurl`, `license_ccurl`; el nombre
  de la licencia se deriva de la URL).
- Las licencias de las pistas son Creative Commons NC en general (uso no comercial).

## Audius

`features/audius` (domain + infrastructure) tiene la misma forma que Jamendo y se
cablea en `app/audius_wiring.dart`. Se registra siempre: no necesita credencial.

- **API:** `HttpAudiusApi` (`api.audius.co`, `app_name=taki`, 10 s, 4 MB).
  `searchTracks`, `trending` (semana/mes, opcional género), `underground` y
  `tracksByIds` (un `id` repetido por pista).
- **Descubrimiento:** semana y mes son los charts `trending`; **Novedades** usa
  `trending/underground` (pistas emergentes y recientes, sin el spam de ordenar por
  fecha); un género se traduce con `audiusGenres` a los nombres cerrados de Audius
  y uno desconocido devuelve una página vacía.
- **Parser:** omite pistas borradas, sin `is_streamable` o con `access.stream`
  falso; `rawCount` cuenta lo recibido para que la paginación no se confunda.
- **Reproducción:** `AudiusPlaybackResolver` comprueba la pista por id (single
  flight por identidad) y devuelve `RemoteUriResource` con
  `/v1/tracks/{id}/stream`. Esa URL redirige a un nodo con firma nueva cada vez,
  así que **no hay nada que caduque ni que cachear**.
- **Artwork:** `RemoteArtworkReference` de 480 px.
- **Atribución:** enlace a `audius.co` solo desde un `permalink` bien formado; la
  licencia es el texto que declaró el artista (`licenseName`, sin `licenseUrl`).
  No se presenta como libre lo que no lo es.
- **Selección de fuente:** `selectedCatalogSourceProvider` guarda la preferencia y
  `activeCatalogSourceProvider` decide la efectiva (la elegida si sigue
  registrada, si no la primera). Los resultados de dos fuentes **no se mezclan**
  (la política multi-fuente D6 sigue abierta). Cambiar de fuente repite la
  búsqueda escrita sobre la nueva.

## `core/theme` y `core/widgets`

`TakiColors` (paleta «Midnight + Taki Orange») y el resto de tokens
(`TakiTypography`, `TakiSpacing`, `TakiRadius`, `TakiElevation`, `TakiMotion`,
`TakiIconSize`) son tokens, no construyen temas; `AppTheme` los compone. Los
widgets `Taki*` (`TakiSongTile`, `TakiButton`, `TakiSearchField`, `TakiArtwork`,
`TakiEmptyState`, `TakiErrorState`, …) son solo presentación (ver
`DESIGN_SYSTEM.md`). `song_actions.dart` define `ExtraSongAction` y el typedef
`ShowSongActions` (la firma del menú que implementa `app/`). Un widget de
`core/widgets` no importa ninguna feature ni `app/`.

## Composition root

**`main.dart`** crea, antes de `runApp`, lo que debe existir desde el arranque y lo
inyecta con overrides de `ProviderScope`:

| Qué crea | Provider que sobrescribe |
|---|---|
| `MediaStoreArtworkRepository` | `artworkRepositoryProvider` |
| Jamendo (si hay `client_id`): `buildJamendoServices` | `jamendoServicesProvider`, `catalogSourcesProvider`, `attributionLookupProvider`, `artworkResolverProvider`, `songLookupProvider` (vía `songLookupOverride`) |
| `HttpRemoteArtworkLoader` (una instancia) | `remoteArtworkLoaderProvider` y `initPlayer` |
| `JustAudioPlayerAdapter` + `TakiAudioHandler` (`initPlayer`, con `SourcePlaybackResolver`) | `audioPlayerPortProvider`, `audioHandlerProvider` |
| `Database` de sqflite (`TakiDatabase.tryOpen`) | `takiDatabaseProvider` (solo si abrió) |

El resto de adapters se cablean en cada feature (`library_providers.dart`,
`favorites_providers.dart`, `playlists_providers.dart`, `player_providers.dart`,
`catalog_search_providers.dart`) con un valor por defecto que los tests
sobrescriben.

## Base de datos local

`core/database/taki_database.dart` abre `taki.db` (sqflite), **versión 3**, con
`PRAGMA foreign_keys = ON`. Si falla, la app arranca igual y favoritos/playlists se
muestran como no disponibles («Reintentar»). Historial: v1 `favorites`; v2
`playlists`/`playlist_songs`; v3 identifica la canción por `source` + `external_id`
(texto) con copia verificada de los datos de v1/v2 (como `source='local'`).
`favorites` tiene clave `(source, external_id)`; `playlist_songs` permite
repetidos. Las columnas `title/artist/album/duration_ms/path` son una copia de
respaldo (`path` solo para locales). Una canción que no se resuelve se **oculta,
no se borra**.

## Fuente local de canciones

`SongRepository` (`library`) → `MediaStoreSongRepository` (canal nativo
`taki/media_store`, `MediaStoreChannel.kt`, registrado como `FlutterPlugin` por
`MainActivity`). `GetSongs` aplica `SongFilter` (descarta < 30 s y carpetas
excluidas).

## Android

- **Permisos** (manifest principal): `INTERNET`, `READ_MEDIA_AUDIO`,
  `READ_EXTERNAL_STORAGE` (`maxSdkVersion 32`), `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `WAKE_LOCK`, `POST_NOTIFICATIONS`. Las
  librerías añaden `ACCESS_NETWORK_STATE`. `<queries>` para `PROCESS_TEXT` y
  `VIEW` http/https (enlaces externos).
- **Servicios:** `com.ryanheise.audioservice.AudioService`
  (`foregroundServiceType=mediaPlayback`) y `MediaButtonReceiver`.
- `minSdk` 24, `targetSdk` 36, `compileSdk` 36, AGP 8.11.1, Kotlin 2.2.20, Java 17.
  `applicationId` `com.limbermendoza.taki`. R8 activo en `release`.
- El tráfico `http://` queda bloqueado por defecto (sin `cleartext`).

## Build, release y firma

Ver `README.md` para los comandos. La firma de producción: la keystore vive
**fuera del repositorio**; `android/key.properties` (local) la describe; ambos están
ignorados por Git. `buildTypes.release` usa `signingConfigs.release` y un release
sin esos datos **falla** (nunca usa la clave de debug). Detalle en
`PHASE_3_9B_PRODUCTION_SIGNING.md`.

## Testing

`test/` replica `lib/` y añade `helpers/` (fakes compartidos) y `architecture/`.
Widget tests con `ProviderScope(overrides: …)` y fakes/`mocktail`; infraestructura
sin dispositivo (adapter con reproductor falso, canal simulado, SQLite en memoria
con `sqflite_common_ffi`, Jamendo con HTTP falso). El mutation testing se hizo
manualmente por fase (resultados en cada `PHASE_3_*`). Sin tests automáticos: el
Kotlin (`MediaStoreChannel`), el comportamiento real de audio_service, la apertura
real de enlaces (`launchUrl`) y todo lo que requiere dispositivo (validado a mano en
la 3.9).

### Test de arquitectura

`test/architecture/dependency_rules_test.dart` (**13 pruebas**) lee los
`import`/`export` de `lib/` y comprueba: (1) que encuentra imports; (2) `core` no
depende de `app` ni de features; (3) las features no dependen de `app`; (4) sin
imports entre features salvo las **8** excepciones; (5) las excepciones siguen
existiendo; (6) `core/domain` solo importa `equatable`; (7–10) `features/search`:
solo importa de otra feature el provider del Player, no importa Jamendo, no depende
de `app` y no menciona a ningún proveedor; (11) `features/player` no importa ni
menciona Jamendo; (12) `features/playlists` tampoco; (13) `search` tiene una única
excepción. **Añadir una excepción** requiere actualizar `_allowedCrossFeature` y la
tabla de este documento.

## Decisiones

- **Persistencia: `sqflite`** (isar no se mantiene y falla con AGP 8+).
- **Lectura de la biblioteca: canal nativo propio (MediaStore)** en lugar de
  `on_audio_query` (abandonado / exige permisos de fotos). Solo se pide
  `READ_MEDIA_AUDIO` (13+) / `READ_EXTERNAL_STORAGE` (≤12).
- **`permission_handler` fijado en 12.x** (la 13.x exige AGP 9) y
  **`device_info_plus`** para elegir el permiso por versión de Android.
- **Cola con `AudioPlayer.setAudioSources`** con `useLazyPreparation`; solo la
  canción actual se publica en la MediaSession.
- **Estado / DI: Riverpod. Navegación: go_router.**
- **Dominio compartido en `core/domain`**: `Song` y lo que la rodea lo usan todas las
  features.
- **Identidad `(source, externalId)` opaca** y persistida como texto; `Song` universal
  y `LocalSong` para lo local (Fases 2.x).
- **Proveedores enchufados desde `app/`** y enrutados por fuente; ninguna feature ni
  `core` nombra a Jamendo.
- **Atribución provider-agnostic en `core`** y sin persistencia.
- **Un solo cargador remoto de carátulas** compartido por la UI y la notificación.
- **Menú de canción inyectado por constructor** (combina tres features, vive en `app/`).

## Limitaciones y deuda conocidas

Hechos, no promesas (detalle en `PHASE_3_8_GLOBAL_POST_3_7B_AUDIT.md` y
`PHASE_3_9_ANDROID_VALIDATION_RELEASE.md`):

- **No implementado:** segunda fuente / selector / mezcla (D6), modo offline, descarga
  de pistas, localización, preferencias persistidas en Ajustes, AAB / Play App
  Signing (no evaluado).
- **No verificado en dispositivo:** UI del lockscreen (el teléfono de prueba no tiene
  bloqueo seguro), auriculares físicos, seek en pistas remotas, muerte del proceso por
  el sistema, persistencia de `remote_*.img` entre reinicios en el release.
- **Deuda técnica:**
  - `addToQueue`/`playNext` comprueban la cola vacía fuera de la serialización del
    adapter.
  - Se resuelven todas las URLs remotas al encolar; las URLs de audio se fijan al
    encolar.
  - `HttpJamendoApi` reintenta hasta 3 veces una respuesta vacía.
  - `RemoteUriResource` / el campo `audio` no validan el esquema.
  - `ArtworkFileCache` no tiene límite ni limpieza.
  - El fallo parcial de una fuente en Favoritos/Playlists es silencioso.
  - `audioHandlerProvider` y `artworkResolverProvider` no tienen lectores.
  - `core/database` conoce el esquema de dos features y
    `core/constants/library_constants.dart` solo lo usa `library`.
  - Algunos comentarios de código dicen «hoy no hay cargador/fuente remota».
- **Deuda de UX observada en Android:** Reproduciendo muestra «REPRODUCIENDO DESDE
  Biblioteca» también para pistas remotas; la pantalla de permiso dice «Nada sale de
  tu dispositivo»; Favoritos queda en error tras un recálculo sin red hasta pulsar
  «Reintentar»; con el permiso denegado la lista de playlists cuenta canciones que el
  detalle oculta.
