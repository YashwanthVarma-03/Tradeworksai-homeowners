import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/intake_service.dart';
import '../theme.dart';

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

class _AiIntakeSheetState extends State<AiIntakeSheet> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();
  final _speech = stt.SpeechToText();
  final List<Map<String, String>> _priorTurns = [];
  final List<String> _photoRefs = [];

  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;
  bool _speechReady = false;
  bool _isListening = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
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
            _textController.text = result.recognizedWords;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
            _isListening = result.finalResult ? false : true;
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

  Future<void> _capturePhoto() async {
    if (_isUploadingPhoto) return;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      setState(() {
        _isUploadingPhoto = true;
        _message = 'Uploading photo...';
      });
      final photoRef = await IntakeService.instance.uploadPhoto(file: file);
      if (!mounted) return;
      setState(() {
        _photoRefs.add(photoRef);
        _isUploadingPhoto = false;
        _message = 'Photo attached.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = false;
        _message = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _submit() async {
    final query = _textController.text.trim();
    if (query.isEmpty && _photoRefs.isEmpty) {
      setState(() {
        _message = 'Add a short description or a photo first.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      final response = await IntakeService.instance.assist(
        text: query,
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
          });
          _priorTurns.add({
            'role': 'assistant',
            'content': clarifyMessage,
          });
          _textController.clear();
          return;
        case 'resolved':
          final resolvedQuery = resolution.scopedDescription?.trim().isNotEmpty == true
              ? resolution.scopedDescription!.trim()
              : query;
          Navigator.of(context).pop(
            AiIntakeResult(
              query: resolvedQuery,
              resolution: resolution,
            ),
          );
          return;
        default:
          setState(() {
            _isSubmitting = false;
            _message = 'The AI layer returned an unsupported response.';
          });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _message = e.toString().replaceAll('Exception: ', '');
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
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isVoiceMode ? 'Voice intake' : 'Camera intake',
              style: const TextStyle(
                color: AppTheme.navy700,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isVoiceMode
                  ? 'Describe the issue in your own words and we will route you to the right pros.'
                  : 'Take a photo, add a short note, and we will match the job to the right service.',
              style: const TextStyle(
                color: AppTheme.gray,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'What is going on at home?',
                filled: true,
                fillColor: const Color(0xFFF7FAFD),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppTheme.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppTheme.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppTheme.teal500),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploadingPhoto || _isSubmitting ? null : _capturePhoto,
                    icon: _isUploadingPhoto
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_outlined),
                    label: Text(_photoRefs.isEmpty ? 'Add photo' : 'Photo attached'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _toggleVoiceCapture,
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                    label: Text(_isListening
                        ? 'Listening...'
                        : (_speechReady || !isVoiceMode ? 'Use voice' : 'Enable voice')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.navyTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _message!,
                  style: const TextStyle(
                    color: AppTheme.navy700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange500,
                  foregroundColor: AppTheme.navy700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppTheme.navy700,
                        ),
                      )
                    : const Text(
                        'Find pros',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
