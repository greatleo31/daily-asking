package com.dailyasking.daily_asking

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File
import java.io.FileNotFoundException

/**
 * 更新 APK 的 FileProvider（自定义实现，避免 androidx FileProvider 传递依赖不确定）。
 *
 * 只暴露本应用外部文件目录 `Android/data/<pkg>/files/Download/` 下的文件，
 * 供 ACTION_VIEW 安装流程读取；文件名为 `liuhen-<version>.apk`。
 *
 * authority 与 AndroidManifest 中 `${applicationId}.fileprovider` 对应。
 */
class UpdateFileProvider : ContentProvider() {
    companion object {
        private const val AUTHORITY_SUFFIX = ".fileprovider"

        /** 构造可安装的 content:// URI（供 MainActivity 调用）。 */
        fun contentUri(context: Context, fileName: String): Uri = Uri.Builder()
            .scheme("content")
            .authority("${context.packageName}$AUTHORITY_SUFFIX")
            .appendPath(fileName)
            .build()

        private fun downloadsDir(context: Context): File = File(
            context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: context.filesDir,
            ""
        )
    }

    override fun onCreate(): Boolean = true

    override fun getType(uri: Uri): String? {
        val name = uri.lastPathSegment ?: return null
        return if (name.endsWith(".md", ignoreCase = true)) {
            "text/markdown"
        } else if (name.endsWith(".json", ignoreCase = true)) {
            "application/json"
        } else {
            "application/vnd.android.package-archive"
        }
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw FileNotFoundException("仅支持只读")
        val file = resolveFile(uri)
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    private fun resolveFile(uri: Uri): File {
        val ctx = requireNotNull(context)
        val name = uri.lastPathSegment ?: throw FileNotFoundException("空文件名")
        val directory = downloadsDir(ctx).canonicalFile
        val file = File(directory, name).canonicalFile
        if (uri.authority != "${ctx.packageName}.fileprovider" ||
            uri.pathSegments.size != 1 || file.parentFile != directory ||
            !file.isFile || !file.canRead()) {
            throw FileNotFoundException("文件不可读取")
        }
        return file
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?
    ): Cursor {
        val file = resolveFile(uri)
        val columns = (projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE))
            .filter { it == OpenableColumns.DISPLAY_NAME || it == OpenableColumns.SIZE }
        val values = columns.map { column ->
            when (column) {
                OpenableColumns.DISPLAY_NAME -> file.name
                else -> file.length()
            }
        }
        return MatrixCursor(columns.toTypedArray(), 1).apply {
            addRow(values.toTypedArray())
        }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?
    ): Int = 0
}