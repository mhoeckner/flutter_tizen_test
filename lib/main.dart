import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tizen_test/connector.dart';
import 'package:logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:video_player_avplay/video_player.dart';
import 'package:video_player_avplay/video_player_platform_interface.dart';

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
  final logger = Logger();

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
        : DefaultTabController(
            length: 6,
            initialIndex: 0,
            child: Scaffold(
              key: const ValueKey<String>('dash_test_player'),
              appBar: AppBar(
                title: const Text('DASH video player example'),
                bottom: const TabBar(
                  isScrollable: true,
                  tabs: <Widget>[
                    Tab(
                      icon: Icon(Icons.cloud),
                      text: "Stream 1",
                    ),
                    Tab(
                      icon: Icon(Icons.cloud),
                      text: "Stream 2",
                    ),
                    Tab(
                      icon: Icon(Icons.cloud),
                      text: "Stream 3",
                    ),
                    Tab(
                      icon: Icon(Icons.cloud),
                      text: "Stream 4",
                    ),
                    Tab(
                      icon: Icon(Icons.cloud),
                      text: "Stream 5",
                    ),
                    Tab(
                      icon: Icon(Icons.cloud),
                      text: "Stream 6",
                    ),
                  ],
                ),
              ),
              body: TabBarView(
                children: <Widget>[
                  _DashRomoteVideo(
                    text: 'OCI Packager: DASH Live Stream FreeToAir',
                    id: '115',
                    connector: connector,
                    drm: false,
                    logger: logger,
                    ep: 'stream',
                  ),
                  _DashRomoteVideo(
                    text: 'OCI Packager: DASH Live Stream DRM Widevine',
                    id: '85',
                    connector: connector,
                    drm: true,
                    logger: logger,
                    ep: 'stream',
                  ),
                  _DashRomoteVideo(
                    text: 'OCI Packager: DASH Static FreeToAir',
                    id: '476',
                    connector: connector,
                    drm: false,
                    logger: logger,
                    ep: 'pvr',
                  ),
                  _DashRomoteVideo(
                    text: 'OCI Packager: DASH DRM Static',
                    id: '459',
                    connector: connector,
                    drm: true,
                    logger: logger,
                    ep: 'pvr',
                  ),
                  _DashRomoteVideo(
                    text: 'DASH Low Latency Harmonic Live Stream',
                    id: '1',
                    connector: connector,
                    drm: false,
                    logger: logger,
                    ep: 'stream',
                  ),
                  _DashRomoteVideo(
                    text: 'DASH Akamai Live Stream',
                    id: '2',
                    connector: connector,
                    drm: false,
                    logger: logger,
                    ep: 'stream',
                  ),
                ],
              ),
            ),
          );
  }
}

class _DashRomoteVideo extends StatefulWidget {
  final String text;
  final Connector connector;
  final String id;
  final String ep;
  final bool drm;
  final Logger logger;

  const _DashRomoteVideo({
    required this.text,
    required this.id,
    required this.connector,
    required this.ep,
    required this.drm,
    required this.logger,
  });

  @override
  State<_DashRomoteVideo> createState() => _DashRomoteVideoState();
}

class _DashRomoteVideoState extends State<_DashRomoteVideo> {
  String streamingUrl = '';
  late VideoPlayerController _controller;
  AppValueNotifier appValueNotifier = AppValueNotifier();

  @override
  void initState() {
    super.initState();

    widget.connector
        .getStream(id: widget.id, ep: widget.ep)
        .then((ConnectorResponse response) => _startStream(response: response));
  }

  void _startStream({required ConnectorResponse response}) {
    try {
      _controller.dispose();
    } catch (_) {}
    if (!widget.drm) {
      widget.logger.i('start free to air stream ${response.url}');
      _controller = VideoPlayerController.network(
        response.url,
        formatHint: VideoFormat.dash,
      );
    } else {
      widget.logger.i('start drm protected stream ${response.url}');
      _controller = VideoPlayerController.network(
        response.url,
        formatHint: VideoFormat.dash,
        drmConfigs: DrmConfigs(
          type: DrmType.widevine,
          licenseCallback: (Uint8List challenge) async {
            final dio = Dio();
            widget.logger.d('send license request to vmx license server...');
            widget.logger.d('token: ${response.drmToken}');
            return dio
                .post(
              'https://multidrm.core.verimatrixcloud.net/widevine',
              data: Stream.fromIterable(challenge.map((e) => [e])),
              options: Options(
                responseType: ResponseType.bytes,
                headers: {
                  'authorization': response.drmToken,
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

    _controller.addListener(_updateValueListener);
    _controller.setLooping(false);

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
    _controller.dispose();
    super.dispose();
  }

  void _updateValueListener() {
    appValueNotifier.streamInformationUpdateNotifier(
        data: StreamInformationStatusData(position: _controller.value.position));
  }

  void _seekSeconds({required int seconds}) {
    Duration newPosition =
        seconds > 0 ? Duration(seconds: _controller.value.position.inSeconds + seconds) : Duration.zero;
    widget.logger.i('seek to position $newPosition');
    _controller.seekTo(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event.runtimeType == KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
          try {
            widget.logger.i("try start stream...");
            _controller.play();
          } catch (_) {
            widget.logger.e("play failed -> $_");
          }
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.only(top: 20.0),
          ),
          Text(widget.text),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Wrap(),
              ElevatedButton(
                child: const Text(
                  'Seek to start',
                  style: TextStyle(fontSize: 20.0),
                ),
                onPressed: () {
                  _seekSeconds(seconds: 0);
                },
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
              const Wrap()
            ],
          ),
          ValueListenableBuilder(
            valueListenable: appValueNotifier.valueNotifier,
            builder: (BuildContext context, dynamic tvalue, Widget? child) {
              StreamInformationStatusData data = tvalue as StreamInformationStatusData;
              return Text('stream position: ${data.position.toString()}');
            },
          ),
          streamingUrl.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  padding: const EdgeInsets.fromLTRB(200, 0, 200, 0),
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: <Widget>[
                        VideoPlayer(_controller),
                        ClosedCaption(text: _controller.value.caption.text),
                        VideoProgressIndicator(_controller, allowScrubbing: true),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class StreamInformationStatusData {
  final Duration position;

  StreamInformationStatusData({required this.position});
}

class AppValueNotifier {
  ValueNotifier<StreamInformationStatusData> valueNotifier =
      ValueNotifier(StreamInformationStatusData(position: const Duration(seconds: 0)));
  void streamInformationUpdateNotifier({required StreamInformationStatusData data}) {
    valueNotifier.value = data;
  }
}
