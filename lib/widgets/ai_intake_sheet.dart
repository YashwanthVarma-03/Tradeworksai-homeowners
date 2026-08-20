import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/intake_service.dart';
import '../theme.dart';
import '../utils/app_error_utils.dart';

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
  final List<Map<String, String>> _priorTurns = [];
  final List<String> _photoRefs = [];
  final List<XFile> _localPhotos = [];

  String _spokenText = '';
  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;
  bool _speechReady = false;
  bool _isListening = false;
  String? _message;
  String? _clarifyingQuestion;

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
      final available = await _speech.initialize();
      if (!mounted) return;
      setState(() {
        _speechReady = available;
      });
      if (!available) {
        setState(() {
          _message = 'Voice capture is not available on this device right now.';
        });
        return;
      }
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _spokenText = result.recognizedWords;
            _isListening = !result.finalResult;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _isListening = true;
        _message = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Voice capture could not start.';
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
        source: source,
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
            _clarifyingQuestion = clarifyMessage;
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
                  : (query.isNotEmpty ? query : (resolution.label ?? 'Home Repair'));
          Navigator.of(context).pop(
            AiIntakeResult(
              query: resolvedQuery,
              resolution: resolution,
            ),
          );
          return;
        default:
          final fallbackLabel = resolution.label ?? (query.isNotEmpty ? query : 'Home Service');
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isVoiceMode ? 'Voice intake' : 'Camera intake',
                style: const TextStyle(
                  color: AppTheme.navy700,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isVoiceMode
                    ? 'Describe what you need done in your own words and our AI will match the right pro.'
                    : 'Take or choose photos of the problem area to match with the right service.',
                style: const TextStyle(
                  color: AppTheme.gray,
                  fontSize: 13,
                  height: 1.45,
                ),
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
                  color: AppTheme.navyTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.line),
                ),
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.navy700,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting || _isUploadingPhoto ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange500,
                  foregroundColor: AppTheme.navy700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppTheme.navy700,
                        ),
                      )
                    : const Text(
                        'Find pros',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _isSubmitting ? null : _toggleVoiceCapture,
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
                    color: _isListening ? AppTheme.orange500 : AppTheme.orangeTint,
                    border: Border.all(
                      color: AppTheme.orange500.withOpacity(_isListening ? 0.8 : 0.3),
                      width: 3,
                    ),
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: AppTheme.orange500.withOpacity(0.35),
                              blurRadius: 24,
                              spreadRadius: 4,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none_rounded,
                    size: 44,
                    color: _isListening ? Colors.white : AppTheme.orange500,
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
                  : 'Tap the microphone to start speaking'),
          style: TextStyle(
            color: _isListening ? AppTheme.orange500 : AppTheme.navy700,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (_spokenText.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded,
                    color: AppTheme.teal500, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _spokenText,
                    style: const TextStyle(
                      color: AppTheme.navy700,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.gray),
                  onPressed: () {
                    setState(() {
                      _spokenText = '';
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
              color: const Color(0xFFF7FAFD),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.line,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: AppTheme.navyTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    color: AppTheme.teal500,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add photos of what needs fixing',
                  style: TextStyle(
                    color: AppTheme.navy700,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploadingPhoto
                            ? null
                            : () => _pickPhoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Take Photo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.navy700,
                          side: const BorderSide(color: AppTheme.line),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploadingPhoto
                            ? null
                            : () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.navy700,
                          side: const BorderSide(color: AppTheme.line),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
                        color: const Color(0xFFF7FAFD),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.line),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 28, color: AppTheme.teal500),
                          SizedBox(height: 4),
                          Text(
                            'Add more',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.navy700,
                              fontWeight: FontWeight.w600,
                            ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _isUploadingPhoto
                    ? null
                    : () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: const Text('Take another'),
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
                  fontSize: 12,
                  color: AppTheme.gray,
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  title: const Text('Take a photo'),
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
