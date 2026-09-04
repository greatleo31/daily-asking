package com.dailyasking.daily_asking

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/**
 * 更新机制原生侧（docs/02-版本与更新机制.md §2.4）。
 *
 * - 下载：系统 DownloadManager（通知栏进度、断点续传），下载完成后由动态注册的
 *   BroadcastReceiver 接手。
 * - 完整性：latest.json 提供 sha256 时校验，不匹配则丢弃并提示重试。
 * - 安装：UpdateFileProvider + ACTION_VIEW 引导系统安装页；Android 8+ 未授权时
 *   先引导「安装未知应用」设置页。
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.dailyasking.daily_asking/update"
    private val exportChannelName = "com.dailyasking.daily_asking/export"
    private var downloadReceiver: BroadcastReceiver? = null
    private var pendingSha256: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "downloadAndInstall" -> {
                        val url = call.argument<String>("url") ?: ""
                        val fileName = call.argument<String>("fileName") ?: "liuhen-update.apk"
                        val sha = call.argument<String>("sha256") ?: ""
                        val title = call.argument<String>("title") ?: "留痕更新"
                        if (url.isEmpty()) {
                            result.error("bad_url", "缺少下载地址", null)
                        } else {
                            pendingSha256 = sha.ifEmpty { null }
                            registerReceiverInternal()
                            val enqueued = enqueueDownload(url, fileName, title)
                            if (enqueued) {
                                result.success(true)
                            } else {
                                result.error("enqueue_failed", "更新下载入队失败", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, exportChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareMarkdown" -> shareMarkdown(
                        call.argument<String>("fileName"),
                        call.argument<String>("content"),
                        result
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun enqueueDownload(url: String, fileName: String, title: String): Boolean {
        return try {
            val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            val request = DownloadManager.Request(Uri.parse(url))
                .setTitle(title)
                .setDescription("正在下载更新…")
                .setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
                )
                .setDestinationInExternalFilesDir(
                    this, Environment.DIRECTORY_DOWNLOADS, fileName
                )
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(false)
                .setMimeType("application/vnd.android.package-archive")
            dm.enqueue(request)
            true
        } catch (e: Exception) {
            toast("更新下载失败，请重试")
            false
        }
    }

    /** ACTION_DOWNLOAD_COMPLETE 为系统保护广播，必须在运行时动态注册。 */
    private fun registerReceiverInternal() {
        if (downloadReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return
                val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
                onDownloadComplete(id)
            }
        }
        registerReceiver(receiver, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE))
        downloadReceiver = receiver
    }

    private fun onDownloadComplete(id: Long) {
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val cursor = dm.query(DownloadManager.Query().setFilterById(id))
        if (!cursor.moveToFirst()) {
            cursor.close()
            toast("更新下载失败，请重试")
            return
        }
        val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
        val localUri = cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
        cursor.close()
        if (status != DownloadManager.STATUS_SUCCESSFUL || localUri.isNullOrEmpty()) {
            toast("更新下载失败，请重试")
            return
        }
        val file = File(Uri.parse(localUri).path ?: "")
        if (!file.exists() || file.length() == 0L) {
            toast("更新下载失败，请重试")
            return
        }
        val sha = pendingSha256
        if (!sha.isNullOrEmpty()) {
            val actual = sha256(file)
            if (!actual.equals(sha, ignoreCase = true)) {
                toast("更新文件校验失败，请重试")
                file.delete()
                return
            }
        }
        if (canInstall()) {
            installApk(file)
        } else {
            toast("首次安装请允许“安装未知应用”")
            openInstallPermission()
        }
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buf = ByteArray(64 * 1024)
            while (true) {
                val n = input.read(buf)
                if (n < 0) break
                if (n > 0) digest.update(buf, 0, n)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()

    private fun openInstallPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }

    private fun installApk(file: File) {
        val uri = UpdateFileProvider.contentUri(this, file.name)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }

    /** 导出 Markdown：写入应用外部 Download 目录，再唤起系统分享面板。 */
    private fun shareMarkdown(
        fileName: String?,
        content: String?,
        result: MethodChannel.Result
    ) {
        try {
            val name = fileName ?: "daily-asking.md"
            val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
            val file = File(dir, name)
            file.writeText(content ?: "", Charsets.UTF_8)
            val uri = UpdateFileProvider.contentUri(this, file.name)
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/markdown"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, name)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                clipData = ClipData.newUri(contentResolver, name, uri)
            }
            startActivity(Intent.createChooser(send, "导出 Markdown"))
            result.success(true)
        } catch (e: Exception) {
            toast("导出失败，请重试")
            result.error("export_failed", "导出失败", e.message)
        }
    }

    private fun toast(msg: String) {
        Toast.makeText(this, msg, Toast.LENGTH_LONG).show()
    }

    override fun onDestroy() {
        super.onDestroy()
        downloadReceiver?.let { unregisterReceiver(it) }
        downloadReceiver = null
    }
}