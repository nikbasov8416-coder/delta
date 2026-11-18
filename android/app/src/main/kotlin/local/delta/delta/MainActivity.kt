package local.delta.delta

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "delta/security")
            .setMethodCallHandler { call, result ->
                if (call.method == "setProtected") {
                    if (call.arguments as? Boolean != false) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else { result.notImplemented() }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "delta/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "version" -> {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        @Suppress("DEPRECATION")
                        val build = if (Build.VERSION.SDK_INT >= 28) {
                            info.longVersionCode.toString()
                        } else {
                            info.versionCode.toString()
                        }
                        result.success(mapOf("version" to info.versionName, "build" to build))
                    }
                    "open", "save" -> {
                        if (document != null) {
                            result.error("busy", "Диалог выбора файла уже открыт.", null)
                            return@setMethodCallHandler
                        }
                        val saving = call.method == "save"
                        val name = call.argument<String>("name")
                        val extension = call.argument<String>("extension")
                        val bytes = call.argument<ByteArray>("bytes")
                        val max = call.argument<Int>("maximum")
                        if (saving && (name == null || bytes == null || extension !in setOf("delta", "xlsx")) ||
                            !saving && (max == null || max !in 1..MAX_BACKUP_BYTES)) {
                            result.error("arguments", "Некорректные параметры файла.", null)
                            return@setMethodCallHandler
                        }
                        val intent = if (saving) {
                            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                type = if (extension == "xlsx") {
                                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                                } else {
                                    "application/octet-stream"
                                }
                                putExtra(Intent.EXTRA_TITLE, name)
                            }
                        } else {
                            Intent(Intent.ACTION_OPEN_DOCUMENT).apply { type = "*/*" }
                        }
                        intent.addCategory(Intent.CATEGORY_OPENABLE)
                        document = DocumentRequest(result, bytes, max ?: 0)
                        try {
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, DOCUMENT_REQUEST)
                        } catch (_: Exception) {
                            document = null
                            result.error("document", "Не удалось открыть системный диалог.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private data class DocumentRequest(
        val result: MethodChannel.Result,
        val bytes: ByteArray?,
        val maximum: Int,
    )

    private var document: DocumentRequest? = null

    @Deprecated("Системный выбор документа для FlutterActivity.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != DOCUMENT_REQUEST) return
        val request = document ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            document = null
            request.result.success(null)
            return
        }
        Thread {
            try {
                val value: Any = if (request.bytes != null) {
                    val output = contentResolver.openOutputStream(uri, "wt")
                        ?: throw IOException("Документ недоступен")
                    output.use { it.write(request.bytes) }
                    true
                } else {
                    val input = contentResolver.openInputStream(uri)
                        ?: throw IOException("Документ недоступен")
                    input.use {
                        val output = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            if (output.size() + count > request.maximum) {
                                throw IOException("Файл слишком большой")
                            }
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    }
                }
                runOnUiThread {
                    document = null
                    request.result.success(value)
                }
            } catch (_: Exception) {
                runOnUiThread {
                    document = null
                    request.result.error("document", "Не удалось прочитать или сохранить файл.", null)
                }
            }
        }.start()
    }

    companion object {
        private const val DOCUMENT_REQUEST = 4672
        private const val MAX_BACKUP_BYTES = 64 * 1024 * 1024
    }
}
