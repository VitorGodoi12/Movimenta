package com.vitorgodoi.movimenta

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissao: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AlertasEstoque.criarCanal(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stokio/alertas").setMethodCallHandler { call, result ->
            when (call.method) {
                "sincronizar" -> {
                    AlertasEstoque.sincronizar(this, call.argument<Int>("baixo") ?: 0,
                        call.argument<List<String>>("datas") ?: emptyList(), call.argument<Int>("dias") ?: 7)
                    result.success(null)
                }
                "permitido" -> result.success(AlertasEstoque.permitido(this))
                "ativar" -> {
                    if (permissao != null) result.success(false)
                    else if (Build.VERSION.SDK_INT >= 33 && !AlertasEstoque.permitido(this) &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                        permissao = result
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
                    } else result.success(AlertasEstoque.permitido(this))
                }
                "configuracoes" -> {
                    val intent = if (Build.VERSION.SDK_INT >= 26)
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    startActivity(intent)
                    result.success(null)
                }
                "testar" -> result.success(AlertasEstoque.testar(this))
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        AlertasEstoque.verificar(this)
        AlertasEstoque.agendar(this)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 101) {
            AlertasEstoque.agendar(this)
            permissao?.success(AlertasEstoque.permitido(this))
            permissao = null
        }
    }
}
