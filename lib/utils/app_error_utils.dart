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
    // Keep this alias while callers migrate to `fallback`. It prevents a
    // stale hot-reload source file from turning error handling itself into a
    // compilation failure.
    String? fallbackMessage,
  }) {
    final effectiveFallback = fallbackMessage ?? fallback;
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

    if (lowerRaw.contains('not_cancellable') ||
        lowerRaw.contains('not cancellable')) {
      return 'This booking can no longer be cancelled.';
    }

    if (lowerRaw.contains('not_reschedulable') ||
        lowerRaw.contains('not reschedulable')) {
      return 'This booking can no longer be rescheduled.';
    }

    if (lowerRaw.contains('booking_cap')) {
      return 'You have reached the maximum number of open bookings. Complete or cancel an existing booking before creating a new one.';
    }

    if (lowerRaw.contains('unauthenticated') ||
        lowerRaw.contains('unauthorized') ||
        lowerRaw.contains('invalid jwt') ||
        lowerRaw.contains('expired token')) {
      return 'Please sign in again to continue.';
    }

    if (lowerRaw.contains('server_error') ||
        lowerRaw.contains('internal server error') ||
        lowerRaw.contains('status code 5')) {
      return effectiveFallback;
    }

    if (raw.isEmpty) {
      return effectiveFallback;
    }

    final sanitized = raw
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Single-token and snake_case responses are implementation codes, not
    // customer-facing copy (for example, `not_cancellable`).
    if (sanitized.isEmpty ||
        !sanitized.contains(' ') ||
        sanitized.contains('_')) {
      return effectiveFallback;
    }

    return sanitized;
  }
}
