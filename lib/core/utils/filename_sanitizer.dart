/// 文件名与路径清洗
///
/// 坚果云有两条硬约束：
/// 1. 文件名禁止字符 `\ / : * ? " < > |` 以及控制字符
/// 2. **URL 不支持中文文件夹名** —— 顶层数据目录必须用英文
///
/// 本类集中处理这些规则，避免各处散落魔法字符串。
class FilenameSanitizer {
  FilenameSanitizer._();

  /// 坚果云禁止的文件名字符
  static const List<String> forbiddenChars = [
    '\\', '/', ':', '*', '?', '"', '<', '>', '|',
  ];

  /// 替换用的占位符
  static const String replacement = '_';

  /// 单个文件名（含扩展名）的最大长度，留出余量避免超长路径
  static const int maxLength = 200;

  /// 把任意字符串清洗成合法的坚果云文件名。
  ///
  /// 同时处理 Windows 保留名（CON/PRN/AUX/NUL/COM1-9/LPT1-9），
  /// 这些名字在 Windows 上无法创建，而坚果云桌面端跑在 Windows 上。
  static String sanitize(String input) {
    var result = input.trim();

    if (result.isEmpty) return 'untitled';

    // 替换禁止字符
    for (final ch in forbiddenChars) {
      result = result.replaceAll(ch, replacement);
    }

    // 去除控制字符（0x00-0x1F 与 0x7F）
    result = result.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // 折叠连续占位符
    result = result.replaceAll(RegExp('${RegExp.escape(replacement)}+'), replacement);

    // 去掉首尾的点与空格（Windows 不允许文件以点或空格结尾）
    result = result.replaceAll(RegExp(r'^[.\s]+'), '');
    result = result.replaceAll(RegExp(r'[.\s]+$'), '');

    if (result.isEmpty) return 'untitled';

    // Windows 保留名
    if (_isReservedName(result)) {
      result = '${result}_file';
    }

    // 截断过长文件名（保留扩展名）
    if (result.length > maxLength) {
      result = _truncate(result, maxLength);
    }

    return result;
  }

  /// 校验一个文件名是否合法，返回问题描述（合法时返回 null）
  static String? validate(String input) {
    if (input.trim().isEmpty) return '文件名不能为空';

    for (final ch in forbiddenChars) {
      if (input.contains(ch)) {
        return '文件名不能包含字符 $ch';
      }
    }

    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(input)) {
      return '文件名不能包含控制字符';
    }

    if (input != input.trim()) {
      return '文件名首尾不能有空格';
    }

    if (input.startsWith('.') || input.endsWith('.')) {
      return '文件名不能以点开头或结尾';
    }

    if (input.length > maxLength) {
      return '文件名过长（上限 $maxLength 字符）';
    }

    if (_isReservedName(input)) {
      return '$input 是系统保留名';
    }

    return null;
  }

  /// 日期目录/文件名，格式 `YYYY-MM-DD`
  static String forDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 今天的日期文件名
  static String today() => forDate(DateTime.now());

  /// 校验一个 WebDAV 路径的每一段是否都合法
  static String? validatePath(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty);
    for (final segment in segments) {
      final problem = validate(segment);
      if (problem != null) return '$segment：$problem';
    }
    return null;
  }

  static bool _isReservedName(String name) {
    // 去掉扩展名再比较
    final base = name.contains('.') ? name.split('.').first : name;
    final upper = base.toUpperCase();

    const reserved = {
      'CON', 'PRN', 'AUX', 'NUL',
      'COM1', 'COM2', 'COM3', 'COM4', 'COM5',
      'COM6', 'COM7', 'COM8', 'COM9',
      'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5',
      'LPT6', 'LPT7', 'LPT8', 'LPT9',
    };

    return reserved.contains(upper);
  }

  static String _truncate(String name, int max) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex < name.length - 10) {
      return name.substring(0, max);
    }
    final ext = name.substring(dotIndex);
    final baseMax = max - ext.length;
    if (baseMax <= 0) return name.substring(0, max);
    return '${name.substring(0, baseMax)}$ext';
  }
}
