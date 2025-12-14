import 'dart:async';
import 'dart:io';

class Spinner {
  final List<String> _frames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏'
  ];
  final String message;

  Timer? _timer;
  int _index = 0;

  Spinner(this.message);
  void start() {
    stdout.write('$message ');
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      stdout.write('\r$message ${_frames[_index]}');
      _index = (_index + 1) % _frames.length;
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
