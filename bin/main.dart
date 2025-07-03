import 'dart:io';
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart';

void main(List<String> arguments) async {

  print(arguments);
  final host = "192.168.0.66";
  final dbName = "test";
  // final collectionName = 'users';
  var db = await Db.create("mongodb://$host:27017/$dbName");
  await db.open();

  // var collection = db.collection(collectionName);
  // 위치는 로컬로 하고  포트는 80 열어야지 
  // print('Hello world: ${mongo.calculate()}!');
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('✅ 서버 실행 중: http://${server.address.address}:${server.port}');

  await for (HttpRequest request in server) {
    final path = request.uri.path;
    print(path);
    if(path == '/' || path.isEmpty){  // 빈 패스면 [] 빈 리스트로 응답한다. 
      print('path is empty... just continue!!');
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode([]));

      await request.response.close();
      continue;
    }
    // CORS 헤더 추가 (필수일 수 있음)
    request.response.headers.set('Access-Control-Allow-Origin', '*');

    if (request.method == 'GET') { // 조회
      final collectionName = path.replaceAll(RegExp(r'/'), '');
      final collection = db.collection(collectionName);
      final result = await collection.find().toList();
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(result));
    } else if (request.method == 'POST' && path == '/echo') {
      final body = await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'you_sent': jsonDecode(body)}));
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('경로를 찾을 수 없습니다.');
    }

    await request.response.close();
  }


  // 서버 종료됨
  print('close');
  await db.close();

}
