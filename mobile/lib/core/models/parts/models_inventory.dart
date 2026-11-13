part of '../models.dart';

// ─────────────────────────────────────────
// Kho Vật Tư Nông Nghiệp (Farm Material Stock)
// ─────────────────────────────────────────
class MaterialInventoryModel {
  final String inventoryId;
  final String farmId;
  final String materialName;
  final String code;
  final String category; // 'FERTILIZER', 'SEED', 'PESTICIDE', 'EQUIPMENT'
  final double quantity;
  final String unit;
  final double minimumStock;
  final String storageLocation;
  final String updatedAt;

  bool get isLowStock => quantity <= minimumStock;

  const MaterialInventoryModel({
    required this.inventoryId,
    required this.farmId,
    required this.materialName,
    required this.code,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.minimumStock,
    required this.storageLocation,
    required this.updatedAt,
  });

  factory MaterialInventoryModel.fromJson(Map<String, dynamic> json) =>
      MaterialInventoryModel(
        inventoryId: json['id']?.toString() ?? '',
        farmId: json['farmId']?.toString() ?? '',
        materialName: json['name']?.toString() ?? '',
        code: '',
        category: switch (json['materialType']?.toString()) {
          'Seed' => 'SEED',
          'Fertilizer' => 'FERTILIZER',
          'Pesticide' => 'PESTICIDE',
          _ => 'EQUIPMENT',
        },
        quantity: (json['quantityOnHand'] as num?)?.toDouble() ?? 0,
        unit: json['unit']?.toString() ?? '',
        minimumStock: (json['lowStockThreshold'] as num?)?.toDouble() ?? 0,
        storageLocation: '',
        updatedAt: '',
      );

  MaterialInventoryModel copyWith({
    double? quantity,
    double? minimumStock,
    String? storageLocation,
    String? updatedAt,
  }) {
    return MaterialInventoryModel(
      inventoryId: inventoryId,
      farmId: farmId,
      materialName: materialName,
      code: code,
      category: category,
      quantity: quantity ?? this.quantity,
      unit: unit,
      minimumStock: minimumStock ?? this.minimumStock,
      storageLocation: storageLocation ?? this.storageLocation,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
