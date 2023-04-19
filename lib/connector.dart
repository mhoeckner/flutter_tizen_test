import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

@immutable
class Connector {
  static const String api = 'https://ocistreaming.madhonk.org/dri.php';
  final String pin;

  const Connector({required this.pin});

  Connector copyWith({required String pin}) => Connector(pin: pin);

  Future<String> getStaticStream({required String id}) async {
    String url = await _call(ep: 'static', chid: id);
    return url.toString();
  }

  Future<dynamic> _call({required String ep, required String chid}) async {
    final dio = Dio();
    Response res = await dio.get('$api?pin=$pin&ep=$ep&chid=$chid');
    if (res.statusCode == 200) {
      return res.data;
    } else {
      throw Exception('Fetch Error');
    }
  }
}
