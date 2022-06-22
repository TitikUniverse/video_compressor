import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compressor/video_compressor.dart';
import 'package:file_selector/file_selector.dart';
import 'package:video_meta_info/video_meta_info.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

import './video_thumbnail.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Video compression experiment'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _counter = "video";
  final videoInfo = VideoMetaInfo();

  int _duration = 0;
  int _compRate = 0;
  String _sizeChange = "";
  String _name = "";
  String _compressedFile = "";
  String _tips = "";

  _compressVideo() async {

/*
    // Pick file
    XFile? file = await ImagePicker().pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(seconds: 302));

    if (file==null) {
      return;
    }
*/

    _reload();

    // Lets the user pick one file; files with any file extension can be selected
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);

    // The result will be null, if the user aborted the dialog
    if(result == null) {
      return;
    }
    File file = File(result.files.first.path!);

    var a = await videoInfo.getVideoInfo(file.path);

    if (a == null){
      return;
    }

    if(a.mimetype!="video/mp4" && a.mimetype!="video/mov" && a.mimetype!="video/quicktime"){
      setState(() {
        _tips = "暂不支持您所选视频类型";
      });
      return;
    }

    if ( (a.duration! / 1000).round() > 302){
      setState(() {
      _tips = "多鱼App鼓励您将每段视频长度控制在5分钟内";
      });
      return;
    }

    if (a.width! < 360 && a.height! <360){
      setState(() {
        _tips = "您的视频像素过低，请帮助我们维护平台视频质量。谢谢！";
      });
      return;
    }

    if (a.filesize! < 1024 * 1024 * 30){
      setState(() {
        _tips = "视频小于30MB无需压缩";
      });
      return;
    }

    var isCompressNeeded = false;

    // Normal resolution: 720 x 1280
    var targetQuality = VideoQuality.NormalResQuality;
    var targetBps = 1024 * 1024 * 2;
    var targetWidth = 720;
    var targetHeight = 1280;

    if ( a.width! >= 1920 || a.height! >= 1920 ){
      // 1080
      if (a.bitrate! > 1024 * 1024 * 3){
        isCompressNeeded = true;
        targetQuality = VideoQuality.HighResQuality;
        targetBps = 1024 * 1024 * 3;
        if (a.width! >= a.height!){
          targetWidth = 1920;
          targetHeight = (a.height! * 1920 / a.width!).round();
        } else {
          targetHeight = 1920;
          targetWidth = (a.width! * 1920 / a.height!).round();
        }
      }else {
        setState(() {
          _tips = "1080x1920像素，大小合适，无需压缩";
        });
        return;
      }
    } else if ( a.width! < 720 && a.height! < 720 ){
      // 360 - 720
      if (a.bitrate! > 1024 * 1024 * 2){
        isCompressNeeded = true;
        targetQuality = VideoQuality.LowResQuality;
        targetWidth = a.width!;
        targetHeight = a.height!;
      } else {
        setState(() {
          _tips = "低画质，大小合适，无需压缩";
        });
        return;
      }
    } else {
      // 720
      if (a.bitrate! > 1024 * 1024 * 2){
        isCompressNeeded = true;
        if (a.width! >= a.height!){
          targetHeight = 720;
          targetWidth = (a.width! * 720 / a.height!).round();
        } else {
          targetWidth = 720;
          targetHeight = (a.height! * 720 / a.width!).round();
        }
      } else {
        setState(() {
          _tips = "720x1280像素，大小合适，无需压缩";
        });
        return;
      }
    }

    // Keep the original orientation
    // if (a.orientation == 90 || a.orientation == 270) {
    //   var temp = targetHeight;
    //   targetHeight = targetWidth;
    //   targetWidth = temp;
    // }

    if (targetWidth > targetHeight){
      if ((targetWidth - targetHeight) < 5){
        return;
      }
    } else {
      if (( targetHeight - targetWidth) < 5){
        return;
      }
    }

    if (isCompressNeeded){
      await VideoCompressor.setLogLevel(0);
      final Stopwatch stopwatch = Stopwatch()..start();
      final MediaInfo? info = await VideoCompressor.compressVideo(
      // final dynamic response = await VideoCompressor.compressVideo(
        file.path,
        quality: targetQuality,
        width: targetWidth,
        height: targetHeight,
        bps: targetBps,
      );
      print(info!.path);

      stopwatch.stop();
      final Duration duration =
      Duration(milliseconds: stopwatch.elapsedMilliseconds);
      _duration = duration.inSeconds;

      if (info != null) {
        setState(() {
          _tips = "压缩成功！";
          _name = a.title!;
          _duration = (a.duration!/1000).round();
          _compRate = 100 - (info.filesize! / a.filesize! * 100).round();
          _sizeChange = "原视频大小：${(a.filesize!/(1024*1024)).round()} MB；压缩后大小：${(info.filesize!/(1024*1024)).round()} MB";
          _compressedFile = info.path!;
        });
      }
    }

  }

  _reload(){
    _duration = 0;
    _compRate = 0;
    _sizeChange = "";
    _name = "";
    _compressedFile = "";
    _tips = "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title!),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '提示: $_tips',
              style: Theme.of(context).textTheme.headline6,
            ),
            Text(
              '文件名: $_name',
              style: Theme.of(context).textTheme.headline6,
            ),
            Text(
              '视频长度: ${_duration}秒',
              style: Theme.of(context).textTheme.headline6,
            ),
            Text(
              '压缩率: $_compRate%',
              style: Theme.of(context).textTheme.headline6,
            ),
            Text(
              '文件大小: $_sizeChange',
              style: Theme.of(context).textTheme.headline6,
            ),
            // Text(
            //   '$_counter',
            //   style: Theme.of(context).textTheme.bodySmall,
            // ),
            // InkWell(
            //     child: Icon(
            //       Icons.cancel,
            //       size: 55,
            //     ),
            //     // onTap: () {
            //     //   VideoCompressor.cancelCompression();
            //     // }
            //     ),
            ElevatedButton(
              onPressed: () async {
                if (_compressedFile != ""){
                  final _result = await OpenFile.open(_compressedFile);
                } else {
                  setState(() {
                    _tips = "请先选择视频...";
                  });
                }
              },
              child: Text('Play video'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async => _compressVideo(),
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
