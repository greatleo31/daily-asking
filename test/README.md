# 架构优化行为测试

这些测试固定 `optimize-app-architecture` 的可观察契约，覆盖：

- `LocalEvidenceRepository` 的 Question/Answer 批量读取与有界存储读取次数；
- `EvidenceService` 的回答回填、未知问题隔离、级联删除和 metrics 聚合；
- `AppState` 的主题、产物、证据领域定向刷新边界。

## 运行

在项目根目录执行：

```text
C:/src/flutter/bin/flutter.bat test test/evidence_repository_test.dart test/evidence_service_test.dart test/app_state_test.dart
C:/src/flutter/bin/flutter.bat analyze
C:/src/flutter/bin/flutter.bat test
```

## 增加用例

优先在对应文件中加入带有具体 Entry、Question、Answer 和字面预期结果的行为用例。读取次数断言应验证批量路径不会随 Entry 数量线性增加；业务断言应验证用户可观察结果与关联实体隔离，不要断言私有字段、调用顺序或其他实现文本。需要真实密钥时从环境变量读取，禁止把凭据写入 fixture。
