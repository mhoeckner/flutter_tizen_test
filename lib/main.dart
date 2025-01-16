import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tizen_test/connector.dart';
import 'package:logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:video_player_avplay/video_player.dart';
import 'package:video_player_avplay/video_player_platform_interface.dart';

class MyLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}

void main() {
  const String defaultAuth = String.fromEnvironment('defaultAuth', defaultValue: '');
  runApp(
    const MaterialApp(
      home: _App(
        defaultAuth: defaultAuth,
      ),
    ),
  );
}

class _App extends StatelessWidget {
  final String defaultAuth;

  const _App({
    required this.defaultAuth,
  });

  @override
  Widget build(BuildContext context) {
    return InputWidget(
      defaultAuth: defaultAuth,
    );
  }
}

class InputWidget extends StatefulWidget {
  final String defaultAuth;

  const InputWidget({
    super.key,
    required this.defaultAuth,
  });

  @override
  State<InputWidget> createState() => _InputWidgetState();
}

class _InputWidgetState extends State<InputWidget> {
  Connector connector = const Connector(pin: '');
  late TextEditingController textController;
  final logger = Logger(
    filter: MyLogFilter(),
  );

  @override
  void initState() {
    textController = TextEditingController(text: widget.defaultAuth);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return connector.pin.isEmpty
        ? Material(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(300, 50, 300, 0),
              child: Column(
                children: [
                  TextFormField(
                    controller: textController,
                    autofocus: false,
                    textInputAction: TextInputAction.next,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter authentication',
                    ),
                  ),
                  ElevatedButton(
                    autofocus: true,
                    style: ElevatedButton.styleFrom(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                      minimumSize: const Size(150, 40),
                    ),
                    child: const Text(
                      'Submit',
                    ),
                    onPressed: () {
                      setState(() {
                        connector = connector.copyWith(pin: textController.text);
                      });
                    },
                  ),
                ],
              ),
            ),
          )
        : Material(
            child: _DashRomoteVideo(
              text: 'OCI Packager: DRM VOD Stream',
              connector: connector,
              logger: logger,
              streamingItems: [
                StreamingItem(
                  id: '806',
                  drm: true,
                  ep: 'pvr',
                ),
                StreamingItem(
                  id: '733',
                  drm: true,
                  ep: 'pvr',
                ),
                StreamingItem(
                  id: '803',
                  drm: true,
                  ep: 'pvr',
                )
              ],
            ),
          );
  }
}

class _DashRomoteVideo extends StatefulWidget {
  final String text;
  final Connector connector;
  final List<StreamingItem> streamingItems;
  final Logger logger;

  const _DashRomoteVideo({
    required this.text,
    required this.connector,
    required this.streamingItems,
    required this.logger,
  });

  @override
  State<_DashRomoteVideo> createState() => _DashRomoteVideoState();
}

class _DashRomoteVideoState extends State<_DashRomoteVideo> {
  String streamingUrl = '';
  late VideoPlayerController _controller;
  VideoPlayerController? _preloadController;
  AppValueNotifier appValueNotifier = AppValueNotifier();
  bool doPreload = true;
  bool nextStream = false;
  int streamStarts = 1;
  final Random _random = Random();

  StreamingItem _getStreamingItem() => widget.streamingItems[_random.nextInt(widget.streamingItems.length)];

  @override
  void initState() {
    super.initState();

    widget.connector
        .getStream(streamingItem: _getStreamingItem())
        .then((ConnectorResponse response) => _startStream(response: response));
  }

  VideoPlayerController _createController({
    required String url,
    required String drmToken,
    required Map<String, dynamic> playerOptions,
  }) {
    if (drmToken.isEmpty) {
      widget.logger.i('start free to air stream $url');
      return VideoPlayerController.network(
        url,
        formatHint: VideoFormat.dash,
        playerOptions: playerOptions,
      );
    } else {
      widget.logger.i('create drm protected controller $url');
      return VideoPlayerController.network(
        url,
        playerOptions: playerOptions,
        formatHint: VideoFormat.dash,
        drmConfigs: DrmConfigs(
          type: DrmType.widevine,
          licenseCallback: (Uint8List challenge) async {
            final dio = Dio();
            widget.logger.d('send license request to vmx license server...');
            widget.logger.d('token: $drmToken');
            return dio
                .post(
              'https://multidrm.core.verimatrixcloud.net/widevine',
              data: Stream.fromIterable(challenge.map((e) => [e])),
              options: Options(
                responseType: ResponseType.bytes,
                headers: {
                  'authorization': drmToken,
                },
              ),
            )
                .then(
              (response) {
                widget.logger.d('got response from license server - send license key to player');
                return response.data;
              },
            );
          },
        ),
      );
    }
  }

  void _preloadStream({required ConnectorResponse response}) {
    _preloadController = _createController(
      url: response.url,
      drmToken: response.drmToken,
      playerOptions: {
        'prebufferMode': true,
      },
    );
    _preloadController!.initialize().then(
          (_) => widget.logger.i('preload stream initialized'),
        );
    _preloadController!.addListener(_updateValueListener);
  }

  void _startStream({required ConnectorResponse response}) {
    _controller = _createController(
      url: response.url,
      drmToken: response.drmToken,
      playerOptions: {
        'prebufferMode': false,
        'startPosition': 5.0,
      },
    );

    _controller.addListener(_updateValueListener);

    _controller.initialize().then(
          (_) => setState(
            () {
              streamingUrl = response.url;
            },
          ),
        );
    _controller.play();
  }

  @override
  void dispose() {
    widget.logger.i('dispose av player...');
    _controller.dispose();
    _preloadController?.dispose();
    super.dispose();
  }

  void _startNextStream() {
    if (nextStream) return;
    nextStream = true;
    if (_preloadController != null) {
      widget.logger.d('found prebuffer stream - switch');
      VideoPlayerController oldController = _controller;
      _controller = _preloadController!;
      _preloadController = null;
      oldController.deactivate().then((value) {
        oldController.dispose();
      });
      _controller.activate().then((value) {
        _controller.play();
        int newStreamStart = streamStarts + 1;
        setState(() {
          doPreload = true;
          streamStarts = newStreamStart;
          nextStream = false;
        });
      });
    } else {
      nextStream = false;
    }
  }

  void _updateValueListener() async {
    if (_controller.value.isCompleted) {
      widget.logger.i('stream finished');
    } else {
      int pos = _controller.value.duration.end.inSeconds - _controller.value.position.inSeconds;
      if (pos < 2 && pos > 0) {
        _startNextStream();
      } else if (doPreload && pos <= 5 && pos > 0) {
        doPreload = false;
        //do preload 5 seconds before stream end
        widget.connector
            .getStream(streamingItem: _getStreamingItem())
            .then((ConnectorResponse response) => _preloadStream(response: response));
      }
      appValueNotifier.streamInformationUpdateNotifier(
        data: StreamInformationStatusData(
          position: _controller.value.position,
          duration: _controller.value.duration,
        ),
      );
    }
  }

  void _seekSeconds({required int seconds}) {
    Duration newPosition =
        seconds > 0 ? Duration(seconds: _controller.value.position.inSeconds + seconds) : Duration.zero;
    widget.logger.i('seek to position $newPosition');
    _controller.seekTo(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.only(top: 20.0),
        ),
        Text(widget.text),
        Text('Stream Start No. $streamStarts'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Wrap(),
            ElevatedButton(
              onPressed: () {
                _seekSeconds(seconds: 0);
              },
              autofocus: true,
              child: const Text(
                'Seek to start',
                style: TextStyle(fontSize: 20.0),
              ),
            ),
            ElevatedButton(
              child: const Text(
                'Seek 5s back',
                style: TextStyle(fontSize: 20.0),
              ),
              onPressed: () {
                _seekSeconds(seconds: -5);
              },
            ),
            ElevatedButton(
              child: const Text(
                'Seek 5s forward',
                style: TextStyle(fontSize: 20.0),
              ),
              onPressed: () {
                _seekSeconds(seconds: 5);
              },
            ),
            ElevatedButton(
              child: const Text(
                'Seek to 10s before end',
                style: TextStyle(fontSize: 20.0),
              ),
              onPressed: () {
                if (_controller.value.isInitialized) {
                  _seekSeconds(
                    seconds: _controller.value.duration.end.inSeconds - 10,
                  );
                }
              },
            ),
            const Wrap()
          ],
        ),
        ValueListenableBuilder(
          valueListenable: appValueNotifier.valueNotifier,
          builder: (BuildContext context, dynamic tvalue, Widget? child) {
            StreamInformationStatusData data = tvalue as StreamInformationStatusData;
            return Column(
              children: [
                Text('stream duration: ${data.duration.toString()}'),
                Text('stream position: ${data.position.toString()}'),
              ],
            );
          },
        ),
        streamingUrl.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Container(
                padding: const EdgeInsets.fromLTRB(200, 0, 200, 0),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      VideoPlayer(
                        _controller,
                        key: Key('video_player_no_$streamStarts'),
                      ),
                      ClosedCaption(text: _controller.value.caption.text),
                      VideoProgressIndicator(_controller, allowScrubbing: true),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}

class StreamInformationStatusData {
  final Duration position;
  final DurationRange duration;

  StreamInformationStatusData({
    required this.position,
    required this.duration,
  });
}

class AppValueNotifier {
  ValueNotifier<StreamInformationStatusData> valueNotifier = ValueNotifier(StreamInformationStatusData(
    position: const Duration(seconds: 0),
    duration: DurationRange(
      const Duration(seconds: 0),
      const Duration(seconds: 0),
    ),
  ));
  void streamInformationUpdateNotifier({required StreamInformationStatusData data}) => valueNotifier.value = data;
}
