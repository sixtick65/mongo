# mongo
몽고디비 REST

dart create . --force
dart pub add mongo_dart

/bin : main 파일 위치


```
curl http://localhost:8080/users/6867579ee6130b87bd000000

curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"name":"cho"}'

curl -X PUT http://localhost:8080/users/6867579ee6130b87bd000000 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"name":"kim", "age": 22}'


curl -X PATCH http://localhost:8080/users/6867579ee6130b87bd000000 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"name":"kim", "age": 22}'

curl -X DELETE http://localhost:8080/users/68677240f76473b9cc000000 \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```


```
## 도커파일
FROM dart:stable as build
WORKDIR /app
COPY . .
RUN dart pub get
RUN dart compile exe bin/server.dart -o /app/server

FROM scratch
COPY --from=build /app/server /app/server
CMD ["/app/server"]


```

```
docker build -t my-dart-app .
docker run -d -p 8080:8080 --name my-dart-container my-dart-app


```

A sample command-line application with an entrypoint in `bin/`, library code
in `lib/`, and example unit test in `test/`.
