package com.limbermendoza.taki

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Canal "taki/media_store": lectura de la biblioteca local vía MediaStore.
 *
 * - querySongs → List<Map> con id, title, artist, album, albumId, duration,
 *   dateAdded, data, folder y contentUri (solo canciones, ver [querySongs]).
 * - getArtwork(albumId, size) → ByteArray (JPEG) o null si no hay carátula.
 *
 * Es un FlutterPlugin ligado al engine (no a la Activity): el servicio de
 * reproducción lo usa para las carátulas aunque la app esté cerrada.
 * Todo el trabajo corre en un pool de hilos; las respuestas vuelven al hilo
 * principal, como exige MethodChannel.
 */
class MediaStoreChannel : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "taki/media_store"
        private const val DEFAULT_ARTWORK_SIZE = 256
        private const val JPEG_QUALITY = 90
    }

    private lateinit var context: Context
    private var channel: MethodChannel? = null
    private var executor: ExecutorService? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        executor = Executors.newFixedThreadPool(3)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        executor?.shutdownNow()
        executor = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "querySongs" -> runInBackground(result) { querySongs() }
            "getArtwork" -> {
                val albumId = call.argument<Number>("albumId")?.toLong()
                if (albumId == null) {
                    result.error("invalid_args", "albumId es obligatorio", null)
                    return
                }
                val size = call.argument<Number>("size")?.toInt() ?: DEFAULT_ARTWORK_SIZE
                runInBackground(result) { getArtwork(albumId, size) }
            }
            else -> result.notImplemented()
        }
    }

    private fun runInBackground(result: MethodChannel.Result, task: () -> Any?) {
        val pool = executor ?: return result.error("detached", "Canal desconectado", null)
        pool.execute {
            try {
                val value = task()
                mainHandler.post { result.success(value) }
            } catch (e: SecurityException) {
                mainHandler.post { result.error("permission_denied", e.message, null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("media_store_error", e.message, null) }
            }
        }
    }

    private fun audioCollection(): Uri =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

    /**
     * Solo canciones: IS_MUSIC y, según la versión de Android, fuera tonos,
     * notificaciones, alarmas, podcasts, audiolibros (10+) y grabaciones (12+).
     * Cada fila incluye la carpeta ("folder") para filtrar por carpeta en Dart.
     */
    @Suppress("DEPRECATION") // DATA sigue siendo útil como ruta informativa.
    private fun querySongs(): List<Map<String, Any?>> {
        val collection = audioCollection()
        val available = availableColumns(collection)
        val relativePathColumn =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                MediaStore.Audio.Media.RELATIVE_PATH in available
            ) {
                MediaStore.Audio.Media.RELATIVE_PATH
            } else {
                null
            }

        val projection = listOfNotNull(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.DATA,
            relativePathColumn,
        ).toTypedArray()
        val songs = mutableListOf<Map<String, Any?>>()

        context.contentResolver.query(collection, projection, songSelection(available), null, null)
            ?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val albumIdCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
                val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val dateAddedCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
                val dataCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
                val relativePathCol = relativePathColumn?.let { cursor.getColumnIndexOrThrow(it) }

                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val data = cursor.getString(dataCol)
                    val relativePath = relativePathCol?.let { cursor.getString(it) }
                    songs.add(
                        mapOf(
                            "id" to id,
                            "title" to cursor.getString(titleCol),
                            "artist" to cursor.getString(artistCol),
                            "album" to cursor.getString(albumCol),
                            "albumId" to if (cursor.isNull(albumIdCol)) null else cursor.getLong(albumIdCol),
                            "duration" to cursor.getLong(durationCol),
                            "dateAdded" to cursor.getLong(dateAddedCol),
                            "data" to data,
                            "folder" to (relativePath?.takeIf { it.isNotBlank() } ?: parentFolder(data)),
                            "contentUri" to ContentUris.withAppendedId(collection, id).toString(),
                        )
                    )
                }
            }
        return songs
    }

    /**
     * Columnas que existen en este dispositivo (consulta sin filas). Si falla,
     * no se aplican exclusiones y la consulta principal sigue funcionando.
     */
    private fun availableColumns(collection: Uri): Set<String> = try {
        context.contentResolver.query(collection, null, "1 = 0", null, null)
            ?.use { it.columnNames.toSet() }
            ?: emptySet()
    } catch (e: Exception) {
        emptySet()
    }

    private fun songSelection(available: Set<String>): String {
        val excluded = buildList {
            add(MediaStore.Audio.AudioColumns.IS_RINGTONE)
            add(MediaStore.Audio.AudioColumns.IS_NOTIFICATION)
            add(MediaStore.Audio.AudioColumns.IS_ALARM)
            add(MediaStore.Audio.AudioColumns.IS_PODCAST)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                add(MediaStore.Audio.AudioColumns.IS_AUDIOBOOK)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                add(MediaStore.Audio.AudioColumns.IS_RECORDING)
            }
        }.filter { it in available }

        // NULL = desconocido: no se excluye por eso.
        return (listOf("${MediaStore.Audio.Media.IS_MUSIC} != 0") +
            excluded.map { "IFNULL($it, 0) = 0" }).joinToString(" AND ")
    }

    /** Carpeta que contiene el archivo, a partir de su ruta (Android 7–9). */
    private fun parentFolder(data: String?): String =
        data?.substringBeforeLast('/', missingDelimiterValue = "") ?: ""

    private fun getArtwork(albumId: Long, size: Int): ByteArray? {
        val bitmap = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val albumUri = ContentUris.withAppendedId(
                    MediaStore.Audio.Albums.EXTERNAL_CONTENT_URI,
                    albumId,
                )
                context.contentResolver.loadThumbnail(albumUri, Size(size, size), null)
            } else {
                legacyAlbumArt(context.contentResolver, albumId, size)
            }
        } catch (e: IOException) {
            null // El álbum no tiene carátula (FileNotFoundException) o no se pudo leer.
        } ?: return null

        return ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
            bitmap.recycle()
            out.toByteArray()
        }
    }

    /** Android 7-9: content://media/external/audio/albumart/<albumId>. */
    private fun legacyAlbumArt(resolver: ContentResolver, albumId: Long, size: Int): Bitmap? {
        val uri = ContentUris.withAppendedId(
            Uri.parse("content://media/external/audio/albumart"),
            albumId,
        )

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            ?: return null
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sample = 1
        while (bounds.outWidth / (sample * 2) >= size && bounds.outHeight / (sample * 2) >= size) {
            sample *= 2
        }
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
    }
}
