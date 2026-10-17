import 'package:absolute_moment_app/core/utils/filename_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('替换坚果云禁止字符', () {
    expect(
      FilenameSanitizer.sanitize(r'a/b\c:d*e?f"g<h>i|j'),
      'a_b_c_d_e_f_g_h_i_j',
    );
  });

  test('空输入回退 untitled', () {
    expect(FilenameSanitizer.sanitize(''), 'untitled');
    expect(FilenameSanitizer.sanitize('   '), 'untitled');
  });

  test('中文内容保留不破坏', () {
    expect(FilenameSanitizer.sanitize('内存模型与指针重塑'), '内存模型与指针重塑');
  });

  test('控制字符被去除', () {
    expect(FilenameSanitizer.sanitize('a\u0000b\u001Fc\u007Fd'), 'abcd');
  });

  test('首尾的点与空格被去除', () {
    expect(FilenameSanitizer.sanitize('  hello  '), 'hello');
    expect(FilenameSanitizer.sanitize('.hidden.'), 'hidden');
  });

  test('连续占位符折叠为一个', () {
    expect(FilenameSanitizer.sanitize('a///b'), 'a_b');
  });

  test('Windows 保留名加后缀', () {
    expect(FilenameSanitizer.sanitize('CON'), 'CON_file');
    expect(FilenameSanitizer.sanitize('NUL'), 'NUL_file');
    expect(FilenameSanitizer.sanitize('COM1'), 'COM1_file');
  });

  test('validate 返回具体问题', () {
    expect(FilenameSanitizer.validate(''), '文件名不能为空');
    expect(FilenameSanitizer.validate('a/b'), '文件名不能包含字符 /');
    expect(FilenameSanitizer.validate('CON'), 'CON 是系统保留名');
    expect(FilenameSanitizer.validate('ok.txt'), isNull);
  });

  test('日期文件名格式', () {
    expect(FilenameSanitizer.forDate(DateTime(2026, 9, 5)), '2026-09-05');
    expect(FilenameSanitizer.forDate(DateTime(2026, 12, 31)), '2026-12-31');
  });

  test('validatePath 逐段校验', () {
    expect(FilenameSanitizer.validatePath('/AbsoluteMoment/checkins/2026-09-29.md'), isNull);
    expect(FilenameSanitizer.validatePath('/bad<name/x'), isNotNull);
  });
}
