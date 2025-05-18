import 'package:cloud_firestore/cloud_firestore.dart';

class MarketplaceAd {
  final String id;
  final String userId;
  final String category; // sale, adoption, sitting
  final String breed;
  final int age;
  final String price; // optional for adoption/sitting
  final String healthStatus;
  final String imageUrl;
  final String contactNumber;
  final Timestamp createdAt;

  MarketplaceAd({
    required this.id,
    required this.userId,
    required this.category,
    required this.breed,
    required this.age,
    required this.price,
    required this.healthStatus,
    required this.imageUrl,
    required this.contactNumber,
    required this.createdAt,
  });

  factory MarketplaceAd.fromMap(Map<String, dynamic> map, String docId) {
    return MarketplaceAd(
      id: docId,
      userId: map['userId'],
      category: map['category'],
      breed: map['breed'],
      age: map['age'],
      price: map['price'],
      healthStatus: map['healthStatus'],
      imageUrl: map['imageUrl'],
      contactNumber: map['contactNumber'],
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'category': category,
      'breed': breed,
      'age': age,
      'price': price,
      'healthStatus': healthStatus,
      'imageUrl': imageUrl,
      'contactNumber': contactNumber,
      'createdAt': createdAt,
    };
  }
}
