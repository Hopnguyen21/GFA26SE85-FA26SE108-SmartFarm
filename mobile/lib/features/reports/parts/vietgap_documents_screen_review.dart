part of '../vietgap_documents_screen.dart';

class VietGapDocumentReviewScreen extends StatefulWidget {
  final AgricultureDocumentModel document;
  final bool canManage;

  const VietGapDocumentReviewScreen({super.key, required this.document, required this.canManage});

  @override
  State<VietGapDocumentReviewScreen> createState() => _VietGapDocumentReviewScreenState();
}

class _VietGapDocumentReviewScreenState extends State<VietGapDocumentReviewScreen> {
  late final TextEditingController _content;
  final _notes = TextEditingController();
  AgricultureDocumentModel? _document;
  bool _loading = true;
  bool _saving = false;
  bool _downloading = false;
  bool _confirmed = false;

  // Metadata người duyệt có thể chỉnh (khởi tạo từ giá trị hệ thống đã nhận diện).
  final _title = TextEditingController();
  final _crop = TextEditingController();
  final _author = TextEditingController();
  final _version = TextEditingController();
  String _type = 'Unspecified';
  bool _confirmGeneral = false;

  static const _typeLabels = <String, String>{
    'Unspecified': 'Chưa xác định',
    'OfficialStandard': 'Tiêu chuẩn / quy chuẩn chính thức',
    'TechnicalGuide': 'Hướng dẫn / quy trình kỹ thuật',
    'Thematic': 'Tài liệu chuyên đề',
  };

  void _syncMeta(AgricultureDocumentModel d) {
    _title.text = d.title;
    _crop.text = d.cropScope;
    _author.text = d.authorOrganization ?? '';
    _version.text = d.version ?? '';
    _type = _typeLabels.containsKey(d.documentType) ? d.documentType : 'Unspecified';
    _confirmGeneral = d.metadataDetection?['generalScopeConfirmed'] == true;
  }

  AgricultureDocumentModel get _doc => _document ?? widget.document;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: widget.document.contentText ?? '');
    _notes.text = widget.document.reviewNotes ?? '';
    _syncMeta(widget.document);
    _load();
  }

  @override
  void dispose() {
    _content.dispose();
    _notes.dispose();
    _title.dispose();
    _crop.dispose();
    _author.dispose();
    _version.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final doc = await DocumentApi.getAgricultureDocument(widget.document.id);
      if (!mounted) return;
      setState(() {
        _document = doc;
        _content.text = doc.contentText ?? '';
        _notes.text = doc.reviewNotes ?? '';
        _syncMeta(doc);
      });
    } catch (error) {
      _showMessage('Không tải được chi tiết tài liệu: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, bool> get _checks {
    final text = _content.text;
    return {
      'Nội dung đọc được (ít nhất 50 ký tự)': text.trim().length >= 50,
      'Mã tiêu chuẩn hoặc từ khóa VietGAP': RegExp(r'TCVN\s*\d|Viet\s?GAP', caseSensitive: false).hasMatch(text),
      'Năm, phiên bản hoặc ngày hiệu lực':
          RegExp(r'20\d{2}|\bV\.?\s?\d|ngày ban hành|hiệu lực', caseSensitive: false).hasMatch(text) ||
          (_doc.version?.isNotEmpty ?? false),
      'Nội dung đất / giá thể': RegExp(r'đất|giá thể', caseSensitive: false).hasMatch(text),
      'Nguồn nước / tưới': RegExp(r'nước tưới|nguồn nước|tưới', caseSensitive: false).hasMatch(text),
      'Phân bón / dinh dưỡng': RegExp(r'phân bón|dinh dưỡng', caseSensitive: false).hasMatch(text),
      'IPM / thuốc bảo vệ thực vật': RegExp(
        r'IPM|BVTV|thuốc bảo vệ thực vật|sâu bệnh',
        caseSensitive: false,
      ).hasMatch(text),
      'Thu hoạch / truy xuất': RegExp(r'thu hoạch|truy xuất', caseSensitive: false).hasMatch(text),
      'Nhiệt độ, ẩm đất, ẩm không khí, pH và EC':
          RegExp(r'nhiệt độ', caseSensitive: false).hasMatch(text) &&
          RegExp(r'độ ẩm|ẩm đất', caseSensitive: false).hasMatch(text) &&
          RegExp(r'ẩm không khí|độ ẩm không khí', caseSensitive: false).hasMatch(text) &&
          RegExp(r'pH', caseSensitive: false).hasMatch(text) &&
          RegExp(r'\bEC\b', caseSensitive: false).hasMatch(text),
      'Giai đoạn và thời lượng sinh trưởng':
          RegExp(r'giai đoạn|thời kỳ', caseSensitive: false).hasMatch(text) &&
          RegExp(r'\d+\s*ngày', caseSensitive: false).hasMatch(text),
      'Có cơ quan ban hành': (_doc.authorOrganization?.isNotEmpty ?? false),
    };
  }

  Future<void> _saveReview(bool approve) async {
    if (_content.text.trim().length < 50) {
      _showMessage('Nội dung cần tối thiểu 50 ký tự.');
      return;
    }
    if (approve && !_confirmed) {
      _showMessage('Hãy xác nhận đã đối chiếu nội dung với nguồn.');
      return;
    }
    if (approve && _type == 'Unspecified') {
      _showMessage('Chưa xác định loại tài liệu: hãy chọn loại trước khi duyệt.');
      return;
    }
    final detection = _doc.metadataDetection;
    final generalDetected = (detection?['generalScope'] as Map?)?['status'] == 'detected';
    if (approve && detection != null && _crop.text.trim().isEmpty && !_confirmGeneral && !generalDetected) {
      _showMessage(
        'Chưa xác định cây áp dụng: hãy nhập cây, hoặc xác nhận tài liệu áp dụng chung sau khi đối chiếu file gốc.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      // Chỉ gửi trường người duyệt đã sửa; trường không đổi giữ giá trị hệ thống nhận diện.
      String? changed(String now, String before) => now.trim() != before ? now.trim() : null;
      await DocumentApi.reviewAgricultureDocument(
        id: _doc.id,
        contentText: _content.text,
        approve: approve,
        reviewNotes: _notes.text,
        title: changed(_title.text, _doc.title),
        cropScope: changed(_crop.text, _doc.cropScope),
        authorOrganization: changed(_author.text, _doc.authorOrganization ?? ''),
        version: changed(_version.text, _doc.version ?? ''),
        documentType: _type != _doc.documentType ? _type : null,
        confirmGeneralScope: _confirmGeneral,
      );
      final refreshed = await DocumentApi.getAgricultureDocument(_doc.id);
      if (!mounted) return;
      setState(() {
        _document = refreshed;
        _content.text = refreshed.contentText ?? '';
        _notes.text = refreshed.reviewNotes ?? '';
        _syncMeta(refreshed);
        _confirmed = false;
      });
      _showMessage(
        approve
            ? 'Đã duyệt. Tài liệu có thể dùng làm nguồn tri thức cho AI.'
            : 'Đã lưu ở trạng thái cần chỉnh sửa; chưa dùng cho AI.',
      );
    } catch (error) {
      _showMessage('Không lưu được rà soát: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _downloadOriginal() async {
    if (!_doc.hasOriginalFile || _downloading) return;
    if (kIsWeb) {
      _showMessage('Tải file gốc để xem chỉ hỗ trợ ứng dụng Android/iOS.');
      return;
    }
    setState(() => _downloading = true);
    try {
      final bytes = await DocumentApi.downloadAgricultureOriginalFile(_doc.id);
      final directory = await getTemporaryDirectory();
      final safeName = (_doc.fileName ?? 'vietgap_document').replaceAll(RegExp(r'[^\w.\-]'), '_');
      final file = File('${directory.path}/$safeName');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        _showMessage('Đã tải file nhưng không mở được: ${result.message}');
      }
    } catch (error) {
      _showMessage('Không tải/mở được file gốc: $error');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final approved = _doc.reviewStatus == 'Approved';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: Text(_doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statusCard(approved),
                const SizedBox(height: 12),
                if (_doc.metadataDetection != null) ...[
                  _detectionCard(_doc.metadataDetection!),
                  const SizedBox(height: 12),
                ],
                _verificationCard(),
                const SizedBox(height: 12),
                if (widget.canManage) ...[_metadataForm(), const SizedBox(height: 12)],
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nguồn: ${_doc.fileName ?? 'Văn bản nhập trực tiếp'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cây trồng: ${_doc.cropScope.isEmpty ? 'Chưa xác định' : _doc.cropScope} · ${_doc.authorOrganization ?? 'Chưa rõ cơ quan ban hành'}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 10),
                        if (_doc.hasOriginalFile)
                          OutlinedButton.icon(
                            onPressed: _downloading ? null : _downloadOriginal,
                            icon: _downloading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.picture_as_pdf_outlined),
                            label: Text(_downloading ? 'Đang tải file gốc…' : 'Tải và mở file gốc để đối chiếu'),
                          )
                        else
                          const Text(
                            'Không có file gốc lưu cùng bản ghi. Với tài liệu cũ hoặc nội dung nhập trực tiếp, hãy đối chiếu nguồn riêng.',
                            style: TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_doc.reviewNotes?.isNotEmpty ?? false)
                  Card(
                    color: const Color(0xFFFFF7ED),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Ghi chú trước: ${_doc.reviewNotes}'),
                    ),
                  ),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kiểm tra độ đầy đủ (gợi ý)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: _ink),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Các mục chưa thấy cần xem lại; checklist không thể xác nhận OCR đúng hay tài liệu còn hiệu lực.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        ..._checks.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                  entry.value ? Icons.check_circle : Icons.error_outline,
                                  size: 16,
                                  color: entry.value ? _green : Colors.orange,
                                ),
                                const SizedBox(width: 7),
                                Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 11))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Toàn văn trích xuất · ${_content.text.length} ký tự · ${_doc.chunkCount} chunks',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: _ink),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _content,
                          readOnly: !widget.canManage,
                          maxLines: 18,
                          maxLength: 200000,
                          onChanged: (_) => setState(() => _confirmed = false),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                            hintText: 'Văn bản sau khi trích xuất/OCR',
                          ),
                        ),
                        if (widget.canManage) ...[
                          TextField(
                            controller: _notes,
                            maxLines: 2,
                            maxLength: 2000,
                            decoration: const InputDecoration(
                              labelText: 'Ghi chú rà soát',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            value: _confirmed,
                            onChanged: (value) => setState(() => _confirmed = value ?? false),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              _doc.hasOriginalFile
                                  ? 'Tôi đã đối chiếu nội dung với file gốc.'
                                  : 'Tôi đã đối chiếu với nguồn đáng tin cậy hoặc xác minh nội dung nhập.',
                            ),
                            subtitle: const Text(
                              'Duyệt không đồng nghĩa chứng nhận tuân thủ VietGAP.',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.canManage) ...[
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _saveReview(false),
                    icon: const Icon(Icons.edit_note, color: Colors.deepOrange),
                    label: const Text('Lưu · cần chỉnh sửa'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _saving || !_confirmed ? null : () => _saveReview(true),
                    icon: const Icon(Icons.verified_outlined),
                    label: Text(_saving ? 'Đang lưu…' : 'Xác nhận & duyệt'),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  static const _statusText = <String, String>{
    'detected': 'Đã nhận diện',
    'uncertain': 'Chưa chắc chắn',
    'not_found': 'Không thấy trong file',
  };

  Widget _detectionCard(Map<String, dynamic> detection) {
    const rows = <(String, String)>[
      ('title', 'Tiêu đề'),
      ('crops', 'Cây áp dụng'),
      ('generalScope', 'Áp dụng chung'),
      ('publisher', 'Đơn vị ban hành'),
      ('standardCode', 'Mã tiêu chuẩn'),
      ('version', 'Phiên bản'),
      ('effectiveDate', 'Hiệu lực / năm'),
      ('documentType', 'Loại tài liệu'),
    ];
    final topics = (detection['topics'] as List?) ?? const [];
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thông tin hệ thống tự nhận diện từ file', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text(
              'Chỉ ghi giá trị khi file có bằng chứng; chưa thấy thì để trống, không đoán.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            for (final (key, label) in rows)
              if (detection[key] is Map<String, dynamic>) _detectionRow(label, detection[key] as Map<String, dynamic>),
            if (topics.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Chủ đề trong nội dung (gợi ý): ${topics.map((t) => "${t['topic']} (${t['chunkCount']})").join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const _verificationText = <String, String>{
    'Pending': 'AI đang kiểm tra',
    'Agricultural': 'AI: thuộc lĩnh vực nông nghiệp',
    'NotAgricultural': 'AI: có thể KHÔNG phải tài liệu nông nghiệp',
    'Uncertain': 'AI chưa đủ căn cứ để kết luận',
    'VerificationError': 'AI gặp lỗi — chưa kiểm tra được',
  };

  /// Kết quả AI kiểm tra tài liệu có thuộc lĩnh vực nông nghiệp: chỉ xác nhận chủ đề, không đánh giá đúng/sai kỹ thuật,
  /// không chứng nhận VietGAP và không quyết định việc duyệt.
  Widget _verificationCard() {
    final v = _doc.verification;
    final status = (v?['status'] ?? _doc.verificationStatus)?.toString();
    final evidence = (v?['evidence'] as List?) ?? const [];
    final color = switch (status) {
      'NotAgricultural' => Colors.red,
      'Agricultural' => _green,
      'Pending' => Colors.blue,
      _ => Colors.orange,
    };
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI kiểm tra tài liệu có thuộc lĩnh vực nông nghiệp',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Chỉ xác nhận chủ đề; không đánh giá kỹ thuật đúng hay sai và không phải chứng nhận VietGAP. Tài liệu chỉ vào RAG sau khi quản trị viên duyệt.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              status == null
                  ? 'Chưa có kết quả kiểm tra (tài liệu nạp trước khi có tính năng).'
                  : (_verificationText[status] ?? status),
              style: TextStyle(fontWeight: FontWeight.w600, color: status == null ? Colors.black54 : color),
            ),
            if (v?['message'] != null) Text('${v!['message']}', style: const TextStyle(fontSize: 12)),
            if (v?['documentKind'] != null)
              Text('AI nhận định đây là: ${v!['documentKind']}', style: const TextStyle(fontSize: 12)),
            if (v?['reason'] != null)
              Text('Lý do: ${v!['reason']}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            for (final q in evidence.whereType<Map<String, dynamic>>())
              Text(
                '“${q['quote']}”${q['page'] == null ? '' : ' · trang ${q['page']}'}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detectionRow(String label, Map<String, dynamic> field) {
    final status = field['status']?.toString() ?? 'not_found';
    final evidence = field['evidence'] as Map<String, dynamic>?;
    final candidates = (field['candidates'] as List?)?.join(', ');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: field['value']?.toString() ?? '—'),
                TextSpan(
                  text: '  · ${_statusText[status] ?? status}',
                  style: TextStyle(
                    fontSize: 11,
                    color: status == 'detected'
                        ? _green
                        : status == 'uncertain'
                        ? Colors.orange
                        : Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),
          if (evidence != null)
            Text(
              '“${evidence['quote']}”${evidence['page'] == null ? '' : ' · trang ${evidence['page']}'}',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
            ),
          if (candidates != null && candidates.isNotEmpty)
            Text(
              'Được nhắc trong file: $candidates (chưa đủ để kết luận phạm vi)',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
        ],
      ),
    );
  }

  Widget _metadataForm() => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chỉnh thông tin sau khi đối chiếu file gốc', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Tiêu đề'),
          ),
          TextField(
            controller: _crop,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Cây áp dụng (phân tách bằng dấu phẩy)',
              helperText: 'Để trống nếu tài liệu áp dụng chung',
            ),
          ),
          if (_crop.text.trim().isEmpty)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _confirmGeneral,
              onChanged: (v) => setState(() => _confirmGeneral = v ?? false),
              title: const Text(
                'Xác nhận áp dụng chung cho mọi cây (sau khi đối chiếu file gốc)',
                style: TextStyle(fontSize: 12),
              ),
            ),
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Loại tài liệu'),
            items: [for (final e in _typeLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          TextField(
            controller: _author,
            decoration: const InputDecoration(labelText: 'Đơn vị ban hành'),
          ),
          TextField(
            controller: _version,
            decoration: const InputDecoration(labelText: 'Phiên bản / hiệu lực'),
          ),
        ],
      ),
    ),
  );

  Widget _statusCard(bool approved) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: approved ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: approved ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA)),
    ),
    child: Row(
      children: [
        Icon(approved ? Icons.verified : Icons.pending_actions, color: approved ? _green : Colors.orange),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _doc.statusLabel,
                style: TextStyle(fontWeight: FontWeight.bold, color: approved ? Colors.green[900] : Colors.orange[900]),
              ),
              Text(
                approved
                    ? 'Được phép dùng làm nguồn cho RAG và AI profile.'
                    : 'Chưa được dùng cho RAG hoặc tạo profile.',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
