/// 敏感词与合规守护器
///
/// 针对用户输入的粗口、辱骂、违禁敏感词以及服务商返回的合规拦截进行统一诊断与友好反馈。
class SensitiveContentGuard {
  SensitiveContentGuard._();

  /// 常见侮辱、谩骂、不当词汇正则（含连续重复字如“草草草”）
  static final List<RegExp> _sensitivePatterns = [
    // 粗口与辱骂（中文）
    RegExp(r'(?:草{2,}|操{2,}|日{2,}|艹{2,})'),
    RegExp(r'(?:卧[槽草]|我[操日草艹]|干你|[操草艹日]你|[操草艹日]他|[操草艹日]妈)'),
    RegExp(r'(?:[妈媽][的了个批]|他[妈媽][的批]?|[你妳][妈媽][的批]?|特么的|特[么麼]的)'),
    RegExp(r'(?:傻[逼比吊雕逼]|煞[笔逼比]|沙[比逼]|二[逼货]|蠢[猪货狗]|智障|脑残|弱智)'),
    RegExp(r'(?:[狗猪]日的|狗杂种|死全家|去死吧|生殖器|[鸡雞][巴吧]|[屌吊]毛|逼样)'),
    RegExp(r'(?:王八蛋|王八羔子|贱人|贱货|骚货|吃屎|放屁|装[逼比]|撕[逼比]|滚蛋|滚粗)'),
    // 拼音与常见缩写
    RegExp(r'\b(?:cnm|tmd|nmsl|mlgb|fw|sb|rnm|nnd)\b', caseSensitive: false),
    // 英文常见极端粗口
    RegExp(r'\b(?:fuck|fucking|shit|bitch|asshole|cunt|motherfucker|dickhead)\b', caseSensitive: false),
  ];

  /// 服务端/网关返回的合规拦截特征词
  static const List<String> _filterErrorTokens = [
    'content_filter',
    'content filter',
    'sensitive',
    'moderation',
    'policy',
    'safety',
    'inappropriate',
    'risk',
    'violation',
    'forbidden_word',
    'blocked',
    '违规',
    '敏感',
    '合规',
    '违禁',
    '拦截',
    '安全策略',
    '内容审核',
    '不当内容',
    '涉恐',
    '涉暴',
  ];

  /// 检查文本是否包含敏感/违禁词汇
  static bool isSensitive(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // 单字粗口在极短表达中直接拦截（如单个“草”、“操”、“日”）
    if (trimmed.length <= 2) {
      if (trimmed == '草' || trimmed == '操' || trimmed == '日' || trimmed == '艹') {
        return true;
      }
    }

    for (final pattern in _sensitivePatterns) {
      if (pattern.hasMatch(trimmed)) {
        return true;
      }
    }

    return false;
  }

  /// 检查服务端报错详情是否代表合规/敏感词拦截
  static bool isContentFilterError(String errorDetail) {
    if (errorDetail.isEmpty) return false;
    final lower = errorDetail.toLowerCase();
    return _filterErrorTokens.any((token) => lower.contains(token));
  }

  /// 针对敏感词输入，生成正式、克制、引导理性的提示语
  static String friendlyWarningMessage() {
    return '⚠️ 输入内容包含不当词汇或敏感用语，已触发合规保护。\n\n'
        '👉 请调整表述，使用理性的技术术语继续探讨。';
  }
}
