import 'package:absolute_moment_app/features/sop/domain/difficulty_calibrator.dart';
import 'package:flutter_test/flutter_test.dart';

const calibrator = DifficultyCalibrator();

void main() {
  test('甜蜜点内维持', () {
    final a = calibrator.calibrate(5, const [4, 5, 6]);
    expect(a.inSweetSpot, true);
    expect(a.delta, 0);
  });

  test('偏易加一档', () {
    final a = calibrator.calibrate(2, const [5, 6]);
    expect(a.delta, 1);
    expect(a.inSweetSpot, false);
  });

  test('连续偏易加大步长', () {
    final a = calibrator.calibrate(1, const [2, 2]);
    expect(a.delta, 2);
  });

  test('偏难单次降一档', () {
    final a = calibrator.calibrate(9, const [5]);
    expect(a.delta, -1);
    expect(a.needsSideQuest, false);
  });

  test('连续过难触发降维支线', () {
    final a = calibrator.calibrate(9, const [8, 9, 9]);
    expect(a.delta, -2);
    expect(a.needsSideQuest, true);
  });

  test('甜蜜点边缘偏难小幅降档', () {
    final a = calibrator.calibrate(7, const [6]);
    expect(a.delta, -1);
    expect(a.inSweetSpot, true);
  });

  test('甜蜜点边缘偏易且近期偏易则加档', () {
    final a = calibrator.calibrate(3, const [2]);
    expect(a.delta, 1);
  });

  test('suggestionText', () {
    expect(const DifficultyAdjustment(delta: 1, inSweetSpot: false, rationale: '').suggestionText, '加难度 +1');
    expect(const DifficultyAdjustment(delta: 0, inSweetSpot: true, rationale: '').suggestionText, '维持');
    expect(const DifficultyAdjustment(delta: -2, inSweetSpot: false, rationale: '').suggestionText, '降难度 2');
  });

  test('统计辅助函数', () {
    expect(calibrator.average(const [4, 6]), 5);
    expect(calibrator.average(const []), 0);
    expect(calibrator.sweetSpotHitRate(const [3, 5, 7, 9]), 0.75);
    expect(calibrator.describe(5), '5/10（甜蜜点）');
    expect(calibrator.describe(null), '未评分');
  });
}
