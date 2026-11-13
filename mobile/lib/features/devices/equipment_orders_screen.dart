import 'package:flutter/material.dart';
import 'legacy_redirect.dart';

class EquipmentOrdersScreen extends StatelessWidget {
  const EquipmentOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const LegacyFlowRedirectScreen(title: 'Đơn thiết bị');
}
