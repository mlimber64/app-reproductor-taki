# Fase 3.4 — Resolución remota de Favoritos y detalle de playlist

Corrige el `REAL_LEAK 1` de la auditoría 3.3 y endurece el aislamiento de fallos
por fuente **en la resolución de Favoritos y Playlists**. No toca Player, Cola,
MediaSession, `MusicIdentity`, `Song`, SQLite, artwork ni el contrato de
`SongLookup`.

## 1. Problema original

`FavoritesPage` y `PlaylistDetailPage` mostraban «Taki necesita acceso a tu
música» siempre que el permiso de MediaStore estuviera denegado, antes de
resolver nada. Un usuario sin ese permiso no veía ni reproducía sus canciones
`jamendo:<id>`. Además, `favoriteSongsProvider`/`playlistItemsProvider` esperaban
`songsProvider.future` (si el escaneo local fallaba, todo fallaba) y
`SourceSongLookup` hace fallar el lote entero si **una** fuente falla.

## 2. Comportamiento anterior (verificado en el código y los tests)

| Escenario (lote `local:42` + `jamendo:123`) | Antes |
|---|---|
| Permiso local + Jamendo bien | ambas |
| **Sin permiso local** + Jamendo bien | **pantalla de permiso, nada resuelto** |
| Escaneo/lectura local falla + Jamendo bien | error de página (todo falla) |
| Jamendo falla + local bien | error de página (todo falla) |

## 3. Solución

1. **Presentación (permiso).** El permiso ya no es una puerta previa. Las páginas
   resuelven primero; la pantalla de permiso se muestra solo si **no hay nada que
   mostrar** y la biblioteca necesita permiso (comportamiento previo para quien
   solo tiene canciones locales).
2. **`localLibrarySongs(ref)`** (`songs_notifier.dart`): la biblioteca local usada
   para el reencuentro de canciones locales nunca lanza (sin permiso, vacía o con
   error → lista vacía) y sigue observando `songsProvider`.
3. **`findAllIsolatingSources`** (`core/domain/services/isolated_song_lookup.dart`):
   consulta el `SongLookup` **una fuente a la vez** (en paralelo). Si una fuente
   lanza `SongLookupFailure`, sus identidades quedan en `failed`; las demás se
   resuelven. Si **todas** las fuentes consultadas fallan, relanza el fallo (la
   página muestra su estado de error existente, como antes).
4. `GetFavoriteSongs` y `GetPlaylistSongs` usan ese helper: las identidades
   `failed` se **ocultan sin reencuentro, sin `relink` y sin borrado**, y nunca
   pasan a `missing`.

`SongLookup`, `SongLookupResult` y `SourceSongLookup` **no cambian** (el lote de
`SourceSongLookup` sigue fallando entero; ya nadie lo consume sin aislar: solo
estos dos casos de uso llaman a `songLookupProvider`).

## 4. Favoritos / 5. Detalle de playlist

| Caso | Ahora |
|---|---|
| Solo `jamendo:123`, sin permiso | se muestra y se reproduce |
| Mixtos con permiso | ambas |
| Mixtos sin permiso | la remota se muestra; la local no (regla de la fuente local, sin borrar) |
| Solo locales sin permiso | pantalla de permiso (como antes) |
| Jamendo falla + local ok | se muestra la local; la remota se oculta, no se borra |
| Local falla + Jamendo ok | se muestra la remota |
| Todas las fuentes fallan | estado de error existente |

Playlists conservan orden, posiciones (las entradas ocultas dejan hueco en la
numeración guardada, como antes) y duplicados. Sin UI nueva ni «Reintentar» nuevo.

## 6. Source isolation: alcance y límites

Resuelto para Favoritos y Playlists, **sin cambiar el contrato**. El fallo parcial
queda **silencioso**: la UI no distingue «oculta por fallo» de «no existe».
Pendiente (deuda separada, PHASE 3.5/3.8): comunicar el fallo parcial al usuario,
reintento y aislamiento dentro de `SourceSongLookup` para otros consumidores.

## 7. Identidad

Sin cambios: `local:42`, `jamendo:42` y `jamendo:0042` son identidades distintas;
`externalId` no se convierte a número; no se usa `Song.id`. Tests: `0042` se
resuelve, se persiste intacto, no se relinka y el lookup recibe exactamente esa
identidad.

## 8. Tests

- `test/core/domain/services/isolated_song_lookup_test.dart` (9): agrupación por
  fuente, `failed`, fallo ≠ `missing`, todas fallan → lanza, `unsupported`.
- `test/features/library/domain/song_lookup_resolution_test.dart`: los dos tests
  que fijaban «el fallo tumba el lote» se sustituyeron por los nuevos
  (remota falla, local falla, fallo ≠ `missing` sin reencuentro ni relink, todas
  fallan, solo remotas sin consultar la local); orden/duplicados de playlist.
- `test/features/library/presentation/remote_favorites_playlists_test.dart` (A–F, H en
  Favoritos y Playlist Detail, página real con fuente de prueba etiquetada
  `jamendo`): sin permiso, mixtos con/sin permiso, fallo de cada fuente, todas
  fallan, reencuentro local por biblioteca, identidad `0042`, reproducción.
- Los tests existentes de permiso de ambas páginas siguen pasando sin cambios.

## 9. Mutation testing (17 mutantes)

Un mutante (biblioteca siempre vacía) sobrevivió inicialmente por falta de un test
de reencuentro local a través del provider; se añadió el test y se repitió.

- **Killed: 12** (agrupación única, `failed` vacío, lanzar en parcial, `every→any`,
  perder el merge, fallo→`missing`, error de biblioteca propagado, biblioteca
  siempre vacía —tras añadir el test de reencuentro—, permiso que bloquea siempre
  en ambas páginas, y esperar la biblioteca en ambos providers).
- **Survived reales: 0.**
- **Survived esperados: 3**: atajo de «sin identidades» (equivalente: el resultado
  es el mismo sin él); y quitar el `continue` de `failed` en los dos casos de uso
  (equivalente: una identidad `failed` no está en `found` ni en `missing`, así que
  igualmente se omite; el `continue` es defensa explícita).
- **Compile-invalid: 2** (`songs.isEmpty && false` / `items.isEmpty && false`
  dejan inalcanzable una promoción de tipo); no cuentan como killed. Ese
  comportamiento («solo locales sin permiso → pide permiso») lo cubren sus tests.

## 10. Riesgos y puntos diferidos

- Fallo parcial silencioso (§6).
- Latencia: los providers esperan el escaneo local (instantáneo sin permiso) antes
  de resolver; las fuentes se consultan en paralelo entre sí, no con el escaneo.
- Con permiso denegado, los favoritos/entradas **locales** quedan ocultos sin
  aviso si hay también remotas (no se muestra el aviso de permiso).
- P2 (errores de reproducción), P3–P5, portadas de playlist y carátula de
  lockscreen siguen pendientes (otras fases).
- **Validación en Android: pendiente** (sin dispositivo); lo anterior está
  verificado solo con tests automáticos.
