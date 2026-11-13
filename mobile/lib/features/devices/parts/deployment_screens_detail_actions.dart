part of '../deployment_screens.dart';

extension _DeploymentRequestDetailScreenStateActions
    on _DeploymentRequestDetailScreenState {
  // ─── Hành động theo role + trạng thái; backend vẫn là nơi kiểm tra cuối cùng ───
  List<Widget> _actions(DeploymentRequest r) {
    final id = r.requestId;
    final buttons = <Widget>[];
    Widget btn(String label, VoidCallback onTap, {bool danger = false}) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                  )
                : null,
            onPressed: _busy ? null : onTap,
            child: Text(label),
          ),
        );

    if (!widget.technician) {
      if (r.status == 'Draft') {
        buttons.add(
          btn('Chỉnh số lượng kế hoạch', () => _editPlan(r, technician: false)),
        );
        buttons.add(
          btn(
            'Gửi yêu cầu cho kỹ thuật viên',
            () => _act(
              () async => DeploymentApi.submitDeploymentRequest(id),
              confirmTitle: 'Gửi yêu cầu',
              confirmBody: 'Sau khi gửi bạn không còn sửa kế hoạch ở bước này.',
            ),
          ),
        );
      }
      if (canCancelDeployment(r.status)) {
        buttons.add(
          btn('Hủy yêu cầu triển khai', () => _cancelRequest(r), danger: true),
        );
      }
    } else {
      switch (r.status) {
        case 'Submitted':
          buttons.add(
            btn(
              'Tiếp nhận yêu cầu',
              () => _act(
                () async => DeploymentApi.acceptDeploymentRequest(id),
                confirmTitle: 'Tiếp nhận',
                confirmBody:
                    'Bạn sẽ chịu trách nhiệm khảo sát và lắp đặt yêu cầu này.',
              ),
            ),
          );
        case 'Accepted':
          buttons.add(btn('Ghi nhận khảo sát địa điểm', () => _survey(r)));
        case 'Surveyed':
          buttons.add(
            btn(
              'Điều chỉnh kế hoạch sau khảo sát',
              () => _editPlan(r, technician: true),
            ),
          );
          buttons.add(btn('Ghi nhận khảo sát khác', () => _survey(r)));
          if (r.latestSurveyFeasible) {
            buttons.add(
              btn(
                'Xác nhận kế hoạch',
                () => _act(
                  () async => DeploymentApi.confirmDeploymentPlan(id),
                  confirmTitle: 'Xác nhận kế hoạch',
                  confirmBody:
                      'Kế hoạch sẽ bị khoá và dùng làm căn cứ cấp phát.',
                ),
              ),
            );
          } else {
            buttons.add(
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Khảo sát mới nhất không khả thi: cần khảo sát khả thi trước khi xác nhận.',
                  style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                ),
              ),
            );
          }
        case 'PlanConfirmed':
          buttons.add(
            btn(
              'Bắt đầu lắp đặt',
              () => _act(
                () async => DeploymentApi.startDeploymentInstallation(id),
                confirmTitle: 'Bắt đầu lắp đặt',
                confirmBody: 'Yêu cầu chuyển sang trạng thái Đang lắp đặt.',
              ),
            ),
          );
        case 'Installing':
          buttons.add(
            btn(
              'Hoàn tất lắp đặt',
              () => _act(
                () async => DeploymentApi.completeDeploymentRequest(id),
                confirmTitle: 'Hoàn tất',
                confirmBody:
                    'Backend chỉ chấp nhận khi mọi thiết bị theo kế hoạch đã gán Zone và có lần kiểm tra kết nối thành công mới nhất.',
              ),
            ),
          );
          buttons.add(
            btn('Báo thất bại & chuyển bảo trì', () => _fail(r), danger: true),
          );
      }
    }
    return buttons;
  }

  Future<void> _editPlan(
    DeploymentRequest r, {
    required bool technician,
  }) async {
    // Kế hoạch đang chỉnh (bắt đầu từ kế hoạch hiện có). Kỹ thuật viên có thể thêm model từ danh mục, kể cả khi kế hoạch đang rỗng.
    final working = <PlanItem>[...r.planItems];
    final qty = {for (final i in r.planItems) i.deviceModelId: i.quantity};
    final notes = {
      for (final i in r.planItems)
        i.deviceModelId: TextEditingController(text: i.installationNotes ?? ''),
    };
    var catalogue = <PlanItem>[];
    String? catalogueError;
    if (technician) {
      try {
        catalogue = await DeploymentApi.getDeploymentPlanModels(r.requestId);
      } catch (e) {
        catalogueError = e.toString().replaceFirst('Exception: ', '');
      }
      if (!mounted) return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Chỉnh kế hoạch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (working.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Kế hoạch chưa có thiết bị. Thêm ít nhất một model để lưu.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                for (final i in working) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          i.modelName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (technician)
                        IconButton(
                          tooltip: 'Bỏ khỏi kế hoạch',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setLocal(() {
                            working.removeWhere(
                              (x) => x.deviceModelId == i.deviceModelId,
                            );
                            notes.remove(i.deviceModelId)?.dispose();
                            qty.remove(i.deviceModelId);
                          }),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Giảm số lượng',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setLocal(
                          () => qty[i.deviceModelId] =
                              ((qty[i.deviceModelId] ?? 1) - 1).clamp(1, 100),
                        ),
                      ),
                      Text('${qty[i.deviceModelId]}'),
                      IconButton(
                        tooltip: 'Tăng số lượng',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setLocal(
                          () => qty[i.deviceModelId] =
                              ((qty[i.deviceModelId] ?? 1) + 1).clamp(1, 100),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: notes[i.deviceModelId],
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú lắp đặt',
                    ),
                  ),
                ],
                if (technician) ...[
                  if (catalogueError != null)
                    Text(
                      'Không tải được danh mục model: $catalogueError',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  for (final m in catalogue.where(
                    (m) =>
                        !working.any((w) => w.deviceModelId == m.deviceModelId),
                  ))
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Sử dụng ${m.modelName}'),
                      onPressed: () => setLocal(() {
                        working.add(m);
                        qty[m.deviceModelId] = m.quantity < 1 ? 1 : m.quantity;
                        notes[m.deviceModelId] = TextEditingController();
                      }),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              // Backend không nhận kế hoạch rỗng.
              onPressed: working.isEmpty ? null : () => Navigator.pop(c, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    final items = [
      for (final i in working)
        PlanItem(
          deviceModelId: i.deviceModelId,
          modelName: i.modelName,
          deviceType: i.deviceType,
          quantity: qty[i.deviceModelId] ?? i.quantity,
          installationNotes: notes[i.deviceModelId]!.text,
        ),
    ];
    for (final c in notes.values) {
      c.dispose();
    }
    if (ok != true || !mounted) return;
    await _act(
      () async => technician
          ? DeploymentApi.updateTechnicianDeploymentPlan(r.requestId, items)
          : DeploymentApi.updateOwnerDeploymentPlan(r.requestId, items),
    );
  }

  Future<void> _survey(DeploymentRequest r) async {
    final input = await askSurvey(context);
    if (input == null || !mounted) return;
    await _act(
      () async => DeploymentApi.surveyDeploymentRequest(
        r.requestId,
        isFeasible: input.feasible,
        siteConditions: input.siteConditions,
        notes: input.notes,
      ),
    );
  }

  Future<void> _fail(DeploymentRequest r) async {
    final code = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Báo triển khai thất bại'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Mã lỗi'),
            ),
            TextField(
              controller: desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Báo thất bại'),
          ),
        ],
      ),
    );
    final codeText = code.text.trim();
    final descText = desc.text.trim();
    code.dispose();
    desc.dispose();
    if (ok != true || !mounted) return;
    if (codeText.isEmpty || descText.isEmpty) {
      _toast(context, 'Cần nhập mã lỗi và mô tả.');
      return;
    }
    await _act(() async {
      final serviceId = await DeploymentApi.failDeploymentRequest(
        r.requestId,
        failureCode: codeText,
        description: descText,
      );
      if (mounted)
        _toast(
          context,
          'Đã chuyển bảo trì, mã service request: ${serviceId.substring(0, 8)}',
        );
    });
  }
}
