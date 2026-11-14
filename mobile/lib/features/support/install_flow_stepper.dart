import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'service_board_logic.dart';

/// Thanh 4 bước của quy trình lắp đặt (giống mô tả quy trình ở đầu trang Lắp đặt trên web):
/// báo giá & hợp đồng → Owner ký & cọc 30% → thi công & chấm node → nghiệm thu 70%.
class InstallFlowStepper extends StatelessWidget {
  final String? quotationStatus;
  final String? deploymentStatus;
  final bool closed;
  final String? depositLabel;
  final String? remainingLabel;
  const InstallFlowStepper({
    super.key,
    required this.quotationStatus,
    required this.deploymentStatus,
    required this.closed,
    this.depositLabel,
    this.remainingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final steps = installFlowSteps(
      quotationStatus: quotationStatus,
      deploymentStatus: deploymentStatus,
      closed: closed,
      depositLabel: depositLabel,
      remainingLabel: remainingLabel,
    );
    return Semantics(
      container: true,
      label: 'Quy trình lắp đặt',
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 8),
                child: Text(
                  'Quy trình lắp đặt',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Expanded(child: _step(i + 1, steps[i])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(int n, ({String label, FlowStepState state}) s) {
    final done = s.state == FlowStepState.done;
    final current = s.state == FlowStepState.current;
    final color = done
        ? AppColors.primaryDark
        : current
        ? AppColors.info
        : AppColors.textMuted;
    return Semantics(
      label:
          'Bước $n: ${s.label}, ${done
              ? 'đã xong'
              : current
              ? 'đang làm'
              : 'chưa tới'}',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? color : color.withValues(alpha: 0.1),
              border: Border.all(color: color, width: current ? 2 : 1),
            ),
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '$n',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              s.label,
              textAlign: TextAlign.center,
              maxLines: 3,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.2,
                fontWeight: current ? FontWeight.w800 : FontWeight.w500,
                color: done || current ? AppColors.text : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
