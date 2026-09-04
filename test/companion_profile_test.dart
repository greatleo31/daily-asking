import 'dart:convert';

import 'package:daily_asking/companion/companion_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompanionProfile 序列化', () {
    test('JSON 往返一致（含节点触发日期与双写字段）', () {
      final p = CompanionProfile.sealed(
        name: '小芽',
        countedDates: {'2026-08-26', '2026-08-27'},
        lastQuoteDate: '2026-08-27',
        quoteRerolls: {'2026-08-27': 1},
        milestoneDates: {1: '2026-08-26', 7: null},
      );
      final back = CompanionProfile.fromJson(p.toJson());
      expect(back.name, '小芽');
      expect(back.countedDates, {'2026-08-26', '2026-08-27'});
      expect(back.lastQuoteDate, '2026-08-27');
      expect(back.quoteRerolls, {'2026-08-27': 1});
      expect(back.milestoneDates, {1: '2026-08-26', 7: null});
      expect(back.celebratedMilestones, [1, 7]);
      expect(back.growthDays, 2);
    });

    test('空资料默认值', () {
      const p = CompanionProfile.empty;
      expect(p.name, isNull);
      expect(p.countedDates, isEmpty);
      expect(p.celebratedMilestones, isEmpty);
      expect(p.milestoneDates, isEmpty);
      expect(p.lastQuoteDate, isNull);
      expect(p.quoteRerolls, isEmpty);
      expect(p.growthDays, 0);
      final back = CompanionProfile.fromJson(const {});
      expect(back.name, isNull);
      expect(back.growthDays, 0);
    });

    test('未知字段忽略，错误容器与错误类型按默认兼容且不抛异常', () {
      final p = CompanionProfile.fromJson(jsonDecode('''
      {
        "unknownField": "ignored",
        "name": 42,
        "countedDates": "not-a-list",
        "milestoneDates": [1, 2],
        "lastQuoteDate": 123,
        "quoteRerolls": {"2026-08-01": 2, "bad": 3, "2026-08-02": -1}
      }
      ''') as Map<String, dynamic>);
      expect(p.name, isNull);
      expect(p.countedDates, isEmpty); // 错误容器类型被忽略
      expect(p.milestoneDates, isEmpty); // 错误容器类型被忽略
      expect(p.lastQuoteDate, isNull);
      expect(p.quoteRerolls, {'2026-08-01': 2}); // 非法键与负数被过滤
      expect(p.growthDays, 0);
    });

    test('countedDates 与 milestoneDates 中的非法值被过滤', () {
      final p = CompanionProfile.fromJson(jsonDecode('''
      {
        "countedDates": ["2026-08-01", "bad-date", 7, "2026-8-1"],
        "milestoneDates": {"1": "2026-08-01", "7": "bad", "14": 3, "99": "2026-08-02", "x": "2026-08-03"}
      }
      ''') as Map<String, dynamic>);
      expect(p.countedDates, {'2026-08-01'});
      expect(p.milestoneDates, {1: '2026-08-01'}); // 7 非法日期、14 非字符串、99 非节点、x 非数字键被过滤
      expect(p.celebratedMilestones, [1]);
    });

    test('真实日期校验：格式正确但不存在/越界的日期被过滤', () {
      final p = CompanionProfile.fromJson(jsonDecode('''
      {
        "countedDates": ["2026-02-30", "2026-13-01", "2026-08-31", "2026-04-31", "2026-02-29"],
        "lastQuoteDate": "2026-02-29",
        "quoteRerolls": {"2026-02-29": 1}
      }
      ''') as Map<String, dynamic>);
      // 2026 非闰年：02-29 不存在；02-30、13-01、04-31 均不存在。
      expect(p.countedDates, {'2026-08-31'});
      expect(p.lastQuoteDate, isNull);
      expect(p.quoteRerolls, isEmpty);
    });

    test('fromJson 校验名称：非 1–8 中文/英文字符被置空', () {
      expect(CompanionProfile.fromJson(const {'name': '小芽'}).name, '小芽');
      expect(CompanionProfile.fromJson(const {'name': 'Sunny'}).name, 'Sunny');
      expect(CompanionProfile.fromJson(const {'name': '名字太长了超过八个字'}).name, isNull);
      expect(CompanionProfile.fromJson(const {'name': '芽123'}).name, isNull);
      expect(CompanionProfile.fromJson(const {'name': 42}).name, isNull);
    });

    test('旧版本 celebratedMilestones 迁移：标记已庆祝但无触发日期', () {
      final p = CompanionProfile.fromJson(const {
        'celebratedMilestones': [1, 7],
      });
      expect(p.celebratedMilestones, [1, 7]);
      expect(p.milestoneDates, {1: null, 7: null});
    });

    test('toJson 双写 celebratedMilestones 与 milestoneDates（旧版本降级兼容）', () {
      final json = CompanionProfile.sealed(
        countedDates: {'2026-08-01'},
        milestoneDates: {1: '2026-08-01', 7: null},
      ).toJson();
      expect(json['celebratedMilestones'], [1, 7]);
      expect(json['milestoneDates'], {'1': '2026-08-01', '7': null});
      // 旧版本读取路径：只读 celebratedMilestones 仍能恢复「已庆祝」标记。
      final legacyRead = CompanionProfile.fromJson({
        'celebratedMilestones': (json['celebratedMilestones'] as List).cast<int>(),
      });
      expect(legacyRead.celebratedMilestones, [1, 7]);
      expect(legacyRead.milestoneDates, {1: null, 7: null});
    });

    test('toJson 输出确定性（日期与节点排序）', () {
      final json = CompanionProfile.sealed(
        countedDates: {'2026-08-27', '2026-08-26'},
        milestoneDates: {14: '2026-09-01', 1: '2026-08-26'},
        quoteRerolls: {'2026-08-27': 1},
      ).toJson();
      expect(json['countedDates'], ['2026-08-26', '2026-08-27']);
      expect(json['celebratedMilestones'], [1, 14]);
      expect(json['milestoneDates'], {'1': '2026-08-26', '14': '2026-09-01'});
    });
  });

  group('CompanionProfile 不可变快照', () {
    test('sealed 构造的集合字段不可被外部 mutate', () {
      final p = CompanionProfile.sealed(
        countedDates: {'2026-08-01'},
        quoteRerolls: {'2026-08-01': 1},
        milestoneDates: {1: '2026-08-01'},
      );
      expect(() => p.countedDates.add('2026-08-02'), throwsUnsupportedError);
      expect(() => p.quoteRerolls['2026-08-02'] = 1, throwsUnsupportedError);
      expect(() => p.milestoneDates[7] = '2026-08-07', throwsUnsupportedError);
      expect(() => p.celebratedMilestones.add(7), throwsUnsupportedError);
    });

    test('fromJson 与 empty 同样是不可变快照', () {
      final p = CompanionProfile.fromJson(const {
        'countedDates': ['2026-08-01'],
        'quoteRerolls': {'2026-08-01': 1},
      });
      expect(() => p.countedDates.add('2026-08-02'), throwsUnsupportedError);
      expect(() => p.quoteRerolls.clear(), throwsUnsupportedError);
      expect(
          () => CompanionProfile.empty.countedDates.add('x'),
          throwsUnsupportedError);
    });
  });
}
