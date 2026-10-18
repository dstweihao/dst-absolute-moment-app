import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 语音识别状态
enum SpeechServiceState {
  uninitialized,
  ready,
  listening,
  notAvailable,
  error,
}

/// 语音输入服务（单例封装）
class SpeechRecognitionService {
  SpeechRecognitionService._();
  static final SpeechRecognitionService instance = SpeechRecognitionService._();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  SpeechServiceState _state = SpeechServiceState.uninitialized;

  SpeechServiceState get state => _state;
  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized && _state == SpeechServiceState.ready;

  /// 初始化语音识别引擎
  Future<bool> init() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
        debugLogging: kDebugMode,
      );

      _state = _isInitialized
          ? SpeechServiceState.ready
          : SpeechServiceState.notAvailable;
      return _isInitialized;
    } catch (e) {
      debugPrint('SpeechRecognitionService init error: $e');
      _state = SpeechServiceState.error;
      return false;
    }
  }

  void _handleError(SpeechRecognitionError error) {
    debugPrint('Speech error: ${error.errorMsg} - permanent: ${error.permanent}');
  }

  void _handleStatus(String status) {
    debugPrint('Speech status: $status');
  }

  /// 开始实时语音转文字
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    VoidCallback? onDone,
    void Function(String message)? onError,
    String? localeId,
  }) async {
    final ready = await init();
    if (!ready) {
      onError?.call('当前设备语音识别服务不可用，请确认系统已开启语音服务');
      return false;
    }

    try {
      // 优先探测是否有中文 locale
      var targetLocale = localeId;
      if (targetLocale == null) {
        final locales = await _speech.locales();
        final hasZh = locales.any((l) => l.localeId.startsWith('zh'));
        if (hasZh) {
          final zhCn = locales.firstWhere(
            (l) => l.localeId.toLowerCase().contains('cn') || l.localeId.startsWith('zh'),
            orElse: () => locales.first,
          );
          targetLocale = zhCn.localeId;
        }
      }

      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult) {
            onDone?.call();
          }
        },
        onSoundLevelChange: onSoundLevel,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          localeId: targetLocale,
          listenFor: const Duration(seconds: 40),
          pauseFor: const Duration(seconds: 4),
        ),
      );

      _state = SpeechServiceState.listening;
      return true;
    } catch (e) {
      debugPrint('Speech startListening failed: $e');
      _state = SpeechServiceState.error;
      onError?.call('启动麦克风失败：$e');
      return false;
    }
  }

  /// 停止监听并保留已识别文字
  Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    _state = SpeechServiceState.ready;
  }

  /// 取消监听并放弃
  Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
    _state = SpeechServiceState.ready;
  }
}
