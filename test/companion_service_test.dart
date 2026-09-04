import 'package:daily_asking/companion/companion_profile.dart';
import 'package:daily_asking/companion/companion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = CompanionService();

  group('日期规范化与自然日去重', () {
    test('本地日期规范化为 yyyy-MM-dd（补零）', () {
      expect(service.normalizeDate(DateTime(2026, 8, 5)), '2026-08-05');
      expect(service.normalizeDate(DateTime(2026, 12, 31, 23, 59)),
          '2026-12-31');
      expect(service.normalizeDate(DateTime(2027, 1, 1, 0, 1)), '2027-01-01');
    });

    test('同一自然日只计入一次成长，且不重复产生语录', () {
      final first = service.record(CompanionProfile.empty, DateTime(2026, 8, 26, 9));
      expect(first.counted, isTrue);
      expect(first.growthAfter, 1);
      expect(first.quote, isNotNull);

      final second = service.record(first.profile, DateTime(2026, 8, 26, 21));
      expect(second.counted, isFalse);
      expect(second.growthAfter, 1);
      expect(second.profile.countedDates.length, 1);
      expect(second.quote, isNull);
      expect(second.milestone, isNull);
    });

    test('补写历史日期计入一次且不重复', () {
      final p = service.record(CompanionProfile.empty, DateTime(2026, 8, 26)).profile;
      final backfill = service.record(p, DateTime(2026, 8, 1));
      expect(backfill.counted, isTrue);
      expect(backfill.growthAfter, 2);
      final again = service.record(backfill.profile, DateTime(2026, 8, 1));
      expect(again.counted, isFalse);
      expect(again.growthAfter, 2);
    });
  });

  group('阶段边界', () {
    test('0–6 天为小芽（day_01），含首次记录前', () {
      for (final d in [0, 1, 6]) {
        expect(service.stageFor(d), CompanionStage.sprout, reason: 'days=$d');
      }
      expect(CompanionStage.sprout.assetPath, 'assets/companion/day_01.png');
      expect(CompanionStage.sprout.label, '小芽');
    });

    test('7–13 天为花苞（day_07）', () {
      for (final d in [7, 13]) {
        expect(service.stageFor(d), CompanionStage.bud, reason: 'days=$d');
      }
      expect(CompanionStage.bud.assetPath, 'assets/companion/day_07.png');
    });

    test('14–29 天为白花（day_14）', () {
      for (final d in [14, 29]) {
        expect(service.stageFor(d), CompanionStage.bloom, reason: 'days=$d');
      }
      expect(CompanionStage.bloom.assetPath, 'assets/companion/day_14.png');
    });

    test('30 天及以上为粉花（day_30）', () {
      for (final d in [30, 31, 100]) {
        expect(service.stageFor(d), CompanionStage.fullBloom, reason: 'days=$d');
      }
      expect(CompanionStage.fullBloom.assetPath, 'assets/companion/day_30.png');
    });


    test('最小派生月度章节编号', () {
      expect(service.chapterFor(0), 0);
      expect(service.chapterFor(1), 1);
      expect(service.chapterFor(30), 1);
      expect(service.chapterFor(31), 2);
      expect(service.chapterFor(60), 2);
      expect(service.chapterFor(61), 3);
      expect(service.chapterFor(100), 4);
    });
  });

  group('节点首次达成与节点语录', () {
    test('首次记录触发节点 1 并给出节点语录', () {
      final r = service.record(CompanionProfile.empty, DateTime(2026, 8, 26));
      expect(r.milestone, 1);
      expect(r.quoteIsNode, isTrue);
      expect(r.quote, isNotNull);
      expect(r.profile.celebratedMilestones, contains(1));
    });

    test('同一节点后续保存不再重复提示（milestoneDates 门控）', () {
      var p = CompanionProfile.empty;
      for (var i = 1; i <= 6; i++) {
        p = service.record(p, DateTime(2026, 8, i)).profile;
      }
      final r7 = service.record(p, DateTime(2026, 8, 7));
      expect(r7.milestone, 7);
      expect(r7.profile.celebratedMilestones, containsAll([1, 7]));

      // 再记一个新日期：growth 8，不再是节点，也不重复庆祝 7。
      final r8 = service.record(r7.profile, DateTime(2026, 8, 8));
      expect(r8.milestone, isNull);
      expect(r8.quoteIsNode, isFalse);
      expect(r8.profile.celebratedMilestones, containsAll([1, 7]));
    });

    test('节点日语录不可换句', () {
      final p = service.record(CompanionProfile.empty, DateTime(2026, 8, 26)).profile;
      final rr = service.reroll(p, '2026-08-26');
      expect(rr.changed, isFalse);
      expect(rr.canReroll, isFalse);
      expect(rr.isNodeQuote, isTrue);
      expect(rr.quote, service.quoteForDay(p, '2026-08-26'));
    });

    test('节点达成日卡片展示节点语录', () {
      final p = service.record(CompanionProfile.empty, DateTime(2026, 8, 26)).profile;
      expect(service.isCelebrationDay(p, '2026-08-26'), isTrue);
      expect(service.quoteForDay(p, '2026-08-26'),
          '第一粒种子落下了。从今天起，你的每一天都有迹可循。');
    });
  });

  group('普通日语录与有限换句', () {
    test('同一日期语录可复现（确定性、跨运行稳定）', () {
      final p = CompanionProfile.sealed(
        countedDates: {'2026-08-26', '2026-08-10'},
      );
      final a = service.quoteForDay(p, '2026-08-10');
      final b = service.quoteForDay(p, '2026-08-10');
      expect(a, b);
      expect(a, isNotEmpty);
    });

    test('换句在限定次数内变化，超出后拒绝', () {
      // 前置：先计入 08-01 形成第 1 天节点，再计入 08-10 得到普通日
      // （growth=1 的节点日按 spec 拒绝换句，不能作为换句测试底子）。
      var p = service.record(CompanionProfile.empty, DateTime(2026, 8, 1)).profile;
      p = service.record(p, DateTime(2026, 8, 10)).profile; // growth 2 普通日
      final q0 = service.quoteForDay(p, '2026-08-10');
      final r1 = service.reroll(p, '2026-08-10');
      expect(r1.changed, isTrue);
      expect(r1.quote, isNot(q0));

      final r2 = service.reroll(r1.profile, '2026-08-10');
      expect(r2.changed, isTrue);

      final r3 = service.reroll(r2.profile, '2026-08-10');
      expect(r3.changed, isFalse);
      expect(r3.canReroll, isFalse);
      expect(r3.profile.quoteRerolls['2026-08-10'], CompanionService.maxRerollsPerDay);
    });


    test('换句次数按自然日独立：今天换句后补写其他日期，原次数保持', () {
      var p = service.record(CompanionProfile.empty, DateTime(2026, 8, 1)).profile;
      p = service.record(p, DateTime(2026, 8, 10)).profile; // growth 2 普通日
      final q0 = service.quoteForDay(p, '2026-08-10');
      final r1 = service.reroll(p, '2026-08-10');
      expect(r1.changed, isTrue);
      expect(r1.quote, isNot(q0));

      // 补写其他日期：lastQuoteDate 移到补写日，但今天的次数必须保持。
      p = service.record(r1.profile, DateTime(2026, 8, 2)).profile;
      expect(service.quoteForDay(p, '2026-08-10'), r1.quote);
      expect(service.canRerollToday(p, '2026-08-10'), isTrue); // 还剩 1 次

      final r2 = service.reroll(p, '2026-08-10');
      expect(r2.changed, isTrue);
      expect(r2.quote, isNot(r1.quote));
      final r3 = service.reroll(r2.profile, '2026-08-10');
      expect(r3.changed, isFalse); // 用尽本日 2 次
      expect(r3.canReroll, isFalse);
      // 补写日自己的次数互不影响。
      expect(service.quoteForDay(r3.profile, '2026-08-02'), isNotNull);
    });

    test('补写历史日期触发节点：本次事件给节点语录，节点日按触发日期判定', () {
      var p = CompanionProfile.empty;
      for (var i = 1; i <= 6; i++) {
        p = service.record(p, DateTime(2026, 8, i)).profile;
      }
      // 补写 2026-07-31 → growth 7，节点 7 由补写日期触发。
      final r = service.record(p, DateTime(2026, 7, 31));
      expect(r.milestone, 7);
      expect(r.quoteIsNode, isTrue);
      expect(r.quote, isNotNull);
      expect(r.profile.milestoneDates[7], '2026-07-31');

      // 触发日期是节点达成日：07-31（节点 7）、08-01（节点 1）都算；
      // 普通计入日（08-02）不误判。
      expect(service.isCelebrationDay(r.profile, '2026-07-31'), isTrue);
      expect(service.milestoneForDate(r.profile, '2026-07-31'), 7);
      expect(service.isCelebrationDay(r.profile, '2026-08-01'), isTrue);
      expect(service.milestoneForDate(r.profile, '2026-08-01'), 1);
      expect(service.isCelebrationDay(r.profile, '2026-08-02'), isFalse);
      expect(service.canRerollToday(r.profile, '2026-07-31'), isFalse);
      expect(service.quoteForDay(r.profile, '2026-07-31'),
          '第七天，芽尖探出土壤。坚持不是一次用力，是每天一点点。');
      // 普通计入日按普通日语录展示。
      expect(service.quoteForDay(r.profile, '2026-08-02'),
          isNot(contains('芽尖')));
    });

    test('达到更高节点后，旧节点触发日仍是节点日，新日子不误判', () {
      var p = CompanionProfile.empty;
      for (var i = 1; i <= 7; i++) {
        p = service.record(p, DateTime(2026, 8, i)).profile; // 08-07 触发节点 7
      }
      p = service.record(p, DateTime(2026, 8, 8)).profile; // growth 8

      expect(service.isCelebrationDay(p, '2026-08-07'), isTrue); // 第 7 天触发日仍是节点日
      expect(service.milestoneForDate(p, '2026-08-07'), 7);
      expect(service.quoteForDay(p, '2026-08-07'),
          '第七天，芽尖探出土壤。坚持不是一次用力，是每天一点点。');
      expect(service.isCelebrationDay(p, '2026-08-08'), isFalse); // 第 8 天不误判
      expect(service.quoteForDay(p, '2026-08-08'), isNot(contains('芽尖')));
      expect(service.canRerollToday(p, '2026-08-07'), isFalse); // 节点日不可换句
      expect(service.canRerollToday(p, '2026-08-08'), isTrue); // 普通日可换句
    });
  });

  group('命名校验', () {
    test('1–8 个中文或英文字符合法', () {
      expect(service.validateName('小芽'), isNull);
      expect(service.validateName('Sunny'), isNull);
      expect(service.validateName('芽'), isNull);
      expect(service.validateName('一二三四五六七八'), isNull);
      expect(service.validateName(' 阿芽 '), isNull); // 首尾空白会被裁剪
    });

    test('空、超长、数字、符号、空格被拒绝', () {
      expect(service.validateName(''), isNotNull);
      expect(service.validateName('   '), isNotNull);
      expect(service.validateName('一二三四五六七八九'), isNotNull);
      expect(service.validateName('芽123'), isNotNull);
      expect(service.validateName('Sunny Day'), isNotNull);
      expect(service.validateName('小芽！'), isNotNull);
    });
  });
}
