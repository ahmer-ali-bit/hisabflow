class LedgerCustomer {
  const LedgerCustomer({
    required this.id,
    required this.name,
    required this.year,
    this.phone = '',
    this.address = '',
    this.isStockLedger = false,
    this.useWeight = false,
    this.openingDebit = 0,
    this.openingCredit = 0,
    this.openingBuyQuantity = 0,
    this.openingSellQuantity = 0,
  });

  final String id;
  final String name;
  final int year;
  final String phone;
  final String address;
  final bool isStockLedger;
  final bool useWeight;
  final double openingDebit;
  final double openingCredit;
  final double openingBuyQuantity;
  final double openingSellQuantity;

  factory LedgerCustomer.fromJson(Map<String, dynamic> json) => LedgerCustomer(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}'.trim(),
        year: int.tryParse('${json['year'] ?? json['ledgerYear'] ?? DateTime.now().year}') ?? DateTime.now().year,
        phone: '${json['phone'] ?? ''}',
        address: '${json['address'] ?? ''}',
        isStockLedger: json['isStockLedger'] == true || json['isStockLedger'] == 1 || json['isStockLedger'] == '1',
        useWeight: json['useWeight'] == true || json['useWeight'] == 1 || json['useWeight'] == '1',
        openingDebit: double.tryParse('${json['openingDebit'] ?? 0}') ?? 0,
        openingCredit: double.tryParse('${json['openingCredit'] ?? 0}') ?? 0,
        openingBuyQuantity: double.tryParse('${json['openingBuyQuantity'] ?? 0}') ?? 0,
        openingSellQuantity: double.tryParse('${json['openingSellQuantity'] ?? 0}') ?? 0,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'year': year,
        'phone': phone,
        'address': address,
        'isStockLedger': isStockLedger,
        'useWeight': useWeight,
        'openingDebit': openingDebit,
        'openingCredit': openingCredit,
        'openingBuyQuantity': openingBuyQuantity,
        'openingSellQuantity': openingSellQuantity,
      };
}
