import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/ai/ai_payload_sheet.dart';
import 'package:smartfarm_mobile/features/ai/ai_payload_snapshot.dart';

final _pascal = jsonEncode({
  'SystemPrompt': 'Chỉ tư vấn, không tự bật thiết bị.',
  'Prompt': '<context>soil=52.4</context>',
  'Context': {
    'Telemetry': [
      {
        'ParameterCode': 'SOIL_MOISTURE',
        'Value': 52.4,
        'Unit': '%',
        'IsFresh': true,
        'CapturedAtUtc': '2026-11-25T10:30:00Z',
      },
      {
        'ParameterCode': 'AIR_TEMP',
        'Value': 30,
        'Unit': '°C',
        'IsFresh': false,
      },
    ],
    'Requirements': [
      {
        'ParameterCode': 'SOIL_MOISTURE',
        'MinValue': 55,
        'TargetValue': 65.5,
        'MaxValue': 75,
        'Unit': '%',
      },
    ],
  },
  'Passages': [
    {
      'DocumentTitle': 'TCVN 11892-1',
      'AuthorOrganization': 'Bộ KH&CN',
      'SimilarityScore': 0.82,
      'Content': 'Tưới đủ ẩm theo giai đoạn sinh trưởng.',
    },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiPayloadSnapshot.tryParse', () {
    test('khoá PascalCase: cảm biến, ngưỡng, RAG, prompt', () {
      final s = AiPayloadSnapshot.tryParse(_pascal)!;
      expect(s.telemetry.length, 2);
      expect(s.telemetry[0].parameter, 'SOIL_MOISTURE');
      expect(s.telemetry[0].valueText, '52.4 %');
      expect(s.telemetry[0].isFresh, isTrue);
      expect(s.telemetry[0].capturedAt, isNotNull);
      expect(s.telemetry[1].valueText, '30 °C'); // số nguyên không có ".0"
      expect(s.telemetry[1].isFresh, isFalse);
      expect(s.requirements.single.min, '55');
      expect(s.requirements.single.target, '65.5');
      expect(s.passages.single.similarityPercent, 82);
      expect(s.passages.single.organization, 'Bộ KH&CN');
      expect(s.prompt, contains('soil=52.4'));
      expect(s.systemPrompt, contains('không tự bật'));
      expect(s.summary, '2 cảm biến · 1 ngưỡng VietGAP · 1 tài liệu RAG');
      expect(s.isEmpty, isFalse);
    });

    test('khoá camelCase cho cùng nội dung', () {
      final s = AiPayloadSnapshot.tryParse(
        jsonEncode({
          'prompt': 'p',
          'context': {
            'telemetry': [
              {'parameterCode': 'AIR_HUMIDITY', 'value': 68.2, 'unit': '%'},
            ],
            'requirements': [
              {'parameterCode': 'AIR_HUMIDITY', 'minValue': 60, 'maxValue': 80},
            ],
          },
          'passages': [
            {'category': 'Nông học', 'content': 'x'},
          ],
        }),
      )!;
      expect(s.telemetry.single.valueText, '68.2 %');
      expect(
        s.telemetry.single.isFresh,
        isNull,
      ); // backend không báo thì không đoán
      expect(s.requirements.single.target, '—');
      expect(s.passages.single.title, 'Nông học');
      expect(s.passages.single.similarityPercent, isNull);
    });

    test('rỗng, hỏng hoặc không phải object: null', () {
      expect(AiPayloadSnapshot.tryParse(null), isNull);
      expect(AiPayloadSnapshot.tryParse('  '), isNull);
      expect(AiPayloadSnapshot.tryParse('{hỏng'), isNull);
      expect(AiPayloadSnapshot.tryParse('[1,2]'), isNull);
    });

    test('object không có dữ liệu hữu ích: isEmpty', () {
      expect(AiPayloadSnapshot.tryParse('{}')!.isEmpty, isTrue);
    });
  });

  group('AiPayloadSheet', () {
    Future<void> pumpSheet(WidgetTester t) async {
      t.view.physicalSize = const Size(430, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiPayloadSheet(
              snapshot: AiPayloadSnapshot.tryParse(_pascal)!,
            ),
          ),
        ),
      );
      await t.pump();
    }

    testWidgets('hiện tiêu đề, tóm tắt và số lượng ở từng tab', (t) async {
      await pumpSheet(t);
      expect(find.text('Dữ liệu AI đã dùng'), findsOneWidget);
      expect(
        find.text('2 cảm biến · 1 ngưỡng VietGAP · 1 tài liệu RAG'),
        findsOneWidget,
      );
      expect(find.text('Cảm biến (2)'), findsOneWidget);
      expect(find.text('Ngưỡng VietGAP (1)'), findsOneWidget);
      expect(find.text('RAG VietGAP (1)'), findsOneWidget);
      // Tab đầu: số đo và độ tươi.
      expect(find.text('52.4 %'), findsOneWidget);
      expect(find.text('Tươi mới'), findsOneWidget);
      expect(find.text('Cũ (stale)'), findsOneWidget);
    });

    testWidgets('chuyển tab ngưỡng và RAG', (t) async {
      await pumpSheet(t);
      await t.tap(find.text('Ngưỡng VietGAP (1)'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Min 55 · Mục tiêu 65.5 · Max 75 %'), findsOneWidget);
      await t.ensureVisible(find.text('RAG VietGAP (1)'));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('RAG VietGAP (1)'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('#1 TCVN 11892-1'), findsOneWidget);
      expect(find.text('Tương đồng 82%'), findsOneWidget);
      expect(find.textContaining('Bộ KH&CN'), findsOneWidget);
    });

    testWidgets('sao chép: tab Prompt chép prompt, tab khác chép JSON', (
      t,
    ) async {
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpSheet(t);
      await t.tap(find.byTooltip('Sao chép'));
      await t.pump();
      expect(copied, contains('"SystemPrompt"')); // tab 1: JSON đầy đủ
      expect(find.text('Đã sao chép'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      await t.ensureVisible(find.text('Prompt'));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Prompt'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byTooltip('Sao chép'));
      await t.pump();
      expect(copied, '<context>soil=52.4</context>'); // tab Prompt
    });
  });
}
