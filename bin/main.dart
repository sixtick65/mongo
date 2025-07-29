import 'dart:io';
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart';

// 원래 기본적으로 dart 프로그램은 메인이 프로젝트이름.dart 네... mongo.dart
// 괜히 main.dart로 바꿨네 ㅋㅋ dart run 할때 mongo.dart 를 찾음

final _sessions = <String, dynamic>{};
void printHelp() {
  print('''
🚀 사용법:
dart run bin/main.dart test 192.168.0.66 8082

옵션:
  첫번째 인자 <데이터베이스 이름>      (예: test)
  두번째 인자 <데이터베이스 호스트>        (예: 192.168.0.66)
  첫번째 인자 <커넥터 포트>      (예: 8082)
  --help 또는 -h         도움말 표시

  mongodb port : 27017
''');
}

bool isLocal(String ip) {
  print("request ip : $ip");
  return ip == '127.0.0.1' || ip == '::1' || ip.startsWith('192.168.');
}

void main(List<String> arguments) async {
  if (arguments.contains('--help') ||
      arguments.contains('-h') ||
      arguments.isEmpty ||
      arguments.length != 3) {
    printHelp();
    return; // 프로그램 종료
  }
  print(arguments); // dart run bin/main.dart test
  final host = arguments[1]; // "192.168.0.66";
  final dbName = arguments[0]; //"test";
  final port = arguments[2];
  // final collectionName = 'users';
  var db = await Db.create("mongodb://$host:27017/$dbName");
  await db.open();

  // var collection = db.collection(collectionName);
  // 위치는 로컬로 하고  포트는 80 열어야지
  // print('Hello world: ${mongo.calculate()}!');
  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    int.parse(port),
  );
  print('✅ 서버 실행 중: http://${server.address.address}:${server.port}');

  await for (HttpRequest request in server) {
    
    print("request remote address : ${request.connectionInfo?.remoteAddress.address}");
    String email = '';
    // 요청위치가 로컬인지 외부인지
    // if (!isLocal(request.connectionInfo?.remoteAddress.address ?? '')) {
    if (request.method != 'OPTIONS') {
      // 외부이면 토큰 파싱
      // print('${request.headers}'); 
      // print("${request.headers['authorization']}"); 
      // print("${request.headers['Authorization']}");
      // print("${request.headers['AUTHORIZATION']}");  
      final authHeader = request.headers.value('Authorization');
      print("authHeader : $authHeader");
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        // 인증키 없음
        print('인증키 없음');
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        continue;
      }
      final token = authHeader.substring(
        'Bearer '.length,
      ); // request.headers.value('Authorization')
      final parts = token.split('.');
      if (parts.length != 3) {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        continue;
      }

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final data = jsonDecode(payload);
      print("email : ${data['email']}");
      email = data['email'];

      // 아이디 토큰은 인증을 따로 하지 않는다. 
      // 액세스 토큰은 

      // 내부 변수 세션에 있나 확인
      // if (_sessions.containsKey(data['email'])) {
      //   // 만료 되었나 확인
      //   print('세션에 있음');
      //   final exp = data['exp'];
      //   final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      //   if (exp < now) {
      //     // 만료됨.. 세션 삭제하고 리턴
      //     _sessions.remove(data['email']);
      //     request.response.statusCode = HttpStatus.unauthorized;
      //     await request.response.close();
      //     continue;
      //   } // 아니면 패스
      // } else {
      //   // 세션에 없음... 구글에 검증 및 세션에 저장
      //   print('세션에 없음');
      //   final uri = Uri.parse(
      //     'https://oauth2.googleapis.com/tokeninfo?id_token=$token',
      //   );
      //   final response = await HttpClient()
      //       .getUrl(uri)
      //       .then((req) => req.close());
      //   print(response);
      //   print(response.headers);
      //   print(response.statusCode);
      //   if (response.statusCode == 200) {
      //     // 유효키... 세션에 저장
      //     _sessions[data['email']] = token;
      //   } else {
      //     // 불량키
      //     request.response.statusCode = HttpStatus.unauthorized;
      //     await request.response.close();
      //     continue;
      //   }
      // }
    }

    final path = request.uri.path;
    print("request path : $path , request method : ${request.method}");

    if (path == '/' || path.isEmpty) {
      // 빈 패스면 [] 빈 리스트로 응답한다. .디비 네임이 같이와야함
      print('path is empty... just continue!!');
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write("empty collection name");

      await request.response.close();
      continue;
    }
    // CORS 헤더 추가 (필수일 수 있음)  // 브라우저에서 응답을 처리할것인가 응답이 믿을만한가를 처리
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type',
    );
    request.response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    );
    try {
      if (request.method == 'GET') {
        // 조회
        dynamic result;
        final collectionName =
            request.uri.pathSegments[0]; // path.replaceAll(RegExp(r'/'), '');
        final collection = db.collection(collectionName);
        if (request.uri.pathSegments.length >= 2) {
          final id = request.uri.pathSegments[1];
          result = await collection.findOne({
            "_id": ObjectId.parse(id),
          }); //  find().toList();
          // result = await collection.findOne({"_id" : id});//  find().toList();
          // print(result);
        } else {
          result = await collection.find(where.eq('email', email) ).toList();
        }
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(result));
      } else if (request.method == 'POST') {
        final body = await utf8.decoder.bind(request).join();
        final collectionName = path.replaceAll(RegExp(r'/'), '');
        final collection = db.collection(collectionName);
        final data = jsonDecode(body);
        final result = await collection.insertOne(data); // 삽입
        print("POST : $data, success is ${result.success}");
        request.response
          ..statusCode = HttpStatus.created
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(result.document));
      } else if (request.method == 'PUT') {
        // ---------------------------------- 교체
        if (request.uri.pathSegments.length < 2) {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..headers.contentType = ContentType.json
            ..write("Missing ID!");

          await request.response.close();
          continue;
        }
        final body = await utf8.decoder.bind(request).join();
        final collectionName =
            request.uri.pathSegments[0]; // path.replaceAll(RegExp(r'/'), '');
        final collection = db.collection(collectionName);
        final data = jsonDecode(body);
        final id = request.uri.pathSegments[1];
        final result = await collection.replaceOne(
          where.eq('_id', ObjectId.parse(id)),
          data,
        ); // 수정
        print("PUT : $data, success is ${result.success}");
        request.response
          ..statusCode = result.success ? HttpStatus.ok : HttpStatus.notModified
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(await collection.findOne({"_id": ObjectId.parse(id)})),
          );
      } else if (request.method == 'PATCH') {
        // --------------------------------- 수정
        if (request.uri.pathSegments.length < 2) {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..headers.contentType = ContentType.json
            ..write("Missing ID!");

          await request.response.close();
          continue;
        }
        final body = await utf8.decoder.bind(request).join();
        final collectionName =
            request.uri.pathSegments[0]; // path.replaceAll(RegExp(r'/'), '');
        final collection = db.collection(collectionName);
        final data = jsonDecode(body);
        final id = request.uri.pathSegments[1];
        final result = await collection.updateOne(
          {"_id": ObjectId.parse(id)},
          {'\$set': data},
        ); // 수정
        print("PATCH : $data, success is ${result.success}");
        request.response
          ..statusCode = result.success ? HttpStatus.ok : HttpStatus.notModified
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(await collection.findOne({"_id": ObjectId.parse(id)})),
          );
      } else if (request.method == 'DELETE') {
        // --------------------------------------삭제
        if (request.uri.pathSegments.length < 2) {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..headers.contentType = ContentType.json
            ..write("Missing ID!");

          await request.response.close();
          continue;
        }
        // final body = await utf8.decoder.bind(request).join();
        final collectionName = request.uri.pathSegments[0];
        final collection = db.collection(collectionName);
        // final data = jsonDecode(body);
        final id = request.uri.pathSegments[1];
        final ret = await collection.findOne(
          where.eq('_id', ObjectId.parse(id)),
        );
        final result = await collection.deleteOne(
          where.eq('_id', ObjectId.parse(id)),
        ); // 삭제
        print("DELETE : $id, success is ${result.success}");
        request.response
          ..statusCode = result.success ? HttpStatus.ok : HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({"deleted": result.success, "document": ret}));
        // ..write(jsonEncode({'you_sent': jsonDecode(body)}));
      } else if (request.method == 'OPTIONS') {
        // ---------------------------브라우저에서 통신 체크
        request.response.statusCode = HttpStatus.ok;
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('경로를 찾을 수 없습니다.');
      }
      
    } catch (e) {
      print("error : $e");
      request.response
          ..statusCode = HttpStatus.badRequest
          ..write('$e');
    } finally {
      await request.response.close();
    }
  }

  // 서버 종료됨
  print('close');
  await db.close();
}
