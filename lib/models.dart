import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { worker, manager, admin }
enum ItemCategory { material, tool }
enum ItemCondition { newOne, good, worn, damaged, broken }
enum TransactionType { checkIn, checkOut, transfer, assign, turnIn }
enum TransactionStatus { pending, completed, rejected }
enum SiteType { warehouse, construction }

class AppUser {
  final String id;
  final String employeeId;
  final String name;
  final String jobTitle;
  final UserRole role;

  AppUser({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.jobTitle,
    required this.role,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      employeeId: d['employeeId'] ?? '',
      name: d['name'] ?? '',
      jobTitle: d['jobTitle'] ?? '',
      role: UserRole.values.firstWhere((e) => e.name == d['role']),
    );
  }
}

class Site {
  final String id;
  final String name;
  final SiteType type;

  Site({required this.id, required this.name, required this.type});

  factory Site.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Site(
      id: doc.id,
      name: d['name'],
      type: SiteType.values.firstWhere((e) => e.name == d['type']),
    );
  }
}

class InventoryItem {
  final String id;
  final String name;
  final String siteId;
  final String? holderId;
  final ItemCategory category;
  final ItemCondition condition;

  InventoryItem({
    required this.id,
    required this.name,
    required this.siteId,
    this.holderId,
    required this.category,
    required this.condition,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json, String id) {
    return InventoryItem(
      id: id,
      name: json['name'],
      siteId: json['siteId'],
      holderId: json['holderId'],
      category: ItemCategory.values.firstWhere((e) => e.name == json['category']),
      condition: ItemCondition.values.firstWhere((e) => e.name == json['condition']),
    );
  }
}

class InventoryTransaction {
  final String? id;
  final String itemId;
  final TransactionType type;
  final TransactionStatus status;
  final DateTime timestamp;
  final String userId;
  final String? targetUserId;
  final ItemCondition condition;

  InventoryTransaction({
    this.id,
    required this.itemId,
    required this.type,
    required this.timestamp,
    required this.userId,
    this.targetUserId,
    this.status = TransactionStatus.completed,
    this.condition = ItemCondition.good,
  });

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'type': type.name,
        'status': status.name,
        'timestamp': Timestamp.fromDate(timestamp),
        'userId': userId,
        'targetUserId': targetUserId,
        'condition': condition.name,
      };

  factory InventoryTransaction.fromJson(Map<String, dynamic> json, String id) {
    return InventoryTransaction(
      id: id,
      itemId: json['itemId'],
      type: TransactionType.values.firstWhere((e) => e.name == json['type']),
      status: TransactionStatus.values.firstWhere((e) => e.name == json['status']),
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      userId: json['userId'],
      targetUserId: json['targetUserId'],
      condition: ItemCondition.values.firstWhere((e) => e.name == json['condition']),
    );
  }
}
