package com.dstk.video_compressor

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.app.Activity
import android.util.Log
import com.otaliastudios.transcoder.Transcoder
import com.otaliastudios.transcoder.TranscoderListener
import com.otaliastudios.transcoder.source.TrimDataSource
import com.otaliastudios.transcoder.source.UriDataSource
import com.otaliastudios.transcoder.strategy.DefaultAudioStrategy
import com.otaliastudios.transcoder.strategy.DefaultVideoStrategy
import com.otaliastudios.transcoder.strategy.RemoveTrackStrategy
import com.otaliastudios.transcoder.strategy.TrackStrategy
import com.otaliastudios.transcoder.strategy.size.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import com.otaliastudios.transcoder.internal.Logger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Future

/**
 * VideoCompressorPlugin
 */
class VideoCompressorPlugin : MethodCallHandler, FlutterPlugin, EventChannel.StreamHandler, ActivityAware{

    companion object {
        const val CHANNEL = "video_compress"
        const val STREAM = "video_compress/stream"
    }

    private lateinit var _methodChannel: MethodChannel
    private lateinit var _eventChannel: EventChannel
    private var _eventSink: EventChannel.EventSink? = null
    private lateinit var _activity: Activity

    private var _context: Context? = null
    private val TAG = "VideoCompressorPlugin"
    private val LOG = Logger(TAG)
    private var transcodeFuture: Future<Void>? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = _context;
        val channel = _methodChannel;

        if (context == null || channel == null) {
            Log.w(TAG, "Calling VideoCompress plugin before initialization")
            return
        }

        when (call.method) {
            "getByteThumbnail" -> {
                val path = call.argument<String>("path")
                val quality = call.argument<Int>("quality")!!
                val position = call.argument<Int>("position")!! // to long
                ThumbnailUtility(CHANNEL).getByteThumbnail(path!!, quality, position.toLong(), result)
            }
            "getFileThumbnail" -> {
                val path = call.argument<String>("path")
                val quality = call.argument<Int>("quality")!!
                val position = call.argument<Int>("position")!! // to long
                ThumbnailUtility("video_compress").getFileThumbnail(context, path!!, quality,
                        position.toLong(), result)
            }
            "getMediaInfo" -> {
                val path = call.argument<String>("path")
                result.success(Utility(CHANNEL).getMediaInfoJson(context, path!!).toString())
            }
            "deleteAllCache" -> {
                result.success(Utility(CHANNEL).deleteAllCache(context, result));
            }
            "setLogLevel" -> {
                val logLevel = call.argument<Int>("logLevel")!!
                Logger.setLogLevel(logLevel)
                result.success(true);
            }
            "cancelCompression" -> {
                transcodeFuture?.cancel(true)
                result.success(false);
            }
            "compressVideo" -> {
                val path = call.argument<String>("path")!!
                val quality = call.argument<Int>("quality")!!
                val width = call.argument<Int>("width")!!
                val height = call.argument<Int>("height")!!
                val bps = call.argument<Long>("bps")!!
                val deleteOrigin = call.argument<Boolean>("deleteOrigin")!!
                val startTime = call.argument<Int>("startTime")
                val duration = call.argument<Int>("duration")
                val includeAudio = call.argument<Boolean>("includeAudio") ?: true
                val saveInGallery = call.argument<Boolean>("saveInGallery") ?: false
                val frameRate = if (call.argument<Int>("frameRate")==null) 30 else call.argument<Int>("frameRate")

                val tempDir: String = context.getExternalFilesDir("video_compress")!!.absolutePath
                val out = SimpleDateFormat("yyyy-MM-dd hh-mm-ss").format(Date())
                val destPath: String = tempDir + File.separator + "VID_" + out + ".mp4"

                val audioTrackStrategy: TrackStrategy
                var videoTrackStrategy: TrackStrategy = DefaultVideoStrategy
                    .exact(width, height)
                    .bitRate(bps)
                    .build()
/*
                when (quality) {

                    0 -> {
                      videoTrackStrategy = DefaultVideoStrategy
                          .exact(720, 1280)
                          .bitRate(1024 * 1024 * 2.toLong())
                          .build()
                    }

                    1 -> {
                        videoTrackStrategy = DefaultVideoStrategy.atMost(360).build()
                    }
                    2 -> {
                        videoTrackStrategy = DefaultVideoStrategy.atMost(640).build()
                    }
                    3 -> {

                        assert(value = frameRate != null)
                        videoTrackStrategy = DefaultVideoStrategy.Builder()
                                .keyFrameInterval(3f)
                                .bitRate(1280 * 720 * 4.toLong())
                                .frameRate(frameRate!!) // will be capped to the input frameRate
                                .build()
                    }
                    4 -> {
                        videoTrackStrategy = DefaultVideoStrategy.atMost(480, 640).build()
                    }
                    5 -> {
                        videoTrackStrategy = DefaultVideoStrategy.atMost(540, 960).build()
                    }
                    6 -> {
                        videoTrackStrategy = DefaultVideoStrategy.atMost(720, 1280).build()
                    }
                    7 -> {
                        videoTrackStrategy = DefaultVideoStrategy.atMost(1080, 1920).build()
                    }
                }
*/
                audioTrackStrategy = if (includeAudio) {
                    val sampleRate = DefaultAudioStrategy.SAMPLE_RATE_AS_INPUT
                    val channels = DefaultAudioStrategy.CHANNELS_AS_INPUT

                    DefaultAudioStrategy.builder()
                        .channels(channels)
                        .sampleRate(sampleRate)
                        .build()
                } else {
                    RemoveTrackStrategy()
                }

                val dataSource = if (startTime != null || duration != null){
                    val source = UriDataSource(context, Uri.parse(path))
                    TrimDataSource(source, (1000 * 1000 * (startTime ?: 0)).toLong(), (1000 * 1000 * (duration ?: 0)).toLong())
                }else{
                    UriDataSource(context, Uri.parse(path))
                }


                transcodeFuture = Transcoder.into(destPath!!)
                        .addDataSource(dataSource)
                        .setAudioTrackStrategy(audioTrackStrategy)
                        .setVideoTrackStrategy(videoTrackStrategy)
                        .setListener(object : TranscoderListener {
                            override fun onTranscodeProgress(progress: Double) {
//                                channel.invokeMethod("updateProgress", progress * 100.00)
                                Handler(Looper.getMainLooper()).post {
                                    _eventSink?.success(progress * 100.00)
                                }
                            }
                            override fun onTranscodeCompleted(successCode: Int) {

                                Handler(Looper.getMainLooper()).post {
                                    _eventSink?.success(100.00)
                                }
//                                channel.invokeMethod("updateProgress", 100.00)
                                val json = Utility(CHANNEL).getMediaInfoJson(context, destPath)
                                json.put("isCancel", false)
                                result.success(json.toString())
                                if (deleteOrigin) {
                                    File(path).delete()
                                }
                            }

                            override fun onTranscodeCanceled() {
                                result.success(null)
                            }

                            override fun onTranscodeFailed(exception: Throwable) {
                                result.success(null)
                            }
                        }).transcode()
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        init(binding.applicationContext, binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        _context = null
        _methodChannel?.setMethodCallHandler(null)
        _eventChannel?.setStreamHandler(null)
    }

    private fun init(context: Context, messenger: BinaryMessenger) {

        _context = context

        val mChannel = MethodChannel(messenger, CHANNEL)
        mChannel.setMethodCallHandler(this)
        _methodChannel = mChannel

        val eChannel = EventChannel(messenger, STREAM)
        eChannel.setStreamHandler(this)
        _eventChannel = eChannel
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        _eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        _eventSink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this._activity = binding.activity
    }
    override fun onDetachedFromActivity() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this._activity = binding.activity
    }
    override fun onDetachedFromActivityForConfigChanges() {}

//    companion object {
//        private const val TAG = "video_compress"
//
//        @JvmStatic
//        fun registerWith(registrar: Registrar) {
//            val instance = VideoCompressorPlugin()
//            instance.init(registrar.context(), registrar.messenger())
//        }
//    }

}
