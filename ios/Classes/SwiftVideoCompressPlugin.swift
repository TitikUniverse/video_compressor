import Flutter
import AVFoundation
import UIKit
import Photos

public class SwiftVideoCompressorPlugin: NSObject, FlutterPlugin {
    
    private var eventSink: FlutterEventSink?
    private let channelName = "video_compress"
    private var exporter: AVAssetExportSession? = nil
    private var stopCommand = false
    private let channel: FlutterMethodChannel
    private let avController = AvController()
    
    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "video_compress", binaryMessenger: registrar.messenger())
        let instance = SwiftVideoCompressorPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? Dictionary<String, Any>
        switch call.method {
        case "getByteThumbnail":
            let path = args!["path"] as! String
            let quality = args!["quality"] as! NSNumber
            let position = args!["position"] as! NSNumber
            getByteThumbnail(path, quality, position, result)
        case "getFileThumbnail":
            let path = args!["path"] as! String
            let quality = args!["quality"] as! NSNumber
            let position = args!["position"] as! NSNumber
            getFileThumbnail(path, quality, position, result)
        case "getMediaInfo":
            let path = args!["path"] as! String
            getMediaInfo(path, result)
        case "compressVideo":
            let path = args!["path"] as! String
            let quality = args!["quality"] as! NSNumber
            let width = args!["width"] as! Int
            let height = args!["height"] as! Int
            let bps = args!["bps"] as! Int
            let deleteOrigin = args!["deleteOrigin"] as! Bool
            let startTime = args!["startTime"] as? Double
            let duration = args!["duration"] as? Double
            let includeAudio = args!["includeAudio"] as? Bool
            let saveInGallery = args!["saveInGallery"] as? Bool
            let frameRate = args!["frameRate"] as? Int
//            compressVideo(path, quality, bps, deleteOrigin, startTime, duration, includeAudio,
//                          frameRate, result)
            
            let desPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString).mp4")
            try? FileManager.default.removeItem(at: desPath)
            compressVideo(
                Utility.getPathUrl(path),
                desPath,
                width,
                height,
                bps,
                false,
                false,
                .main,
                { progress in
                      DispatchQueue.main.async { [unowned self] in
                          if(self.eventSink != nil){
                              let progress = Float(progress.fractionCompleted * 100)
                              if(progress <= 100) {
                                  self.eventSink!(progress)
                              }
                          }
                      }
                  },
//                  completion: { compressionResult in
//                      switch compressionResult {
//                          case .onSuccess(let path):
//                              if(saveInGallery!) {
//                                  DispatchQueue.main.async {
//                                      PHPhotoLibrary.shared().performChanges({
//                                          PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: path)
//                                      })
//                                  }
//                              }
//                              let response: [String: String] = ["onSuccess": path.path]
//                              result(response)
//
//                          case .onStart: break
//
//                          case .onFailure(let error):
//                              let response: [String: String] = ["onFailure": error.title]
//                              result(response)
//
//                          case .onCancelled:
//                              let response: [String: Bool] = ["onCancelled": true]
//                              result(response)
//                      }
//                  }
                result)
        case "cancelCompression":
            cancelCompression(result)
        case "deleteAllCache":
            Utility.deleteFile(Utility.basePath(), clear: true)
            result(true)
        case "setLogLevel":
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func getBitMap(_ path: String,_ quality: NSNumber,_ position: NSNumber,_ result: FlutterResult)-> Data?  {
        let url = Utility.getPathUrl(path)
        let asset = avController.getVideoAsset(url)
        guard let track = avController.getTrack(asset) else { return nil }
        
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        
        let timeScale = CMTimeScale(track.nominalFrameRate)
        let time = CMTimeMakeWithSeconds(Float64(truncating: position),preferredTimescale: timeScale)
        guard let img = try? assetImgGenerate.copyCGImage(at:time, actualTime: nil) else {
            return nil
        }
        let thumbnail = UIImage(cgImage: img)
        let compressionQuality = CGFloat(0.01 * Double(truncating: quality))
        return thumbnail.jpegData(compressionQuality: compressionQuality)
    }
    
    private func getByteThumbnail(_ path: String,_ quality: NSNumber,_ position: NSNumber,_ result: FlutterResult) {
        if let bitmap = getBitMap(path,quality,position,result) {
            result(bitmap)
        }
    }
    
    private func getFileThumbnail(_ path: String,_ quality: NSNumber,_ position: NSNumber,_ result: FlutterResult) {
        let fileName = Utility.getFileName(path)
        let url = Utility.getPathUrl("\(Utility.basePath())/\(fileName).jpg")
        Utility.deleteFile(path)
        if let bitmap = getBitMap(path,quality,position,result) {
            guard (try? bitmap.write(to: url)) != nil else {
                return result(FlutterError(code: channelName,message: "getFileThumbnail error",details: "getFileThumbnail error"))
            }
            result(Utility.excludeFileProtocol(url.absoluteString))
        }
    }
    
    public func getMediaInfoJson(_ path: String)->[String : Any?] {
        let url = Utility.getPathUrl(path)
        let asset = avController.getVideoAsset(url)
        guard let track = avController.getTrack(asset) else { return [:] }
        
        let playerItem = AVPlayerItem(url: url)
        let metadataAsset = playerItem.asset
        
        let orientation = avController.getVideoOrientation(path)
        
        let title = avController.getMetaDataByTag(metadataAsset,key: "title")
        let author = avController.getMetaDataByTag(metadataAsset,key: "author")
        
        let duration = asset.duration.seconds * 1000
        let filesize = track.totalSampleDataLength
        
        let size = track.naturalSize.applying(track.preferredTransform)
        
        let width = abs(size.width)
        let height = abs(size.height)
        let bitrate = round(track.estimatedDataRate)
        
        let dictionary = [
            "path":Utility.excludeFileProtocol(path),
            "title":title,
            "author":author,
            "width":width,
            "height":height,
            "bitrate":bitrate,
            "duration":duration,
            "filesize":filesize,
            "orientation":orientation
            ] as [String : Any?]
        return dictionary
    }
    
    private func getMediaInfo(_ path: String,_ result: FlutterResult) {
        let json = getMediaInfoJson(path)
        let string = Utility.keyValueToJson(json)
        result(string)
    }
    
    private func statusUpdateJson(_ status: String)->[String : Any?]{
        let dictionary = [
            "Status": status
            ] as [String : Any?]
        return dictionary
    }
    
    private func getStatusUpdate(_ status: String,_ result: FlutterResult) {
        let json = statusUpdateJson(status)
        let string = Utility.keyValueToJson(json)
        result(string)
    }
    
    @objc private func updateProgress(timer:Timer) {
        let asset = timer.userInfo as! AVAssetExportSession
        if(!stopCommand) {
            channel.invokeMethod("updateProgress", arguments: "\(String(describing: asset.progress * 100))")
        }
    }
    
    private func getExportPreset(_ quality: NSNumber)->String {
        switch(quality) {
        case 1:
            return AVAssetExportPreset1920x1080
        case 2:
            return AVAssetExportPreset1280x720
        case 3:
            return AVAssetExportPresetMediumQuality
        default:
            return AVAssetExportPreset1280x720
        }
    }
    
    private func getComposition(_ isIncludeAudio: Bool,_ timeRange: CMTimeRange, _ sourceVideoTrack: AVAssetTrack)->AVAsset {
        let composition = AVMutableComposition()
        if !isIncludeAudio {
            let compressionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
            compressionVideoTrack!.preferredTransform = sourceVideoTrack.preferredTransform
            try? compressionVideoTrack!.insertTimeRange(timeRange, of: sourceVideoTrack, at: CMTime.zero)
        } else {
            return sourceVideoTrack.asset!
        }
        
        return composition    
    }
    
    // Deprecated
    private func compressVideo(_ path: String,_ quality: NSNumber,_ bRate: Int?,_ deleteOrigin: Bool,_ startTime: Double?,
                               _ duration: Double?,_ includeAudio: Bool?,_ frameRate: Int?,
                               _ result: @escaping FlutterResult) {
        let sourceVideoUrl = Utility.getPathUrl(path)
        let sourceVideoType = "mp4"
        
        let sourceVideoAsset = avController.getVideoAsset(sourceVideoUrl)
        let sourceVideoTrack = avController.getTrack(sourceVideoAsset)
        
        let compressionUrl =
            Utility.getPathUrl("\(Utility.basePath())/\(Utility.getFileName(path)).\(sourceVideoType)")
        
        let timescale = sourceVideoAsset.duration.timescale
        let minStartTime = Double(startTime ?? 0)
        
        let videoDuration = sourceVideoAsset.duration.seconds
        let minDuration = Double(duration ?? videoDuration)
        let maxDurationTime = minStartTime + minDuration < videoDuration ? minDuration : videoDuration
        
        let cmStartTime = CMTimeMakeWithSeconds(minStartTime, preferredTimescale: timescale)
        let cmDurationTime = CMTimeMakeWithSeconds(maxDurationTime, preferredTimescale: timescale)
        let timeRange: CMTimeRange = CMTimeRangeMake(start: cmStartTime, duration: cmDurationTime)
        
        let isIncludeAudio = includeAudio != nil ? includeAudio! : true
        
        let session = getComposition(isIncludeAudio, timeRange, sourceVideoTrack!)
        
        let exporter = AVAssetExportSession(asset: session, presetName: getExportPreset(quality))!
        
        exporter.outputURL = compressionUrl
        exporter.outputFileType = AVFileType.mp4
        exporter.shouldOptimizeForNetworkUse = true
        
        if frameRate != nil {
            let videoComposition = AVMutableVideoComposition(propertiesOf: sourceVideoAsset)
            videoComposition.frameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate!))
            exporter.videoComposition = videoComposition
        }
        
        if !isIncludeAudio {
            exporter.timeRange = timeRange
        }
        
        Utility.deleteFile(compressionUrl.absoluteString)
        
        let timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateProgress),
                                         userInfo: exporter, repeats: true)
        
        exporter.exportAsynchronously(completionHandler: {
            timer.invalidate()
            if(self.stopCommand) {
                self.stopCommand = false
                var json = self.getMediaInfoJson(path)
                json["isCancel"] = true
                let jsonString = Utility.keyValueToJson(json)
                return result(jsonString)
            }
            if deleteOrigin {
                let fileManager = FileManager.default
                do {
                    if fileManager.fileExists(atPath: path) {
                        try fileManager.removeItem(atPath: path)
                    }
                    self.exporter = nil
                    self.stopCommand = false
                }
                catch let error as NSError {
                    print(error)
                }
            }
            var json = self.getMediaInfoJson(compressionUrl.absoluteString)
            json["isCancel"] = false
            let jsonString = Utility.keyValueToJson(json)
            result(jsonString)
        })
    }

    
    func checkFileSize(sizeUrl: URL, message:String){
        let data = NSData(contentsOf: sizeUrl)!
        print(message, (Double(data.length) / 1048576.0), " mb")
    }
    
    private func cancelCompression(_ result: FlutterResult) {
        exporter?.cancelExport()
        stopCommand = true
        result("")
    }
    
    /**
     * This function compresses a given [source] video file and writes the compressed video file at
     * [destination]
     *
     * @param [source] the path of the provided video file to be compressed
     * @param [destination] the path where the output compressed video file should be saved
     * @param [quality] to allow choosing a video quality that can be [.very_low], [.low],
     * [.medium],  [.high], and [very_high]. This defaults to [.medium]
     * @param [isMinBitRateEnabled] to determine if the checking for a minimum bitrate threshold
     * before compression is enabled or not. This default to `true`
     * @param [keepOriginalResolution] to keep the original video height and width when compressing.
     * This defaults to `false`
     * @param [progressHandler] a compression progress  listener that listens to compression progress status
     * @param [completion] to return completion status that can be [onStart], [onSuccess], [onFailure],
     * and if the compression was [onCancelled]
     */

    public func compressVideo(_ source: URL,
                              _ destination: URL,
                              _ tWidth: Int,
                              _ tHeight: Int,
                              _ bps: Int,
                              _ isMinBitRateEnabled: Bool = true,
                              _ keepOriginalResolution: Bool = false,
                              _ progressQueue: DispatchQueue,
                              _ progressHandler: ((Progress) -> ())?,
                              _ result: @escaping FlutterResult) -> Compression {

        var frameCount = 0
        let compressionOperation = Compression()

        // Compression started
//        completion(.onStart)
        
//        self.getStatusUpdate("Start to compress ...", result)

        let videoAsset = AVURLAsset(url: source)
        guard let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first else {
            let error = CompressionError(title: "Cannot find video track")
//            completion(.onFailure(error))
            self.getStatusUpdate("Cannot find video track", result)
            return Compression()
        }

//        let bitrate = videoTrack.estimatedDataRate

        // Generate a bitrate based on desired quality
//        let newBitrate = getBitrate(bitrate: bitrate, quality: quality)
        let newBitrate = bps

        // Handle new width and height values
        // let videoSize = videoTrack.naturalSize
        let newWidth = tWidth
        let newHeight = tHeight

        // Total Frames
        let durationInSeconds = videoAsset.duration.seconds
        let frameRate = videoTrack.nominalFrameRate
        let totalFrames = ceil(durationInSeconds * Double(frameRate))

        // Progress
        let totalUnits = Int64(totalFrames)
        let progress = Progress(totalUnitCount: totalUnits)
        
        // Setup video writer input
        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: getVideoWriterSettings(bitrate: newBitrate, width: newWidth, height: newHeight))
        videoWriterInput.expectsMediaDataInRealTime = true
        videoWriterInput.transform = videoTrack.preferredTransform

        let videoWriter = try! AVAssetWriter(outputURL: destination, fileType: AVFileType.mov)
        videoWriter.add(videoWriterInput)

        // Setup video reader output
        let videoReaderSettings:[String : AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) as AnyObject
        ]
        let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoReaderSettings)

        var videoReader: AVAssetReader!
        do{
            videoReader = try AVAssetReader(asset: videoAsset)
        }
        catch {
            let compressionError = CompressionError(title: error.localizedDescription)
//            completion(.onFailure(compressionError))
            self.getStatusUpdate("Cannot find video track", result)
        }

        videoReader.add(videoReaderOutput)
        //setup audio writer
        let audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: nil)
        audioWriterInput.expectsMediaDataInRealTime = false
        videoWriter.add(audioWriterInput)
        //setup audio reader
        let audioTrack = videoAsset.tracks(withMediaType: AVMediaType.audio).first
        var audioReader: AVAssetReader?
        var audioReaderOutput: AVAssetReaderTrackOutput?
        if(audioTrack != nil) {
            audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack!, outputSettings: nil)
            audioReader = try! AVAssetReader(asset: videoAsset)
            audioReader?.add(audioReaderOutput!)
        }
        videoWriter.startWriting()

        //start writing from video reader
        videoReader.startReading()
        videoWriter.startSession(atSourceTime: CMTime.zero)
        let processingQueue = DispatchQueue(label: "processingQueue1")

        var isFirstBuffer = true
        videoWriterInput.requestMediaDataWhenReady(on: processingQueue, using: {() -> Void in
            while videoWriterInput.isReadyForMoreMediaData {

                // Observe any cancellation
                if compressionOperation.cancel {
                    videoReader.cancelReading()
                    videoWriter.cancelWriting()
//                    completion(.onCancelled)
                    self.getStatusUpdate("Cancelled", result)
                    return
                }

                // Update progress based on number of processed frames
                frameCount += 1
                if let handler = progressHandler {
                    progress.completedUnitCount = Int64(frameCount)
                    progressQueue.async { handler(progress) }
                }

                let sampleBuffer: CMSampleBuffer? = videoReaderOutput.copyNextSampleBuffer()

                if videoReader.status == .reading && sampleBuffer != nil {
                    videoWriterInput.append(sampleBuffer!)
                } else {
                    videoWriterInput.markAsFinished()
                    if videoReader.status == .completed {
                        if(audioReader != nil){
                            if(!(audioReader!.status == .reading) || !(audioReader!.status == .completed)){
                                //start writing from audio reader
                                audioReader?.startReading()
                                videoWriter.startSession(atSourceTime: CMTime.zero)
                                let processingQueue = DispatchQueue(label: "processingQueue2")

                                audioWriterInput.requestMediaDataWhenReady(on: processingQueue, using: {() -> Void in
                                    while audioWriterInput.isReadyForMoreMediaData {
                                        let sampleBuffer: CMSampleBuffer? = audioReaderOutput?.copyNextSampleBuffer()
                                        if audioReader?.status == .reading && sampleBuffer != nil {
                                            if isFirstBuffer {
                                                let dict = CMTimeCopyAsDictionary(CMTimeMake(value: 1024, timescale: 44100), allocator: kCFAllocatorDefault);
                                                CMSetAttachment(sampleBuffer as CMAttachmentBearer, key: kCMSampleBufferAttachmentKey_TrimDurationAtStart, value: dict, attachmentMode: kCMAttachmentMode_ShouldNotPropagate);
                                                isFirstBuffer = false
                                            }
                                            audioWriterInput.append(sampleBuffer!)
                                        } else {
                                            audioWriterInput.markAsFinished()

                                            videoWriter.finishWriting(completionHandler: {() -> Void in
//                                                completion(.onSuccess(destination))
                                                self.getMediaInfo(destination.absoluteString, result)
                                            })

                                        }
                                    }
                                })
                            }
                        } else {
                            videoWriter.finishWriting(completionHandler: {() -> Void in
//                                completion(.onSuccess(destination))
                                self.getMediaInfo(destination.absoluteString, result)
                            })
                        }
                    }
                }
            }
        })
        
        return compressionOperation
    }
    
    private func getBitrate(bitrate: Float, quality: VideoQuality) -> Int {
        
        if quality == .RES1080 {
            return 1024 * 1024 * 3
        } else {
            return 1024 * 1024 * 2
        }
    }
    
    private func getVideoWriterSettings(bitrate: Int, width: Int, height: Int) -> [String : AnyObject] {
        
        let videoWriterCompressionSettings = [
            AVVideoAverageBitRateKey : bitrate
        ]
        
        let videoWriterSettings: [String : AnyObject] = [
            AVVideoCodecKey : AVVideoCodecType.h264 as AnyObject,
            AVVideoCompressionPropertiesKey : videoWriterCompressionSettings as AnyObject,
            AVVideoWidthKey : width as AnyObject,
            AVVideoHeightKey : height as AnyObject
        ]
        
        return videoWriterSettings
    }
    
    public enum VideoQuality {
        case RES1080
        case RES720
        case RESLOWER
    }

    // Compression Result
    public enum CompressionResult {
        case onStart
        case onSuccess(URL)
        case onFailure(CompressionError)
        case onCancelled
    }

    // Compression Interruption Wrapper
    public class Compression {
        public init() {}

        public var cancel = false
    }

    // Compression Error Messages
    public struct CompressionError: LocalizedError {
        public let title: String

        init(title: String = "Compression Error") {
            self.title = title
        }
    }
    
}
