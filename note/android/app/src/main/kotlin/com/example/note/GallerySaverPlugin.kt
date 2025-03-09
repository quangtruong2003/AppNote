package com.example.note

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class GallerySaverPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "app_note/gallery_saver")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "saveImageToGallery" -> {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    val savedSuccessfully = saveImageToGallery(filePath)
                    result.success(savedSuccessfully)
                } else {
                    result.error("INVALID_ARGUMENT", "Path must not be null", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun saveImageToGallery(filePath: String): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveImageWithMediaStore(filePath)
        } else {
            saveImageLegacy(filePath)
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun saveImageWithMediaStore(filePath: String): Boolean {
        val file = File(filePath)
        val filename = file.name
        val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, filename)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }

        val contentResolver = context.contentResolver
        val imageUri = contentResolver.insert(collection, values) ?: return false

        try {
            contentResolver.openOutputStream(imageUri)?.use { outputStream ->
                FileInputStream(file).use { inputStream ->
                    inputStream.copyTo(outputStream)
                }
            }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(imageUri, values, null, null)
            return true
        } catch (e: IOException) {
            contentResolver.delete(imageUri, null, null)
            return false
        }
    }

    private fun saveImageLegacy(filePath: String): Boolean {
        try {
            val pictures = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            val appDir = File(pictures, "NotesApp")
            if (!appDir.exists()) {
                appDir.mkdirs()
            }

            val file = File(filePath)
            val destFile = File(appDir, file.name)
            file.copyTo(destFile, overwrite = true)

            // Notify gallery about new image
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DATA, destFile.absolutePath)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            }
            context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            return true
        } catch (e: IOException) {
            e.printStackTrace()
            return false
        }
    }
}
