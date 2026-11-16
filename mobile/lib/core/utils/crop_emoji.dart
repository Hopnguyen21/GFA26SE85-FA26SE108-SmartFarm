/// Bỏ dấu tiếng Việt + chữ thường để so khớp tên cây ("Cà Chua", "Ca chua", "tomato" đều khớp).
String foldCropName(String s) {
  const from =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

// Thứ tự quan trọng: "cà chua chuông" phải ra ớt chuông trước khi khớp "cà chua".
const _cropEmojis = <(List<String>, String)>[
  (['ca chua chuong', 'sweet pepper', 'bell pepper', 'ot chuong'], '🫑'),
  (['ca chua', 'tomato'], '🍅'),
  (['dau tay', 'strawberry', 'dau'], '🍓'),
  (['dua leo', 'dua chuot', 'cucumber'], '🥒'),
  (['dua luoi', 'dua hau', 'dua', 'melon'], '🍈'),
  (['ot', 'chili'], '🌶️'),
  (['ca rot', 'carrot'], '🥕'),
  (['xa lach', 'rau', 'lettuce'], '🥬'),
  (['hoa'], '🌸'),
  (['lua', 'rice'], '🌾'),
  (['ngo', 'bap', 'corn'], '🌽'),
  (['khoai'], '🥔'),
  (['ca phe', 'coffee'], '☕'),
  (['nho', 'grape'], '🍇'),
  (['chuoi', 'banana'], '🍌'),
];

/// Biểu tượng cây trồng dùng chung cho mọi màn hình; cây lạ → 🌱.
String cropEmoji(String cropName) {
  final f = foldCropName(cropName);
  if (f.trim().isEmpty) return '🌱';
  for (final (keys, emoji) in _cropEmojis) {
    for (final k in keys) {
      // Từ khóa ngắn (ot, dau, hoa, lua, ngo, nho...) chỉ khớp nguyên từ để không bắt nhầm ("hoa" trong "hoang").
      final re = k.length <= 4
          ? RegExp('(^|[^a-z])${RegExp.escape(k)}([^a-z]|\$)')
          : RegExp(RegExp.escape(k));
      if (re.hasMatch(f)) return emoji;
    }
  }
  return '🌱';
}
