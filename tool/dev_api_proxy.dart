import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final port =
      int.tryParse(Platform.environment['TRADEWORKS_PROXY_PORT'] ?? '') ?? 8787;
  final targetBase = _normalizeBaseUrl(
    Platform.environment['TRADEWORKS_PROXY_TARGET'] ??
        'https://tradeworks-api-71668222585.us-east1.run.app/',
  );

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln(
    'TradeWorks dev proxy listening on http://${server.address.host}:$port/ -> $targetBase',
  );

  await for (final request in server) {
    unawaited(_handle(request, targetBase));
  }
}

Future<void> _handle(HttpRequest request, String targetBase) async {
  _writeCorsHeaders(request.response);

  if (request.method.toUpperCase() == 'OPTIONS') {
    request.response
      ..statusCode = HttpStatus.noContent
      ..close();
    return;
  }

  final client = HttpClient();
  try {
    final path = request.uri.path.startsWith('/')
        ? request.uri.path.substring(1)
        : request.uri.path;
    final upstreamUri = Uri.parse(targetBase).resolve(path).replace(
          query: request.uri.query,
        );
    final upstreamRequest = await client.openUrl(request.method, upstreamUri);

    request.headers.forEach((name, values) {
      final lower = name.toLowerCase();
      if (lower == 'host' || lower == 'content-length') {
        return;
      }
      for (final value in values) {
        upstreamRequest.headers.add(name, value);
      }
    });

    final bodyBytes = await request.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    if (bodyBytes.isNotEmpty) {
      upstreamRequest.add(bodyBytes);
    }

    final upstreamResponse = await upstreamRequest.close();
    request.response.statusCode = upstreamResponse.statusCode;

    upstreamResponse.headers.forEach((name, values) {
      final lower = name.toLowerCase();
      if (lower == 'content-length' ||
          lower == 'transfer-encoding' ||
          lower == 'connection') {
        return;
      }
      for (final value in values) {
        request.response.headers.add(name, value);
      }
    });

    final responseBytes = await upstreamResponse.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );

    if (responseBytes.isEmpty) {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'success': false,
          'error':
              'Upstream TradeWorks API returned an empty response for ${request.uri.path}.',
        }),
      );
    } else {
      request.response.add(responseBytes);
    }
  } catch (error) {
    request.response
      ..statusCode = HttpStatus.badGateway
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode({
          'success': false,
          'error': 'TradeWorks dev proxy error: $error',
        }),
      );
  } finally {
    client.close(force: true);
    await request.response.close();
  }
}

void _writeCorsHeaders(HttpResponse response) {
  response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set(
      'Access-Control-Allow-Headers',
      'Origin, X-Requested-With, Content-Type, Accept, Authorization',
    )
    ..set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
}

String _normalizeBaseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('TRADEWORKS_PROXY_TARGET must not be empty.');
  }
  return trimmed.endsWith('/') ? trimmed : '$trimmed/';
}
