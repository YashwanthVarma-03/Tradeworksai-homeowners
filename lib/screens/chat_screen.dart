import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../utils/app_error_utils.dart';
import '../services/stream_service.dart';
import '../theme.dart';
import '../widgets/offline_state.dart';

class ChatScreen extends StatefulWidget {
  final String contractorId;
  final String contractorName;
  final String? workOrderTitle;
  final String? workOrderStatus;

  const ChatScreen({
    super.key,
    required this.contractorId,
    required this.contractorName,
    this.workOrderTitle,
    this.workOrderStatus,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Channel? _channel;
  bool _isCreating = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initChannel();
  }

  Future<void> _initChannel({bool forceReconnect = false}) async {
    try {
      final channel = await StreamService.instance.openDirectMessageChannel(
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
        _error = AppErrorUtils.friendlyMessage(e);
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
          child: CircularProgressIndicator(color: AppTheme.orange500),
        ),
      );
    }

    if (_error != null ||
        _channel == null ||
        StreamService.instance.client == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: OfflineState(
          title: AppErrorUtils.noInternetTitle,
          message: _error ??
              StreamService.instance.lastError ??
              AppErrorUtils.noInternetMessage,
          onRetry: () {
            setState(() {
              _isCreating = true;
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
              if (widget.workOrderTitle != null) _buildContextBar(),
              const Expanded(child: StreamMessageListView()),
              const StreamMessageInput(),
            ],
          ),
        ),
      ),
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

  Widget _buildContextBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        color: AppTheme.navyTint,
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined,
              size: 16, color: AppTheme.navy700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.workOrderTitle!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: AppTheme.navy700,
                  ),
                ),
                if (widget.workOrderStatus != null)
                  Text(
                    'Status: ${widget.workOrderStatus}',
                    style: const TextStyle(color: AppTheme.gray, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
