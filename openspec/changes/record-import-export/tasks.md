# tasks — record-import-export

> 约定：每个任务可独立验证；带 🧪 的测试任务与对应实现任务成对出现。开工前需 1.1 全绿。

## 1. 前置

- [x] 1.1 🧪 基线：Git 仅有批准的 OpenSpec 未跟踪文档，无已跟踪文件修改、`flutter analyze` 0 issue、逐文件 `flutter test` 全绿（全量 `flutter test` 在本机会卡死，用 `scratchpad/<session>/run_tests.py` 逐文件跑）
- [x] 1.2 加依赖 `file_picker` 到 `pubspec.yaml`，`flutter pub get` 成功；若拉取失败走 design §6 的原生通道退路并在此记录

## 2. 交换格式与解析（纯逻辑，无 UI）

- [x] 2.1 实现 `lib/core/transfer/transfer_schema.dart`：schema 常量、v2 组装、按 schema 串分派、旧 v1 的 `date` 回落、逐条字段校验（必填缺失 / 未知枚举只判该条失败）
- [ ] 2.2 🧪 `test/transfer_schema_test.dart`：v2 导出→导入往返条目等价；未知 schema、`schemaVersion > 2` 整文件拒绝；缺必填判该条失败；未知 `kind`/`status` 不抛异常
- [x] 2.3 实现 `lib/core/transfer/import_parser.dart`：Markdown 严格状态机（标题识别、`## 证据 N` 分节吸收、已知标签、多行正文、追问行、完整度重算、忽略行计数、非法条记录原因）
- [ ] 2.4 🧪 `test/import_parser_test.dart`：往返解析；正文伪造 `**任务**：`/`**完整度**：100%` 不被采信；分节标题不误开新记录；空文件 / 无有效记录 / 超 5000 条 / 非 UTF-8 的失败路径

## 3. 导入规划与落盘

- [x] 3.1 实现 `lib/core/transfer/import_plan.dart`：id 判重、指纹判重（`yyyy-MM-dd|规范化task`）、连带跳过、时间戳取原记录日期、`#导入-YYYYMMDD` 标记、增删跳过的计数汇总
- [ ] 3.2 🧪 `test/import_plan_test.dart`：同 id 跳过、同指纹跳过、entry 跳过时其 question/answer 连带跳过、时间戳与标签正确、报告计数与失败原因可读
- [ ] 3.3 三个 Repository 各加 `saveAll(List<T>)`（内存合并 + 单次 `_persist`）；🧪 补/扩现有 repository 测试，证明 N 条只触发一次写回且不改变既有 `save` 行为
- [ ] 3.4 `AppState.importEntries(plan)`：批量写 entries/questions/answers → 刷新内存快照 → `notifyListeners()`；**不调用** `_recordCompanionGrowth`；🧪 断言导入后伙伴成长阶段不变、记录列表按 `createdAt` 倒序含新记录
- [x] 3.5 `lib/core/transfer/data_transfer_service.dart`：读文件（含 UTF-8 校验、大小/条数上限）→ 解析 → 规划 → 自动快照（`backup/auto-<时间戳>.json`，保留最近 3 份）→ 批量落盘 → 返回结果报告
- [ ] 3.6 🧪 服务层单测：上限拒绝、非 UTF-8 拒绝、快照只在确认后写入且只保留 3 份、部分失败仍写入合法条

## 4. 结构化导出

- [x] 4.1 `lib/core/export/markdown_exporter.dart` 增加 JSON 导出组装与文件名（`daily-asking-export-<yyyyMMdd-HHmm>.json`），复用现有原生写文件 + 分享通道
- [ ] 4.2 🧪 断言导出内容可被 2.1 的解析器读回、且**不含** API Key / LLM 配置 / 主题设置
- [x] 4.3 基线 `test/markdown_export_test.dart` 已通过；按用户最新要求不安排最终既有功能回归（不表示变更后已重新通过）。

## 5. UI

- [x] 5.1 泛化 `GenerationWaitingOverlay`（通用文案参数、`ArtifactType` 可选），工作室调用点改新参数
- [ ] 5.2 🧪 `test/generation_waiting_overlay_test.dart` 全绿：工作室原有文案与行为不变，通用文案可用
- [x] 5.3 设置页插入「数据」组：「导出数据（可再导入）」「导入记录」「上次自动备份：…」
- [x] 5.4 预览页：三数字 + 可展开清单（>50 只渲染前 50 并注明总数）+ Markdown 损失提示 + 取消/确认
- [x] 5.5 结果页：三数字与失败原因清单 + 「查看导入的记录」（关结果页并切到记录 Tab）
- [ ] 5.6 🧪 `test/import_ui_test.dart`：预览/结果页文案与截断、拒绝类错误文案（UTF-8 / 10 MB / 5000 条 / 更新版本 / 无法识别格式）、导入中蒙层挡住返回
- [ ] 5.7 工作室出站确认补「将发送 N 条记录」；🧪 断言条数随选择变化

## 6. 收尾

- [ ] 6.1 按用户 2026-09-17 最新指示，仅运行新增功能定向测试（主代理当前串行执行，结果待确认）；不做最终全量回归。
- [ ] 6.2 主代理构建 APK 并安装雷电模拟器（待确认）；安装后用户自行验收：导出 JSON → 回灌（应全部跳过）；导入 App 自产 Markdown（应新增且标注不完整解析）；导入手工构造的旧 v1 JSON（`date` 回落生效）；导入后伙伴成长阶段不变
- [ ] 6.3 设备验收由用户自行完成，截图按用户需要提供；当前不得标记设备验收通过。
- [x] 6.4 `CHANGELOG.md` 补 `[1.2.6]`；版本文档与发版流程另行确认（本 change 不含发版）

## 7. 2026-09-17 批准修订与当前交付状态

- [x] 7.1 开工基线：analyze 0 issue，原有 30/30 测试文件逐个通过，0 失败/超时。
- [x] 7.2 功能实现已完成：格式/解析/规划/批量持久化/预览结果/分享，以及超限普通 v2 分片、整批快照与最近三批保留。上方混合实现+测试任务中的未勾选项表示验证待确认，不表示代码缺失。
- [x] 7.3 新增 `test/transfer_backup_store_test.dart`：混合普通/分片最近三批、同秒不覆盖、pending 排除、6000 条落盘分片逐片独立解析（含关联数据）。
- [ ] 7.4 主代理确认新增功能定向测试结果；当前正在运行，尚未宣称最终功能测试通过。
- [ ] 7.5 主代理构建并安装 APK 到雷电模拟器；用户自行设备验收。

本修订覆盖旧最终全回归要求：用户明确只测新功能，不跑全量回归。各测试任务在主代理确认实际结果前保持未完成；版本号与正式发布仍另行授权。
