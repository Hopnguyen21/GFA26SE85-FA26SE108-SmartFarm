import 'package:flutter/material.dart';
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
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.alt_route_rounded,
                        size: 16,
                        color: Color(0xFF047857),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Quy trình lắp đặt',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Expanded(
                      child: _step(
                        i + 1,
                        steps[i],
                        isFirst: i == 0,
                        isLast: i == steps.length - 1,
                        prevDone:
                            i > 0 && steps[i - 1].state == FlowStepState.done,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(
    int n,
    ({String label, FlowStepState state}) s, {
    required bool isFirst,
    required bool isLast,
    required bool prevDone,
  }) {
    final done = s.state == FlowStepState.done;
    final current = s.state == FlowStepState.current;
    final leftLineColor = isFirst
        ? Colors.transparent
        : (done || (current && prevDone)
              ? const Color(0xFF047857)
              : const Color(0xFFE2E8F0));
    final rightLineColor = isLast
        ? Colors.transparent
        : (done ? const Color(0xFF047857) : const Color(0xFFE2E8F0));

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
          Row(
            children: [
              Expanded(child: Container(height: 2.5, color: leftLineColor)),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? const Color(0xFF047857)
                      : current
                      ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                      : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: done
                        ? const Color(0xFF047857)
                        : current
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFCBD5E1),
                    width: current ? 2 : 1.2,
                  ),
                  boxShadow: done
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF047857,
                            ).withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ]
                      : null,
                ),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : Text(
                        '$n',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: current
                              ? const Color(0xFF0284C7)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
              ),
              Expanded(child: Container(height: 2.5, color: rightLineColor)),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              s.label,
              textAlign: TextAlign.center,
              maxLines: 3,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: current
                    ? FontWeight.w800
                    : (done ? FontWeight.w600 : FontWeight.w500),
                color: done
                    ? const Color(0xFF0F172A)
                    : current
                    ? const Color(0xFF0284C7)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
