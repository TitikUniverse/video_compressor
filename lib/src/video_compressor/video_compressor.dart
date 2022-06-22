import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../progress_callback/compress_mixin.dart';
import '../video_compressor/video_quality.dart';
import 'compression_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../media/media_info.dart';

abstract class IVideoCompressor extends CompressMixin {}

class _VideoCompressorImpl extends IVideoCompressor {
  _VideoCompressorImpl._() {
    initProcessCallback();
  }

  static _VideoCompressorImpl? _instance;

  static _VideoCompressorImpl get instance {
    return _instance ??= _VideoCompressorImpl._();
  }

  static void _dispose() {
    _instance = null;
  }
}

// ignore: non_constant_identifier_names
IVideoCompressor get VideoCompressor => _VideoCompressorImpl.instance;

extension Compress on IVideoCompressor {
  void dispose() {
    _VideoCompressorImpl._dispose();
  }

  Future<T?> _invoke<T>(String name, [Map<String, dynamic>? params]) async {
    T? result;
    try {
      result = params != null ? await channel.invokeMethod(name, params) : await channel.invokeMethod(name);
    } on PlatformException catch (e) {
      debugPrint('''Error from VideoCompressor:
      Method: $name
      $e''');
    }
    return result;
  }

  /// getByteThumbnail return [Future<Uint8List>],
  /// quality can be controlled by [quality] from 1 to 100,
  /// select the position unit in the video by [position] is milliseconds
  Future<Uint8List?> getByteThumbnail(
    String path, {
    int quality = 100,
    int position = -1,
  }) async {
    assert(quality > 1 || quality < 100);

    return await _invoke<Uint8List>('getByteThumbnail', {
      'path': path,
      'quality': quality,
      'position': position,
    });
  }

  /// getFileThumbnail return [Future<File>]
  /// quality can be controlled by [quality] from 1 to 100,
  /// select the position unit in the video by [position] is milliseconds
  Future<File> getFileThumbnail(
    String path, {
    int quality = 100,
    int position = -1,
  }) async {
    assert(quality > 1 || quality < 100);

    // Not to set the result as strong-mode so that it would have exception to
    // lead to the failure of compression
    final filePath = await (_invoke<String>('getFileThumbnail', {
      'path': path,
      'quality': quality,
      'position': position,
    }));

    final file = File(filePath!);

    return file;
  }

  /// get media information from [path]
  ///
  /// get media information from [path] return [Future<MediaInfo>]
  ///
  /// ## example
  /// ```dart
  /// final info = await _flutterVideoCompressor.getMediaInfo(file.path);
  /// debugPrint(info.toJson());
  /// ```
  Future<MediaInfo> getMediaInfo(String path) async {
    // Not to set the result as strong-mode so that it would have exception to
    // lead to the failure of compression
    final jsonStr = await (_invoke<String>('getMediaInfo', {'path': path}));
    final jsonMap = json.decode(jsonStr!);
    return MediaInfo.fromJson(jsonMap);
  }

  /// compress video from [path]
  /// compress video from [path] return [Future<MediaInfo>]
  ///
  /// you can choose its quality by [quality],
  /// determine whether to delete his source file by [deleteOrigin]
  /// bitrate decided by [bRate]
  /// optional parameters [startTime] [duration] [includeAudio] [frameRate]
  ///
  /// ## example
  /// ```dart
  /// final info = await _flutterVideoCompressor.compressVideo(
  ///   file.path,
  ///   deleteOrigin: true,
  /// );
  /// debugPrint(info.toJson());
  /// ```
  ///
  ///

  ///
  ///
  Future<MediaInfo?> compressVideo(
    String path, {
    VideoQuality quality = VideoQuality.NormalResQuality,
    int? width,
    int? height,
    int? bps = 1024 * 1024 * 3,
    bool deleteOrigin = false,
    int? startTime,
    int? duration,
    bool? includeAudio = true,
    bool? saveInGallery = false,
    int frameRate = 30,
  }) async {
    if (isCompressing) {
      throw StateError('''VideoCompressor Error:
      Method: compressVideo
      Already have a compression process, you need to wait for the process to finish or stop it''');
    }

    if (compressProgress$.notSubscribed) {
      debugPrint('''VideoCompressor: You can try to subscribe to the
      compressProgress\$ stream to know the compressing state.''');
    }
    // ignore: invalid_use_of_protected_member
    setProcessingStatus(true);
    final jsonStr = await _invoke<String>('compressVideo', {
      'path': path,
      'quality': quality.index,
      'width': width,
      'height': height,
      'bps': bps,
      'deleteOrigin': deleteOrigin,
      'startTime': startTime,
      'duration': duration,
      'includeAudio': includeAudio,
      'saveInGallery': saveInGallery,
      'frameRate': frameRate,
    });

    // if (response['onSuccess'] != null) {
    //   return OnSuccess(response['onSuccess']);
    // } else if (response['onFailure'] != null) {
    //   return OnFailure(response['onFailure']);
    // } else if (response['onCancelled'] != null) {
    //   return OnCancelled(response['onCancelled']);
    // } else {
    //   return const OnFailure('Something went wrong');
    // }

    // ignore: invalid_use_of_protected_member
    setProcessingStatus(false);

    if (jsonStr != null) {
      final jsonMap = json.decode(jsonStr);
      return MediaInfo.fromJson(jsonMap);
    } else {
      return null;
    }
  }

  /// Call this function to cancel video compression process.
  // Future<Map<String, dynamic>?> cancelCompression() async =>
  //     jsonDecode(await channel.invokeMethod<dynamic>('cancelCompression'));

  /// stop compressing the file that is currently being compressed.
  /// If there is no compression process, nothing will happen.
  Future<void> cancelCompression() async {
    await _invoke<void>('cancelCompression');
  }

  /// delete the cache folder, please do not put other things
  /// in the folder of this plugin, it will be cleared
  Future<bool?> deleteAllCache() async {
    return await _invoke<bool>('deleteAllCache');
  }

  Future<void> setLogLevel(int logLevel) async {
    return await _invoke<void>('setLogLevel', {
      'logLevel': logLevel,
    });
  }
}
