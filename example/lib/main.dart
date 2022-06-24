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
  bool _isVideoCompressed = false;

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

    CompressionConfig conf = CompressionConfig(
        a.mimetype!,
        a.duration!,
        a.filesize!,
        a.width!,
        a.height!,
        a.bitrate!
    );

    // Todo: set the orientation correctly
    // Keep the original orientation
    // if (a.orientation == 90 || a.orientation == 270) {
    //   var temp = targetHeight;
    //   targetHeight = targetWidth;
    //   targetWidth = temp;
    // }

    if (conf.isCompressionNeeded){
      await VideoCompressor.setLogLevel(0);
      final Stopwatch stopwatch = Stopwatch()..start();
      final MediaInfo? info = await VideoCompressor.compressVideo(
      // final dynamic response = await VideoCompressor.compressVideo(
        file.path,
        quality: conf.targetQuality!,
        width: conf.targetWidth,
        height: conf.targetHeight,
        bps: conf.targetBps,
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
    } else {
      setState(() {
        _tips = conf.tips!;
        _compressedFile = a.path!;
      });
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
            Visibility(
              visible: !_isVideoCompressed,
              child: StreamBuilder<double>(
                stream: VideoCompressor.onProgressUpdated,
                builder: (BuildContext context,
                    AsyncSnapshot<dynamic> snapshot) {
                  if (snapshot.data != null && snapshot.data > 0) {
                    return Column(
                      children: <Widget>[
                        LinearProgressIndicator(
                          minHeight: 8,
                          value: snapshot.data / 100,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.data.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 20),
                        )
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
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
