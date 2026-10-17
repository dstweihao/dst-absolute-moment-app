import 'package:absolute_moment_app/data/serialization/frontmatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse(compose(x)) 保持 data 与 body', () {
    final data = <String, dynamic>{
      'date': '2026-09-29',
      'title': '内存模型与指针重塑',
      'duration_minutes': 62,
      'completed': false,
      'difficulty': 5,
      'tags': ['a', 'b'],
      'nested': {'x': 1, 'y': '值'},
    };
    final text = Frontmatter.composeWith(data, '正文内容\n第二行');
    final parsed = Frontmatter.parse(text);

    expect(parsed.body, '正文内容\n第二行');
    expect(parsed.data['date'], '2026-09-29');
    expect(parsed.data['title'], '内存模型与指针重塑');
    expect(parsed.data['duration_minutes'], 62);
    expect(parsed.data['completed'], false);
    expect(parsed.data['difficulty'], 5);
    expect(parsed.data['tags'], ['a', 'b']);
    expect(parsed.data['nested'], {'x': 1, 'y': '值'});
  });

  test('特殊字符值正确加引号往返', () {
    final data = <String, dynamic>{
      'desc': '包含: 冒号 和 #井号',
      'leading': ' 有前导空格',
      'quoted': '他说"你好"',
      'numeric_like': '123',
      'bool_like': 'true',
    };
    final text = Frontmatter.composeWith(data, 'body');
    final parsed = Frontmatter.parse(text);

    expect(parsed.data['desc'], '包含: 冒号 和 #井号');
    expect(parsed.data['leading'], ' 有前导空格');
    expect(parsed.data['quoted'], '他说"你好"');
    // 形似数字/布尔的字符串必须仍被解析为字符串而非数字/布尔
    expect(parsed.data['numeric_like'], '123');
    expect(parsed.data['numeric_like'], isA<String>());
    expect(parsed.data['bool_like'], 'true');
    expect(parsed.data['bool_like'], isA<String>());
  });

  test('无头部时整篇当正文', () {
    final parsed = Frontmatter.parse('# 纯正文\n没有头部');
    expect(parsed.data, isEmpty);
    expect(parsed.body, '# 纯正文\n没有头部');
  });

  test('头部未闭合不崩溃', () {
    final parsed = Frontmatter.parse('---\ndate: 2026-09-29\n（缺少结束符）');
    expect(parsed.data, isEmpty);
  });

  test('YAML 语法错误不崩溃', () {
    final parsed = Frontmatter.parse('---\n  bad: [unclosed\n---\n\n正文');
    expect(parsed.data, isEmpty);
  });

  test('CRLF 换行被规范化', () {
    final text = Frontmatter.composeWith({'date': '2026-09-29'}, 'a\r\nb');
    final parsed = Frontmatter.parse(text);
    expect(parsed.data['date'], '2026-09-29');
  });
}
