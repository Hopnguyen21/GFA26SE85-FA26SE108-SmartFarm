import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/offline_task_draft_service.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/image_compress.dart';
import '../../../core/utils/user_error.dart';

class TaskResultDialog extends StatefulWidget {
  final TaskModel task;
  final FarmProvider provider;
  const TaskResultDialog({
    super.key,
    required this.task,
    required this.provider,
  });

  @override
  State<TaskResultDialog> createState() => _TaskResultDialogState();
}

class _TaskResultDialogState extends State<TaskResultDialog> {
  late final TextEditingController _ctrl;
  bool _submitting = false;
  bool _uploadingImage = false;
  final List<String> _imageUrls = [];
  String? _localError;
  bool _hasDraftRestored = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _checkOfflineDraft();
  }

  Future<void> _checkOfflineDraft() async {
    final draft = await OfflineTaskDraftService.getDraft(widget.task.taskId);
    if (draft != null && mounted) {
      setState(() {
        if (draft.result.isNotEmpty) _ctrl.text = draft.result;
        _imageUrls.addAll(draft.imageUrls);
        _hasDraftRestored = true;
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage({bool camera = false}) async {
    if (_uploadingImage || _submitting) return;
    setState(() {
      _uploadingImage = true;
      _localError = null;
    });
    try {
      final photo = camera
          ? await ImagePicker().pickImage(source: ImageSource.camera)
          : null;
      final file = camera
          ? null
          : await FilePicker.pickFile(
              type: FileType.custom,
              allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
            );
      if (!mounted || (photo == null && file == null)) return;
      final bytes = photo != null
          ? await photo.readAsBytes()
          : await file!.readAsBytes();
      if (bytes.isEmpty) throw StateError('Ảnh trống.');
      final optimizedBytes = await ImageCompressUtil.optimizeForUpload(bytes);
      if (!mounted) return;
      final upload = await MediaApi.uploadFile(
        bytes: optimizedBytes,
        fileName: ImageCompressUtil.uploadFileName(
          photo?.name ?? file!.name,
          bytes,
          optimizedBytes,
        ),
        folder: 'tasks',
      );
      if (upload.secureUrl.isEmpty)
        throw StateError('Máy chủ chưa trả về địa chỉ ảnh.');
      if (mounted) setState(() => _imageUrls.add(upload.secureUrl));
    } catch (error) {
      if (mounted)
        setState(
          () => _localError = 'Không thể thêm ảnh: ${userFacingError(error)}',
        );
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _localError = 'Vui lòng nhập mô tả kết quả đã làm.');
      return;
    }
    setState(() {
      _submitting = true;
      _localError = null;
    });
    final error = await widget.provider.performTaskAction(
      widget.task.taskId,
      'Complete',
      result: text,
      imageUrls: _imageUrls.isNotEmpty ? _imageUrls : null,
    );
    if (!mounted) return;
    if (error == null) {
      await OfflineTaskDraftService.clearDraft(widget.task.taskId);
      AppHaptics.success();
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      await OfflineTaskDraftService.saveDraft(
        taskId: widget.task.taskId,
        result: text,
        imageUrls: _imageUrls,
      );
      if (!mounted) return;
      AppHaptics.warning();
      setState(() {
        _submitting = false;
        _localError = 'Không thể gửi: $error. Đã lưu bản nháp vào thiết bị.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Nộp Kết Quả Công Việc Thực Địa',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasDraftRestored)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.offline_pin_rounded,
                      size: 16,
                      color: Color(0xFF92400E),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Đã nạp lại bản nháp chưa gửi trước đó trên thiết bị.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    (widget.task.description ?? '').isNotEmpty
                        ? widget.task.description!
                        : 'Kiểm tra và thực hiện công việc được giao tại khu vực.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  Text(
                    widget.task.zoneName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Mô tả kết quả đã làm *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'Ví dụ: Đã kiểm tra xong toàn bộ đầu vòi phun sương, vệ sinh 1 vòi nghẹt, cây phát triển đồng đều...',
                hintStyle: TextStyle(fontSize: 12),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ảnh minh chứng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              children: [
                if (ImagePicker().supportsImageSource(ImageSource.camera))
                  OutlinedButton.icon(
                    onPressed: _submitting || _uploadingImage
                        ? null
                        : () => _pickAndUploadImage(camera: true),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Chụp ảnh'),
                  ),
                OutlinedButton.icon(
                  onPressed: _submitting || _uploadingImage
                      ? null
                      : () => _pickAndUploadImage(),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Chọn ảnh'),
                ),
              ],
            ),
            if (_uploadingImage) const LinearProgressIndicator(),
            if (_imageUrls.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final url = _imageUrls[idx];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 64,
                            height: 64,
                            cacheWidth: 128,
                            cacheHeight: 128,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 64,
                              height: 64,
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(
                                Icons.broken_image_rounded,
                                size: 24,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: _submitting || _uploadingImage
                                ? null
                                : () =>
                                      setState(() => _imageUrls.removeAt(idx)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            if (_localError != null) ...[
              const SizedBox(height: 6),
              Text(
                _localError!,
                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
          ),
          onPressed: _submitting || _uploadingImage ? null : _submit,
          child: Text(_submitting ? 'Đang gửi...' : 'Nộp kết quả'),
        ),
      ],
    );
  }
}
