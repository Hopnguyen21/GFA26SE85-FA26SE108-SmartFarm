import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/models.dart';

void main() {
  final json = {
    'id': 't1',
    'zoneId': 'z1',
    'title': 'Tưới',
    'status': 'CompletedPendingReview',
    'dueAtUtc': '2026-11-05T10:00:00Z',
    'assignments': [
      {
        'farmerId': 'f1',
        'farmerName': 'An',
        'status': 'CompletedPendingReview',
        'progressPercent': 100,
        'result': 'Xong',
      },
      {
        'farmerId': 'f2',
        'farmerName': 'Bình',
        'status': 'Pending',
        'progressPercent': 0,
      },
    ],
  };

  test('task reads backend status and every assignment', () {
    final task = TaskModel.fromJson(json);
    expect(task.status, 'CompletedPendingReview');
    expect(task.isCompleted, isTrue);
    expect(task.zoneId, 'z1');
    expect(task.assignments.length, 2);
    expect(task.assignedFarmerName, 'An, Bình');
    expect(task.dueDate, contains('2026'));
    expect(task.dueDate, isNot(contains('T10')));
  });

  test(
    'pending task is not completed and missing due date is not invented',
    () {
      final task = TaskModel.fromJson({
        'id': 't2',
        'title': 'X',
        'status': 'Pending',
      });
      expect(task.isCompleted, isFalse);
      expect(task.dueDate, 'Chưa đặt hạn');
    },
  );

  test('farmer keeps zone access from the API', () {
    final farmer = FarmerModel.fromJson({
      'userId': 'f1',
      'fullName': 'An',
      'role': 'Farmer',
      'farmId': 'farm1',
      'zoneAccess': [
        {'zoneId': 'z1', 'canControl': true},
      ],
    });
    expect(farmer.farmId, 'farm1');
    expect(farmer.zoneAccess.single.zoneId, 'z1');
    expect(farmer.zoneAccess.single.canControl, isTrue);
  });

  test('inventory item maps the API fields', () {
    final item = MaterialInventoryModel.fromJson({
      'id': 'i1',
      'farmId': 'farm1',
      'name': 'NPK',
      'materialType': 'Fertilizer',
      'unit': 'kg',
      'quantityOnHand': 5,
      'lowStockThreshold': 10,
      'isLowStock': true,
    });
    expect(item.category, 'FERTILIZER');
    expect(item.quantity, 5);
    expect(item.isLowStock, isTrue);
  });

  test('auto rule shows readable values and keeps raw data for updates', () {
    final json = {
      'ruleId': 'r1',
      'zoneId': 'z1',
      'name': 'Tưới',
      'parameterCode': 'SoilMoisture',
      'operator': 'LessThan',
      'threshold': 40,
      'actuatorId': 'a1',
      'action': 'TurnOn',
      'durationSeconds': 600,
      'isActive': true,
    };
    final rule = AutomationRuleModel.fromJson(json, actuatorName: 'Bơm');
    expect(rule.operator, '<');
    expect(rule.parameterCode, 'Độ ẩm đất');
    expect(rule.actionDurationMinutes, 10);
    expect(rule.actuatorName, 'Bơm');
    expect(rule.raw, json);
  });
}
