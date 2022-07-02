import '../../video_compressor.dart';

class CompressionConfig {

  bool isCompressionNeeded = true;
  String? tips;
  int? targetWidth;
  int? targetHeight;
  int? targetBps;
  VideoQuality? targetQuality;

  CompressionConfig(String mimeType,
      double originDuration,
      int originFileSize,
      int originWidth,
      int originHeight,
      int originBps){

    if(mimeType!="video/mp4" && mimeType!="video/mov" && mimeType!="video/quicktime"){
      isCompressionNeeded = false;
      tips = "e01";
      return;
    }

    if ( (originDuration / 1000).round() > 302){
      isCompressionNeeded = false;
      tips = "e02";
      return;
    }

    if (originWidth < 360 && originHeight <360){
      isCompressionNeeded = false;
      tips = "e03";
      return;
    }

    if (originFileSize < 1024 * 1024 * 10){
      isCompressionNeeded = false;
      tips = "e04";
      return;
    }

    // Normal resolution: 720 x 1280
    targetQuality = VideoQuality.NormalResQuality;
    targetBps = 1024 * 1024 * 2;
    targetWidth = 720;
    targetHeight = 1280;

    if ( originWidth >= 1920 || originHeight >= 1920 ){
      // 1080
      if (originBps > 1024 * 1024 * 3){
        targetQuality = VideoQuality.HighResQuality;
        targetBps = 1024 * 1024 * 3;
        if (originWidth >= originHeight){
          targetWidth = 1920;
          targetHeight = (originHeight * 1920 / originWidth).round();
        } else {
          targetHeight = 1920;
          targetWidth = (originWidth * 1920 / originHeight).round();
        }
      }else {
        isCompressionNeeded = false;
        tips = "e05";
        return;
      }
    } else if ( originWidth < 720 && originHeight < 720 ){
      // 360 - 720
      if (originBps > 1024 * 1024 * 2){
        targetQuality = VideoQuality.LowResQuality;
        targetWidth = originWidth;
        targetHeight = originHeight;
      } else {
        isCompressionNeeded = false;
        tips = "e06";
        return;
      }
    } else {
      // 720
      if (originBps > 1024 * 1024 * 2){
        if (originWidth >= originHeight){
          targetHeight = 720;
          targetWidth = (originWidth * 720 / originHeight).round();
        } else {
          targetWidth = 720;
          targetHeight = (originHeight * 720 / originWidth).round();
        }
      } else {
        isCompressionNeeded = false;
        tips = "e07";
        return;
      }
    }

  }

}
