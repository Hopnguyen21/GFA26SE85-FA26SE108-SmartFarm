import 'package:flutter/material.dart';
import '../../../core/models/iot_deployment.dart';
import '../../../core/theme/app_theme.dart';
import '../deployment_board_logic.dart';

/// Màu theo trạng thái yêu cầu triển khai (dùng chung bảng việc, chi tiết và thanh tiến trình).
Color deploymentStatusColor(String status) => switch (status) {
  'Completed' => AppColors.primaryDark,
  'MaintenanceRequired' => AppColors.danger,
  'Draft' || 'Cancelled' => AppColors.textMuted,
  _ => AppColors.info,
};

/// Thanh tiến trình các bước của yêu cầu triển khai. Bước đã xong màu xanh, bước hiện tại màu theo trạng thái
/// (đỏ khi thất bại), bước chưa tới màu xám. [compact] chỉ vẽ thanh và dòng "Bước x/6".
class DeploymentProgressBar extends StatelessWidget {
  final String status;
  final bool compact;
  const DeploymentProgressBar({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final current = deploymentStepIndex(status);
    final failed = status == 'MaintenanceRequired';
    final currentColor = deploymentStatusColor(status);
    final total = deploymentSteps.length;

    Color segmentColor(int i) {
      if (current < 0) return AppColors.border;
      if (i < current) return AppColors.primaryDark;
      if (i == current) {
        return status == 'Completed' ? AppColors.primaryDark : currentColor;
      }
      return AppColors.border;
    }

    final bar = Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: segmentColor(i),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );

    if (compact) {
      final label = current < 0
          ? 'Chưa gửi'
          : 'Bước ${current + 1}/$total · ${deploymentStatusLabels[status] ?? status}';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar,
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: failed ? AppColors.danger : AppColors.textMuted,
              fontWeight: failed ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bar,
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    deploymentSteps[i].label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: i == current
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: i == current
                          ? (failed ? AppColors.danger : AppColors.text)
                          : AppColors.textFaint,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Khung "Việc tiếp theo" nổi bật cho kỹ thuật viên; không vẽ gì nếu không còn việc.
class NextStepBanner extends StatelessWidget {
  final String status;
  const NextStepBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final hint = deploymentNextStepHint(status);
    if (hint == null) return const SizedBox.shrink();
    final failed = status == 'MaintenanceRequired';
    final color = failed ? AppColors.danger : AppColors.info;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: failed ? AppColors.dangerSoft : AppColors.infoSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            failed ? Icons.build_circle_outlined : Icons.flag_outlined,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Việc tiếp theo: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: hint),
                ],
              ),
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
