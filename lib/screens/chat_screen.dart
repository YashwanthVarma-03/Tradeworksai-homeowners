import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../utils/app_error_utils.dart';
import '../services/stream_service.dart';
import '../theme.dart';
import '../widgets/offline_state.dart';

class ChatScreen extends StatefulWidget {
  final String contractorId;
  final String contractorName;
  final String? jobReference;
  final Channel? existingChannel;

  const ChatScreen({
    super.key,
    required this.contractorId,
    required this.contractorName,
    this.jobReference,
    this.existingChannel,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Channel? _channel;
  bool _isCreating = true;
  bool _isNetworkIssue = false;
  String? _error;
  String? _pendingJobReference;

  @override
  void initState() {
    super.initState();
    _pendingJobReference = widget.jobReference;
    _initChannel();
  }

  Future<void> _initChannel({bool forceReconnect = false}) async {
    try {
      final channel = widget.existingChannel ??
          await StreamService.instance.openDirectMessageChannel(
            otherUserId: widget.contractorId,
            otherUserName: widget.contractorName,
            forceReconnect: forceReconnect,
          );

      if (!mounted) return;
      setState(() {
        _channel = channel;
        _isCreating = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isNetworkIssue = AppErrorUtils.isNetworkError(e);
        _error = _chatErrorMessage(e);
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreating) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.navy),
        ),
      );
    }

    if (_error != null ||
        _channel == null ||
        StreamService.instance.client == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: OfflineState(
          title: _isNetworkIssue
              ? AppErrorUtils.noInternetTitle
              : 'Messaging unavailable',
          icon: _isNetworkIssue
              ? Icons.wifi_off_rounded
              : Icons.chat_bubble_outline_rounded,
          message: _error ??
              StreamService.instance.lastError ??
              (_isNetworkIssue
                  ? AppErrorUtils.noInternetMessage
                  : 'This contractor is not available for messaging yet.'),
          onRetry: () {
            setState(() {
              _isCreating = true;
              _isNetworkIssue = false;
              _error = null;
            });
            _initChannel(forceReconnect: true);
          },
        ),
      );
    }

    return StreamChat(
      client: StreamService.instance.client!,
      child: StreamChannel(
        channel: _channel!,
        child: Scaffold(
          appBar: _buildAppBar(),
          body: Column(
            children: [
              Expanded(child: StreamMessageListView(
                messageBuilder: (context, details, messages, defaultWidget) {
                  final reference = details.message.extraData['jobReference'];
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (reference is String && reference.trim().isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: Text(reference,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12))),
                        defaultWidget.copyWith(showSendingIndicator: false),
                      ]);
                },
              )),
              if (_pendingJobReference != null)
                Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: InputChip(
                            label: Text(_pendingJobReference!),
                            onDeleted: () =>
                                setState(() => _pendingJobReference = null)))),
              StreamMessageInput(
                preMessageSending: (message) => message.copyWith(extraData: {
                  ...message.extraData,
                  if (_pendingJobReference != null)
                    'jobReference': _pendingJobReference,
                }),
                onMessageSent: (_) {
                  if (mounted) setState(() => _pendingJobReference = null);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _chatErrorMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('getorcreatechannel') ||
        raw.contains("users are involved in channel create operation") ||
        raw.contains("don't exist")) {
      return 'This contractor is not available for messaging yet.';
    }
    return AppErrorUtils.friendlyMessage(
      error,
      fallback: 'Chat is unavailable right now.',
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.contractorName,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: AppTheme.navy700,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(color: AppTheme.line, height: 0.5),
      ),
    );
  }
}
