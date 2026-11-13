package com.example.mackeupai

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Seguridad (fugas de datos, M6/M9): FLAG_SECURE en las pantallas que muestran el rostro.
        // Bloquea capturas y grabaciones de pantalla y oculta la vista previa en "apps recientes".
        // Lo controla lib/core/utils/pantalla_segura.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mackeupai/pantalla_segura")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "activar" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "desactivar" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
