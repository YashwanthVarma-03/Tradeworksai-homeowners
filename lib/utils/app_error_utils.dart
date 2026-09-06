import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AppErrorUtils {
  static const String noInternetTitle = 'No internet connection';
  static const String noInternetMessage =
      'Check your connection and tap Retry.';
  static const String webFetchMessage =
      "We couldn't reach TradeWorks right now. If you're using the web app, the API may be unavailable or blocking this browser origin.";
  static const String genericTitle = 'Something went wrong';
  static const String genericMessage = 'Please try again.';

  static bool isNetworkError(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException ||
        error is http.ClientException) {
      return true;
    }

    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('clientexception') ||
        message.contains('handshakeexception') ||
        message.contains('timeoutexception') ||
        message.contains('failed to fetch') ||
        message.contains('xmlhttprequest error') ||
        message.contains('networkrequestfailed') ||
        message.contains('network error') ||
        message.contains('host lookup') ||
        message.contains('failed host lookup') ||
        message.contains('no address associated with hostname') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('connection timed out');
  }

  static String friendlyMessage(
    Object error, {
    String fallback = genericMessage,
  }) {
    final raw = error.toString().replaceAll('Exception: ', '').trim();
    final lowerRaw = raw.toLowerCase();

    if (kIsWeb &&
        (lowerRaw.contains('failed to fetch') ||
            lowerRaw.contains('xmlhttprequest error'))) {
      return webFetchMessage;
    }

    if (isNetworkError(error)) {
      return noInternetMessage;
    }

    if (raw.isEmpty) {
      return fallback;
    }

    final sanitized = raw
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return sanitized.isEmpty ? fallback : sanitized;
  }
}
