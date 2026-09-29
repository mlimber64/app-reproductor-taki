package com.limbermendoza.taki

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Extiende AudioServiceActivity para compartir el FlutterEngine con el servicio
 * de reproducción (sigue vivo aunque se cierre la Activity).
 */
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // El engine sobrevive a la Activity: registrar el canal una sola vez.
        if (!flutterEngine.plugins.has(MediaStoreChannel::class.java)) {
            flutterEngine.plugins.add(MediaStoreChannel())
        }
    }
}
