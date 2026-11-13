import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/models/agriculture_document.dart';
import '../../core/services/api_service.dart';
part 'parts/vietgap_documents_screen_review.dart';

const _green = Color(0xFF10B981);
const _ink = Color(0xFF062326);

class VietGapDocumentsScreen extends StatefulWidget {
  const VietGapDocumentsScreen({super.key});

  @override
  State<VietGapDocumentsScreen> createState() => _VietGapDocumentsScreenState();
}

class _VietGapDocumentsScreenState extends State<VietGapDocumentsScreen> {
  List<AgricultureDocumentModel> _documents = [];
  bool _loading = true;
  bool _uploading = false;
  Object? _error;

  // Chỉ PlatformAdmin được thêm, rà soát/duyệt tài liệu VietGAP và duyệt tài liệu.
  // FarmOwner chỉ được xem danh sách và nội dung tài liệu đã có.
  bool get _canManage => ApiService.userRole?.toLowerCase() == 'platformadmin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await DocumentApi.getAgricultureDocuments();
      if (!mounted) return;
      setState(() => _documents = docs);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'txt'],
    );
    if (picked == null || !mounted) return;

    final length = await picked.length();
    if (length == null || length == 0) {
      _message('Không đọc được file hoặc file rỗng.');
      return;
    }
    if (length > 50 * 1024 * 1024) {
      _message('File vượt giới hạn 50 MB.');
      return;
    }

    // Chỉ cần file: tiêu đề, cây, đơn vị ban hành, phiên bản, loại và chủ đề do server nhận diện từ nội dung.
    if (mounted) setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final doc = await DocumentApi.uploadAgricultureDocument(
        fileName: picked.name,
        bytes: bytes,
      );
      if (!mounted) return;
      await _load();
      _message(
        'Đã lưu "${doc.title}" ở trạng thái chờ duyệt. Hệ thống tự đọc thông tin từ nội dung file '
        '(cây: ${doc.cropScope.isEmpty ? 'chưa xác định' : doc.cropScope}); hãy đối chiếu với file gốc khi duyệt.',
      );
      await _openDocument(doc);
    } catch (error) {
      _message('Tải tài liệu thất bại: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openDocument(AgricultureDocumentModel doc) async {
    await Navigator.push<AgricultureDocumentModel>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VietGapDocumentReviewScreen(document: doc, canManage: _canManage),
      ),
    );
    if (mounted) await _load();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final approved = _documents
        .where((d) => d.reviewStatus == 'Approved')
        .length;
    final pending = _documents.length - approved;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: const Text(
          'Tài liệu VietGAP',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Đồng bộ',
            icon: const Icon(Icons.sync),
          ),
          if (_canManage)
            IconButton(
              onPressed: _uploading ? null : _pickAndUpload,
              tooltip: 'Tải tài liệu',
              icon: const Icon(Icons.upload_file),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _error != null
          ? _errorPanel()
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: _countCard(
                          'Tổng tài liệu',
                          '${_documents.length}',
                          Icons.description_outlined,
                          _ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _countCard(
                          'Đã duyệt',
                          '$approved',
                          Icons.verified_outlined,
                          _green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _countCard(
                          'Chờ rà soát',
                          '$pending',
                          Icons.fact_check_outlined,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_uploading)
                  const LinearProgressIndicator(minHeight: 3, color: _green),
                Expanded(
                  child: _documents.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _documents.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _documentCard(_documents[index]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: _canManage && !_loading
          ? FloatingActionButton.extended(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              onPressed: _uploading ? null : _pickAndUpload,
              icon: const Icon(Icons.add),
              label: const Text('Tải tài liệu'),
            )
          : null,
    );
  }

  Widget _countCard(String label, String count, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(height: 4),
            Text(
              count,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      );

  Widget _documentCard(AgricultureDocumentModel doc) {
    final isApproved = doc.reviewStatus == 'Approved';
    final color = isApproved
        ? _green
        : doc.reviewStatus == 'NeedsCorrection'
        ? Colors.red
        : Colors.orange;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.28)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDocument(doc),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Color(0xFFBE123C),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${doc.cropScope.isEmpty ? 'Chưa ghi cây trồng' : doc.cropScope} · ${doc.fileType.toUpperCase()}${doc.version == null ? '' : ' · ${doc.version}'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black38),
                ],
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _pill(
                    doc.statusLabel,
                    color,
                    isApproved ? Icons.verified : Icons.pending_actions,
                  ),
                  _pill(
                    doc.hasOriginalFile ? 'Có file gốc' : 'Không có file gốc',
                    doc.hasOriginalFile ? _ink : Colors.orange,
                    Icons.attach_file,
                  ),
                ],
              ),
              if (!isApproved && !doc.isProfileAllowed)
                const Padding(
                  padding: EdgeInsets.only(top: 9),
                  child: Text(
                    'Cần rà soát và duyệt trước khi dùng tạo profile/RAG.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _emptyState() => ListView(
    children: [
      const SizedBox(height: 90),
      Icon(Icons.library_books_outlined, size: 48, color: Colors.grey[400]),
      const SizedBox(height: 12),
      const Center(
        child: Text(
          'Chưa có tài liệu VietGAP',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
        ),
      ),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _canManage
                ? 'Chọn file PDF, DOCX hoặc TXT để bắt đầu. Thông tin tài liệu được đọc tự động.'
                : 'Tài liệu VietGAP do quản trị viên nền tảng thêm và duyệt.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ),
      ),
    ],
  );

  Widget _errorPanel() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 44, color: Colors.orange),
          const SizedBox(height: 12),
          Text(
            'Không tải được kho tài liệu: $_error',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}

extension on AgricultureDocumentModel {
  bool get isProfileAllowed => reviewStatus == 'Approved';
}
