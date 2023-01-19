import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:video_player_videohole/video_player.dart';
import 'package:video_player_videohole/video_player_platform_interface.dart';

void main() {
  runApp(
    MaterialApp(
      home: _DrmRemoteVideo(),
    ),
  );
}

class _DrmRemoteVideo extends StatefulWidget {
  @override
  _DrmRemoteVideoState createState() => _DrmRemoteVideoState();
}

class _DrmRemoteVideoState extends State<_DrmRemoteVideo> {
  late VideoPlayerController _controller;
  // ignore: non_constant_identifier_names
  late FFIController ffi_controller;

  Future<Uint8List> _getlicense(Uint8List challenge) {
    return http
        .post(
          Uri.parse('https://proxy.uat.widevine.com/proxy'),
          body: challenge,
        )
        .then((response) => response.bodyBytes);
  }

  @override
  void initState() {
    super.initState();
    ffi_controller = FFIController(_getlicense);
    ffi_controller.FFIgetLicense();

    _controller = VideoPlayerController.network(
      //widevine
      'https://storage.googleapis.com/wvmedia/cenc/hevc/tears/tears.mpd',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      drmConfigs: {
        'drmType': 2,
      },
    );

    _controller.addListener(() {
      setState(() {});
    });
    _controller.setLooping(true);
    _controller.initialize().then((_) => setState(() {}));
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}
