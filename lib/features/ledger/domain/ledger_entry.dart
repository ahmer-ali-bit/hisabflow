class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.customerId,
    required this.entryDate,
    required this.createdAt,
    this.pageNumber,
    this.description = '',
    this.debit = 0,
    this.credit = 0,
    this.buyQuantity = 0,
    this.sellQuantity = 0,
    this.dailyLogVisible = true,
  });

  final String id;
  final String customerId;
  final DateTime entryDate;
  final DateTime createdAt;
  final String? pageNumber;
  final String description;
  final double debit;
  final double credit;
  final double buyQuantity;
  final double sellQuantity;
  final bool dailyLogVisible;

  LedgerEntry copyWith({
    String? customerId,
    DateTime? entryDate,
    String? pageNumber,
    String? description,
    double? debit,
    double? credit,
    double? buyQuantity,
    double? sellQuantity,
    bool? dailyLogVisible,
  }) => LedgerEntry(
        id: id,
        customerId: customerId ?? this.customerId,
        entryDate: entryDate ?? this.entryDate,
        createdAt: createdAt,
        pageNumber: pageNumber ?? this.pageNumber,
        description: description ?? this.description,
        debit: debit ?? this.debit,
        credit: credit ?? this.credit,
        buyQuantity: buyQuantity ?? this.buyQuantity,
        sellQuantity: sellQuantity ?? this.sellQuantity,
        dailyLogVisible: dailyLogVisible ?? this.dailyLogVisible,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'customerId': customerId,
        'entryDate': entryDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'pageNumber': pageNumber,
        'description': description,
        'debit': debit,
        'credit': credit,
        'buyQuantity': buyQuantity,
        'sellQuantity': sellQuantity,
        'dailyLogVisible': dailyLogVisible,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: '${json['id']}',
        customerId: '${json['customerId'] ?? json['customer_id'] ?? ''}',
        entryDate: DateTime.tryParse('${json['entryDate'] ?? json['entry_date'] ?? json['date'] ?? ''}') ?? DateTime.now(),
        createdAt: DateTime.tryParse('${json['createdAt'] ?? json['created_at'] ?? json['creationDate'] ?? json['creation_date'] ?? ''}') ?? DateTime.now(),
        pageNumber: json['pageNumber']?.toString() ?? json['page_number']?.toString() ?? json['page']?.toString(),
        description: '${json['description'] ?? json['details'] ?? ''}',
        debit: _asDouble(json['debit'] ?? json['debitAmount'] ?? json['debit_amount'] ?? json['buyAmount'] ?? json['buy_amount']),
        credit: _asDouble(json['credit'] ?? json['creditAmount'] ?? json['credit_amount'] ?? json['sellAmount'] ?? json['sell_amount']),
        buyQuantity: _asDouble(json['buyQuantity'] ?? json['buy_quantity'] ?? json['buyBags'] ?? json['buy_bags'] ?? json['buyWeight'] ?? json['buy_weight']),
        sellQuantity: _asDouble(json['sellQuantity'] ?? json['sell_quantity'] ?? json['sellBags'] ?? json['sell_bags'] ?? json['sellWeight'] ?? json['sell_weight']),
        dailyLogVisible: json['dailyLogVisible'] as bool? ?? json['is_visible'] as bool? ?? true,
      );
}

double _asDouble(Object? value) => double.tryParse('$value') ?? 0;
