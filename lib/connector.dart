import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class StreamingItem {
  final String id;
  final String ep;
  final bool drm;

  StreamingItem({required this.id, required this.ep, required this.drm});
}

class ConnectorResponse {
  final String url;
  final String drmToken;

  ConnectorResponse({
    required this.url,
    this.drmToken = '',
  });
}

@immutable
class Connector {
  static const String api = 'https://ocistreaming.madhonk.org/dri.php';
  final String pin;

  const Connector({required this.pin});

  Connector copyWith({required String pin}) => Connector(pin: pin);

  Future<ConnectorResponse> getStream({required StreamingItem streamingItem}) async {
    final dio = Dio();
    Response res = await dio.get('$api?pin=$pin&ep=${streamingItem.ep}&chid=${streamingItem.id}',
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ));
    if (res.statusCode == 200) {
      return ConnectorResponse(url: res.data['url'] ?? '', drmToken: res.data['drmToken'] ?? '');
    } else {
      throw Exception('Fetch Error');
    }
  }
}
