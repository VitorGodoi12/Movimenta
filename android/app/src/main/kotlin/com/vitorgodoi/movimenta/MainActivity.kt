package com.vitorgodoi.movimenta

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private var fotoPendente: MethodChannel.Result? = null
    private var permissao: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AlertasEstoque.criarCanal(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "movimenta/perfil").setMethodCallHandler { call, result ->
            if (call.method != "escolherFoto") {
                result.notImplemented()
            } else if (fotoPendente != null) {
                result.error("ocupado", "Já existe uma seleção aberta.", null)
            } else {
                fotoPendente = result
                try {
                    startActivityForResult(
                        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "image/*"
                        },
                        102
                    )
                } catch (_: ActivityNotFoundException) {
                    fotoPendente = null
                    result.error("seletor", "Não foi possível abrir as fotos.", null)
                }
            }
        }
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

    @Deprecated("Retorno do seletor de arquivos do Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 102) return
        val resposta = fotoPendente ?: return
        fotoPendente = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            resposta.success(null)
            return
        }
        Thread {
            try {
                val imagem = lerAvatar(uri)
                val bytes = ByteArrayOutputStream().use { buffer ->
                    check(imagem.compress(Bitmap.CompressFormat.JPEG, 86, buffer))
                    buffer.toByteArray()
                }
                runOnUiThread { resposta.success(bytes) }
            } catch (_: Exception) {
                runOnUiThread { resposta.error("imagem", "Não foi possível ler a foto.", null) }
            }
        }.start()
    }

    private fun lerAvatar(uri: Uri): Bitmap {
        val limite = 384
        if (Build.VERSION.SDK_INT >= 28) {
            return ImageDecoder.decodeBitmap(ImageDecoder.createSource(contentResolver, uri)) { decoder, info, _ ->
                val maior = maxOf(info.size.width, info.size.height)
                if (maior > limite) {
                    decoder.setTargetSize(
                        maxOf(1, info.size.width.toLong().times(limite).div(maior).toInt()),
                        maxOf(1, info.size.height.toLong().times(limite).div(maior).toInt())
                    )
                }
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
        }
        val opcoes = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opcoes) }
        check(opcoes.outWidth > 0 && opcoes.outHeight > 0)
        opcoes.inSampleSize = 1
        val maior = maxOf(opcoes.outWidth, opcoes.outHeight)
        while (maior / opcoes.inSampleSize > limite) opcoes.inSampleSize *= 2
        opcoes.inJustDecodeBounds = false
        return checkNotNull(contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opcoes) })
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
