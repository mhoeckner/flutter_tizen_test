import 'package:flutter/material.dart';
import 'package:flutter_tizen_test/connector.dart';
import 'package:video_player_videohole/video_player.dart';

void main() {
  runApp(
    MaterialApp(
      home: _App(),
    ),
  );
}

class _App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const InputWidget();
  }
}

class InputWidget extends StatefulWidget {
  const InputWidget({super.key});

  @override
  State<InputWidget> createState() => _InputWidgetState();
}

class _InputWidgetState extends State<InputWidget> {
  Connector connector = const Connector(pin: '');
  final textController = TextEditingController(text: '03062022');

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
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter Pin',
                    ),
                  ),
                  ElevatedButton(
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
            length: 2,
            child: Scaffold(
              key: const ValueKey<String>('dash_test_player'),
              appBar: AppBar(
                title: const Text('DASH video player example'),
                bottom: const TabBar(
                  isScrollable: true,
                  tabs: <Widget>[
                    Tab(
                      icon: Icon(Icons.cloud),
                      text: "DASH Template",
                    ),
                    Tab(
                      icon: Icon(Icons.cloud),
                      text: "DASH Segments",
                    ),
                  ],
                ),
              ),
              body: TabBarView(
                children: <Widget>[
                  _DashRomoteVideo(
                    text: 'DASH with template',
                    id: '100',
                    connector: connector,
                  ),
                  _DashRomoteVideo(
                    text: 'DASH without template - segments',
                    id: '101',
                    connector: connector,
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

  const _DashRomoteVideo({required this.text, required this.id, required this.connector});

  @override
  State<_DashRomoteVideo> createState() => _DashRomoteVideoState();
}

class _DashRomoteVideoState extends State<_DashRomoteVideo> {
  String streamingUrl = '';
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    widget.connector.getStaticStream(id: widget.id).then((String url) {
      print('start $url');
      _controller = VideoPlayerController.network(url);

      _controller.addListener(() {
        setState(() {});
      });
      _controller.setLooping(false);
      _controller.initialize().then((_) => setState(() {
            streamingUrl = url;
            _controller.play();
          }));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return streamingUrl.isEmpty
        ? const CircularProgressIndicator()
        : Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.only(top: 20.0),
              ),
              Text(widget.text),
              Container(
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
          );
  }
}
