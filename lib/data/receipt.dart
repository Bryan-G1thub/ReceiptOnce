class Receipt {
  final int? id;
  final String merchant;
  final int? totalCents;
  final String purchaseDate;
  final String category;
  final String imagePath;
  final String rawText;
  final String note;
  final String createdAt;

  const Receipt({
    this.id,
    required this.merchant,
    required this.totalCents,
    required this.purchaseDate,
    required this.category,
    required this.imagePath,
    required this.rawText,
    required this.note,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'merchant': merchant,
      'total_cents': totalCents,
      'purchase_date': purchaseDate,
      'category': category,
      'image_path': imagePath,
      'raw_text': rawText,
      'note': note,
      'created_at': createdAt,
    };
  }

  Receipt copyWith({
    int? id,
    String? merchant,
    int? totalCents,
    String? purchaseDate,
    String? category,
    String? imagePath,
    String? rawText,
    String? note,
    String? createdAt,
  }) {
    return Receipt(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      totalCents: totalCents ?? this.totalCents,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      rawText: rawText ?? this.rawText,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Receipt.fromMap(Map<String, Object?> map) {
    return Receipt(
      id: map['id'] as int?,
      merchant: (map['merchant'] as String?) ?? '',
      totalCents: map['total_cents'] as int?,
      purchaseDate: (map['purchase_date'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'Other',
      imagePath: (map['image_path'] as String?) ?? '',
      rawText: (map['raw_text'] as String?) ?? '',
      note: (map['note'] as String?) ?? '',
      createdAt: (map['created_at'] as String?) ?? '',
    );
  }
}
