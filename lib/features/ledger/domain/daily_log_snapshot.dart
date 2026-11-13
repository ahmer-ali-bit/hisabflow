class DailyLogSnapshot {
  const DailyLogSnapshot({
    required this.id,
    required this.year,
    required this.createdAt,
    required this.debit,
    required this.credit,
    required this.finalBalance,
    required this.customerCount,
    required this.entryIds,
    this.pageNumber,
  });

  final String id;
  final int year;
  final DateTime createdAt;
  final double debit;
  final double credit;
  final double finalBalance;
  final int customerCount;
  final String? pageNumber;
  final List<String> entryIds;

  Map<String, Object?> toJson() => {
        'id': id,
        'year': year,
        'createdAt': createdAt.toIso8601String(),
        'debit': debit,
        'credit': credit,
        'finalBalance': finalBalance,
        'customerCount': customerCount,
        'pageNumber': pageNumber,
        'entryIds': entryIds,
      };

  factory DailyLogSnapshot.fromJson(Map<String, dynamic> json) => DailyLogSnapshot(
        id: '${json['id'] ?? ''}',
        year: int.tryParse('${json['year'] ?? 0}') ?? 0,
        createdAt: DateTime.tryParse('${json['createdAt'] ?? json['savedAt'] ?? ''}') ?? DateTime.now(),
        debit: double.tryParse('${json['debit'] ?? 0}') ?? 0,
        credit: double.tryParse('${json['credit'] ?? 0}') ?? 0,
        finalBalance: double.tryParse('${json['finalBalance'] ?? json['balance'] ?? 0}') ?? 0,
        customerCount: int.tryParse('${json['customerCount'] ?? 0}') ?? 0,
        pageNumber: json['pageNumber']?.toString(),
        entryIds: (json['entryIds'] as List? ?? const []).map((value) => '$value').toList(),
      );
}
