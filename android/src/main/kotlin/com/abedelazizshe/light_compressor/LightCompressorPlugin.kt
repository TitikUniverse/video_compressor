package com.abedelazizshe.light_compressor

import android.content.Context
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.Looper
import com.abedelazizshe.lightcompressorlibrary.CompressionListener
import com.abedelazizshe.lightcompressorlibrary.VideoCompressor
import com.abedelazizshe.lightcompressorlibrary.VideoQuality
import com.abedelazizshe.lightcompressorlibrary.config.Configuration
import com.abedelazizshe.lightcompressorlibrary.config.StorageConfiguration
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import org.jetbrains.annotations.NotNull

/** LightCompressorPlugin */
class LightCompressorPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        const val CHANNEL = "titik_compressor"
        const val STREAM = "compression/stream"
    }

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val gson = Gson()
    private lateinit var _context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        _context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, STREAM)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startCompression" -> {
                val path: String = call.argument<String>("path")!!
                val isMinBitrateCheckEnabled: Boolean = call.argument<Boolean>("isMinBitrateCheckEnabled")!!
                val bps: Int? = call.argument<Int?>("bps")
                val width: Double? = call.argument<Double?>("width")
                val height: Double? = call.argument<Double?>("height")

                val quality: VideoQuality =
                    when (call.argument<String>("videoQuality")!!) {
                        "very_low" -> VideoQuality.VERY_LOW
                        "low" -> VideoQuality.LOW
                        "medium" -> VideoQuality.MEDIUM
                        "high" -> VideoQuality.HIGH
                        "very_high" -> VideoQuality.VERY_HIGH
                        else -> VideoQuality.MEDIUM
                    }

                compressVideo(
                    path,
                    result,
                    quality,
                    width,
                    height,
                    bps,
                    isMinBitrateCheckEnabled
                )
            }
            "cancelCompression" -> {
                VideoCompressor.cancel()
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun compressVideo(
        path: String,
        result: MethodChannel.Result,
        quality: VideoQuality,
        width: Double?,
        height: Double?,
        bps: Int?,
        isMinBitrateCheckEnabled: Boolean,
    ) {
        VideoCompressor.start(
            context = _context,
            uris = listOf(Uri.parse(path)),
            isStreamable = true,
            storageConfiguration = StorageConfiguration(
                saveAt = Environment.DIRECTORY_MOVIES, // => the directory to save the compressed video(s). Will be ignored if isExternal = false.
                isExternal = true // => false means save at app-specific file directory. Default is true.
                // fileName = "output-video.mp4" // => an optional value for a custom video name.
            ),
            configureWith = Configuration(
                quality = quality,
                isMinBitrateCheckEnabled = isMinBitrateCheckEnabled,
                videoBitrate = bps ?: 3677198,
                disableAudio = false, /*Boolean, or ignore*/
                keepOriginalResolution = false, /*Boolean, or ignore*/
                videoWidth = width, /*Double, ignore, or null*/
                videoHeight = height /*Double, ignore, or null*/
            ),
            listener = object : CompressionListener {
                override fun onProgress(index: Int, percent: Float) {
                    Handler(Looper.getMainLooper()).post {
                        eventSink?.success(percent)
                    }
                }

                override fun onStart(index: Int) {}

                override fun onSuccess(index: Int, size: Long, path: String?) {
                    result.success(
                        gson.toJson(
                            buildResponseBody(
                                "onSuccess",
                                path ?: ""
                            )
                        )
                    )
                }

                override fun onFailure(index: Int, failureMessage: String) {
                    result.success(
                        gson.toJson(
                            buildResponseBody(
                                "onFailure",
                                failureMessage
                            )
                        )
                    )
                }

                override fun onCancelled(index: Int) {
                    Handler(Looper.getMainLooper()).post {
                        result.success(
                            gson.toJson(
                                buildResponseBody(
                                    "onCancelled",
                                    true
                                )
                            )
                        )
                    }
                }
            },
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun buildResponseBody(
        tag: String,
        response: Any
    ): Map<String, Any> = mapOf(tag to response)

}
