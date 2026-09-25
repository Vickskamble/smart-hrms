class Customer {
  final String id;
  final String name;
  final String mobile;
  final String? address;
  final String? profilePhoto;
  final double totalBalance;
  final String businessId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Customer({
    required this.id,
    required this.name,
    required this.mobile,
    this.address,
    this.profilePhoto,
    this.totalBalance = 0.0,
    required this.businessId,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mobile': mobile,
      'address': address,
      'profilePhoto': profilePhoto,
      'totalBalance': totalBalance,
      'businessId': businessId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      mobile: map['mobile'] ?? '',
      address: map['address'],
      profilePhoto: map['profilePhoto'],
      totalBalance: (map['totalBalance'] ?? 0.0).toDouble(),
      businessId: map['businessId'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : null,
    );
  }
}

class Transaction {
  final String id;
  final String customerId;
  final double amount;
  final String type;
  final DateTime timestamp;
  final String? note;
  final String businessId;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.type,
    required this.timestamp,
    this.note,
    required this.businessId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'amount': amount,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
      'businessId': businessId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      type: map['type'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      note: map['note'],
      businessId: map['businessId'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class BusinessProfile {
  final String id;
  final String name;
  final String ownerName;
  final String? logoUrl;
  final String currency;
  final String theme;
  final DateTime createdAt;

  BusinessProfile({
    required this.id,
    required this.name,
    required this.ownerName,
    this.logoUrl,
    this.currency = '₹',
    this.theme = 'light',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerName': ownerName,
      'logoUrl': logoUrl,
      'currency': currency,
      'theme': theme,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BusinessProfile.fromMap(Map<String, dynamic> map) {
    return BusinessProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      ownerName: map['ownerName'] ?? '',
      logoUrl: map['logoUrl'],
      currency: map['currency'] ?? '₹',
      theme: map['theme'] ?? 'light',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
