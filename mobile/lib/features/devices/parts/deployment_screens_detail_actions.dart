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
    final qty = {for (final i in r.planItems) i.deviceModelId: i.quantity};
    final notes = {
      for (final i in r.planItems)
        i.deviceModelId: TextEditingController(text: i.installationNotes ?? ''),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Chỉnh kế hoạch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final i in r.planItems) ...[
                  Text(
                    i.modelName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    final items = [
      for (final i in r.planItems)
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
    var feasible = true;
    final site = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Khảo sát địa điểm'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Khả thi để lắp đặt'),
                  value: feasible,
                  onChanged: (v) => setLocal(() => feasible = v),
                ),
                TextField(
                  controller: site,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Điều kiện địa điểm',
                  ),
                ),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú khảo sát',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Ghi nhận'),
            ),
          ],
        ),
      ),
    );
    final siteText = site.text.trim();
    final noteText = notes.text.trim();
    site.dispose();
    notes.dispose();
    if (ok != true || !mounted) return;
    if (siteText.isEmpty || noteText.isEmpty) {
      _toast(context, 'Cần nhập điều kiện địa điểm và ghi chú.');
      return;
    }
    await _act(
      () async => DeploymentApi.surveyDeploymentRequest(
        r.requestId,
        isFeasible: feasible,
        siteConditions: siteText,
        notes: noteText,
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
