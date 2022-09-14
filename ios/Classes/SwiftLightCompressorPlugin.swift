import Flutter
import UIKit
import Photos

public class SwiftLightCompressorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    // private var compression: Compression? = nil

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "titik_compressor", binaryMessenger: registrar.messenger())
        let instance = SwiftLightCompressorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let eventChannel = FlutterEventChannel(name: "compression/stream", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance.self)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startCompression":
            if let myArgs = call.arguments as? [String: Any?],
               let path : String = myArgs["path"] as? String,
               let bps : Int = myArgs["bps"] as? Int,
               let width : Int = myArgs["width"] as? Int,
               let height : Int = myArgs["height"] as? Int
            {
                // Bitrate constrains
                if (bps < 1024 * 1024 * 3) {
                    let response: [String: String] = ["onSuccess": path]
                    result(response.toJson)
                }

                // Compression
                let config = FYVideoCompressor.CompressionConfig(videoBitrate: bps,
                                                videomaxKeyFrameInterval: 10,
                                                fps: 30,
                                                audioSampleRate: 44100,
                                                audioBitrate: 128_000,
                                                fileType: .mp4,
                                                scale: CGSize(width: width, height: height))
                FYVideoCompressor().compressVideo(URL(fileURLWithPath: path), config: config) { r in
                    switch r {
                    case .success(let compressedVideoURL): 
                        let response: [String: String] = ["onSuccess": compressedVideoURL.path]
                        result(response.toJson)
                    case .failure(let error): 
                        let response: [String: String] = ["onFailure": error.localizedDescription]
                        result(response.toJson)
                    }
                }
            }
        default:
            let response: [String: String] = ["onFailure": "Method is not defined!"]
            result(response.toJson)
        }
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    // private func getVideoQuality(quality: String) -> VideoQuality{
    //     switch quality {
    //     case "very_low":
    //         return VideoQuality.very_low
    //     case "low":
    //         return VideoQuality.low
    //     case "medium":
    //         return VideoQuality.medium
    //     case "high":
    //         return VideoQuality.high
    //     case "very_high":
    //         return VideoQuality.very_high
    //     default:
    //         return VideoQuality.medium
    //     }
    // }
    
}
