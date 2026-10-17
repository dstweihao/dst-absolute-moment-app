// 极简静态文件服务器 —— 托管 `flutter build web` 产物（build/web）。
//
// 为什么不用 `flutter run -d web-server`：其 debug 模式依赖 DWDS 调试器握手，
// 握手超时会导致页面空白。release 产物是纯 JS，静态托管即可直接渲染。
//
// 用法：dart run tool/web_server.dart [port]
import 'dart:io';

void main(List<String> args) {
  final port = int.tryParse(args.isNotEmpty ? args[0] : '') ?? 8080;
  final root = Directory('build/web').absolute;

  HttpServer.bind(InternetAddress.loopbackIPv4, port).then((server) {
    stdout.writeln('serving ${root.path} at http://127.0.0.1:$port');
    server.listen((req) async {
      try {
        var path = Uri.decodeComponent(req.uri.path);
        if (path == '/') path = '/index.html';
        final file = File(
          '${root.path}${path.replaceAll('/', Platform.pathSeparator)}',
        );
        if (!file.existsSync()) {
          req.response.statusCode = HttpStatus.notFound;
          req.response.close();
          return;
        }
        req.response.headers.contentType =
            ContentType.parse('${_mime(path)}; charset=utf-8');
        req.response.add(file.readAsBytesSync());
      } catch (_) {
        req.response.statusCode = HttpStatus.internalServerError;
      }
      req.response.close();
    });
  });
}

String _mime(String p) {
  if (p.endsWith('.html')) return 'text/html';
  if (p.endsWith('.js')) return 'application/javascript';
  if (p.endsWith('.mjs')) return 'application/javascript';
  if (p.endsWith('.css')) return 'text/css';
  if (p.endsWith('.wasm')) return 'application/wasm';
  if (p.endsWith('.json')) return 'application/json';
  if (p.endsWith('.png')) return 'image/png';
  if (p.endsWith('.ico')) return 'image/x-icon';
  if (p.endsWith('.svg')) return 'image/svg+xml';
  if (p.endsWith('.woff')) return 'font/woff';
  if (p.endsWith('.woff2')) return 'font/woff2';
  return 'application/octet-stream';
}
