import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/intake_service.dart';
import '../theme.dart';
import '../ui/tw.dart';
import '../utils/app_error_utils.dart';
import 'transaction_guard.dart';

class AiIntakeResult {
  const AiIntakeResult({
    required this.query,
    this.resolution,
  });

  final String query;
  final IntakeResolution? resolution;
}

class AiIntakeSheet extends StatefulWidget {
  const AiIntakeSheet({
    super.key,
    required this.initialMode,
    this.initialZip,
  });

  final String initialMode;
  final String? initialZip;

  @override
  State<AiIntakeSheet> createState() => _AiIntakeSheetState();
}

class _AiIntakeSheetState extends State<AiIntakeSheet>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  final _speech = stt.SpeechToText();
  final TextEditingController _spokenTextController = TextEditingController();
  final List<Map<String, String>> _priorTurns = [];
  final List<String> _photoRefs = [];
  final List<XFile> _localPhotos = [];

  String _spokenText = '';
  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;
  bool _speechReady = false;
  bool _isListening = false;
  String? _message;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    unawaited(_prepare());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spokenTextController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (widget.initialMode == 'voice') {
      await _startVoiceCapture();
    }
  }

  Future<void> _startVoiceCapture() async {
    try {
      final available = await _speech.initialize(
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _message = error.errorMsg.trim().isEmpty
                ? 'Voice capture could not understand that. Please try again.'
                : error.errorMsg;
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          setState(() {
            _isListening = status == 'listening';
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _speechReady = available;
      });
      if (!available) {
        setState(() {
          _message =
              'Voice capture is not available right now. Type your issue below instead.';
        });
        return;
      }
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _spokenText = result.recognizedWords;
            _isListening = !result.finalResult;
            _spokenTextController.value = TextEditingValue(
              text: _spokenText,
              selection: TextSelection.collapsed(offset: _spokenText.length),
            );
          });
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.search,
        ),
      );
      if (!mounted) return;
      setState(() {
        _isListening = true;
        _message = kIsWeb
            ? 'Browser voice capture is live. Allow microphone access in Chrome if prompted.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'Voice capture could not start. Type your issue below instead.';
        _isListening = false;
      });
    }
  }

  Future<void> _toggleVoiceCapture() async {
    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      return;
    }
    await _startVoiceCapture();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_isUploadingPhoto) return;
    try {
      final file = await _picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : source,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      setState(() {
        _isUploadingPhoto = true;
        _message = 'Uploading photo...';
        _localPhotos.add(file);
      });
      final photoRef = await IntakeService.instance.uploadPhoto(file: file);
      if (!mounted) return;
      setState(() {
        _photoRefs.add(photoRef);
        _isUploadingPhoto = false;
        _message = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = false;
        _message = AppErrorUtils.friendlyMessage(e);
      });
    }
  }

  void _removePhoto(int index) {
    if (index >= 0 && index < _localPhotos.length) {
      setState(() {
        _localPhotos.removeAt(index);
        if (index < _photoRefs.length) {
          _photoRefs.removeAt(index);
        }
      });
    }
  }

  Future<void> _submit() async {
    final isVoiceMode = widget.initialMode == 'voice';
    final query = _spokenText.trim();

    if (isVoiceMode && query.isEmpty) {
      setState(() {
        _message = 'Please tap the mic and speak your issue first.';
      });
      return;
    }

    if (!isVoiceMode && _photoRefs.isEmpty && _localPhotos.isEmpty) {
      setState(() {
        _message = 'Please take or choose at least one photo first.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      final sendText = query.isNotEmpty
          ? query
          : 'Diagnostic and repair request for home service';

      final response = await IntakeService.instance.assist(
        text: sendText,
        zip: widget.initialZip ?? '',
        photoRefs: _photoRefs,
        priorTurns: _priorTurns,
      );
      final resolution = IntakeResolution.fromApi(response);
      if (!mounted) return;

      if (query.isNotEmpty) {
        _priorTurns.add({'role': 'user', 'content': query});
      }

      switch (resolution.outcome) {
        case 'life_safety':
          setState(() {
            _isSubmitting = false;
            _message =
                'This looks life-safety related. Contact local emergency services first.';
          });
          return;
        case 'clarify':
          final clarifyMessage = resolution.clarifyingQuestion ??
              'Please share one more detail so we can match the right service.';
          setState(() {
            _isSubmitting = false;
            _message = clarifyMessage;
            _spokenText = '';
          });
          _priorTurns.add({
            'role': 'assistant',
            'content': clarifyMessage,
          });
          return;
        case 'resolved':
          final resolvedQuery =
              resolution.scopedDescription?.trim().isNotEmpty == true
                  ? resolution.scopedDescription!.trim()
                  : (query.isNotEmpty
                      ? query
                      : (resolution.label ?? 'Home Repair'));
          Navigator.of(context).pop(
            AiIntakeResult(
              query: resolvedQuery,
              resolution: resolution,
            ),
          );
          return;
        default:
          final fallbackLabel =
              resolution.label ?? (query.isNotEmpty ? query : 'Home Service');
          Navigator.of(context).pop(
            AiIntakeResult(
              query: fallbackLabel,
              resolution: resolution,
            ),
          );
          return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _message = AppErrorUtils.friendlyMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVoiceMode = widget.initialMode == 'voice';
    final gutter = TwLayout.gutter(context);

    // v3.3 A06: grabber 36×4, Outfit 22/700 title, 15/22 body subline,
    // 24 to the content, one orange "Find pros" (navy label, radius 12).
    // The content scrolls inside the sheet so nothing clips at 1.3× text.
    return TransactionGuard(
      isProcessing: _isSubmitting || _isUploadingPhoto,
      blockedMessage: 'Please wait while your request is being prepared.',
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: gutter,
            right: gutter,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: TwSpace.s20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isVoiceMode ? 'Voice intake' : 'Camera intake',
                  style: TwType.sheetTitle(),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isVoiceMode
                      ? 'Describe what you need done in your own words and our AI will match the right pro.'
                      : 'Take or choose photos of the problem area to match with the right service.',
                  style: TwType.bodySm(),
                ),
              ),
              const SizedBox(height: 24),
              if (isVoiceMode) _buildVoiceSection() else _buildCameraSection(),
              if (_message != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.subtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TwType.bodySm(color: AppTheme.navy),
                  ),
                ),
              ],
              const SizedBox(height: TwSpace.s20),
              TwPrimaryButton(
                label: 'Find pros',
                loading: _isSubmitting,
                onPressed: _isSubmitting || _isUploadingPhoto ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: (!_speechReady || _isSubmitting) ? null : _toggleVoiceCapture,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isListening ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? AppTheme.blue
                        : (_speechReady
                            ? AppTheme.blueTint
                            : AppTheme.pageBackground),
                    border: Border.all(
                      color: AppTheme.blue.withOpacity(
                        _isListening ? 0.8 : (_speechReady ? 0.3 : 0.15),
                      ),
                      width: 3,
                    ),
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: AppTheme.blue.withOpacity(0.35),
                              blurRadius: 24,
                              spreadRadius: 4,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none_rounded,
                    size: 44,
                    color: _isListening
                        ? Colors.white
                        : (_speechReady ? AppTheme.blue : AppTheme.gray),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isListening
              ? 'Listening... Speak now'
              : (_spokenText.isNotEmpty
                  ? 'Voice recorded. Tap mic to re-record.'
                  : (_speechReady
                      ? 'Tap the microphone to start speaking'
                      : 'Type what you need help with')),
          style: TwType.title(
            color: _isListening ? AppTheme.blue : AppTheme.navy,
          ).copyWith(fontSize: 15),
        ),
        const SizedBox(height: 16),
        TextField(
          minLines: 3,
          maxLines: 5,
          enabled: !_isSubmitting,
          controller: _spokenTextController,
          onChanged: (value) {
            setState(() {
              _spokenText = value;
            });
          },
          decoration: TwInputs.decoration(
            hint: 'Describe the problem in a few words...',
          ),
          style: TwType.body(color: AppTheme.navy),
        ),
        if (_spokenText.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.subtle,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded,
                    color: AppTheme.navy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _spokenText,
                    style: TwType.bodySm(color: AppTheme.navy)
                        .copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.textSecondary),
                  onPressed: () {
                    setState(() {
                      _spokenText = '';
                      _spokenTextController.clear();
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 44, height: 44),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCameraSection() {
    return Column(
      children: [
        if (_localPhotos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.subtle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    border: Border.fromBorderSide(
                        BorderSide(color: AppTheme.cardBorder)),
                    color: AppTheme.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppTheme.navy,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  kIsWeb
                      ? 'Upload photos of what needs fixing'
                      : 'Add photos of what needs fixing',
                  textAlign: TextAlign.center,
                  style: TwType.title(),
                ),
                const SizedBox(height: 18),
                // Side by side; stacked on Compact or large text so the
                // labels never clip.
                if (TwLayout.stackRows(context)) ...[
                  TwSecondaryButton(
                    label: kIsWeb ? 'Upload photo' : 'Take photo',
                    icon: kIsWeb
                        ? Icons.upload_file_outlined
                        : Icons.photo_camera_outlined,
                    height: 50,
                    onPressed: _isUploadingPhoto
                        ? null
                        : () => _pickPhoto(ImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  TwSecondaryButton(
                    label: kIsWeb ? 'Choose file' : 'Gallery',
                    icon: Icons.photo_library_outlined,
                    height: 50,
                    onPressed: _isUploadingPhoto
                        ? null
                        : () => _pickPhoto(ImageSource.gallery),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: TwSecondaryButton(
                          label: kIsWeb ? 'Upload photo' : 'Take photo',
                          icon: kIsWeb
                              ? Icons.upload_file_outlined
                              : Icons.photo_camera_outlined,
                          height: 50,
                          onPressed: _isUploadingPhoto
                              ? null
                              : () => _pickPhoto(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TwSecondaryButton(
                          label: kIsWeb ? 'Choose file' : 'Gallery',
                          icon: Icons.photo_library_outlined,
                          height: 50,
                          onPressed: _isUploadingPhoto
                              ? null
                              : () => _pickPhoto(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          )
        else ...[
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _localPhotos.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == _localPhotos.length) {
                  return InkWell(
                    onTap: _isUploadingPhoto
                        ? null
                        : () => _showPhotoSourceSheet(),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.subtle,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_rounded,
                              size: 24, color: AppTheme.navy),
                          const SizedBox(height: 4),
                          Text(
                            'Add more',
                            style: TwType.caption(color: AppTheme.navy)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final photo = _localPhotos[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 100,
                        height: 110,
                        child: kIsWeb
                            ? Image.network(photo.path, fit: BoxFit.cover)
                            : Image.file(File(photo.path), fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Wraps instead of overflowing on Compact or at 1.3x text.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _isUploadingPhoto
                    ? null
                    : () => _pickPhoto(ImageSource.camera),
                icon: Icon(
                  kIsWeb
                      ? Icons.upload_file_outlined
                      : Icons.camera_alt_outlined,
                  size: 16,
                ),
                label: Text(kIsWeb ? 'Upload another' : 'Take another'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _isUploadingPhoto
                    ? null
                    : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: const Text('From gallery'),
              ),
            ],
          ),
        ],
        if (_isUploadingPhoto) ...[
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'Uploading photo...',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showPhotoSourceSheet() {
    TwSheet.show<void>(
      context,
      scrollControlled: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined,
                      color: AppTheme.navy700),
                  title: Text(kIsWeb ? 'Upload a photo' : 'Take a photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined,
                      color: AppTheme.navy700),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
