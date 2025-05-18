import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/marketplace_ad_model.dart';
class MarketplaceAdProvider with ChangeNotifier {
  final List<MarketplaceAd> _allAds = [];
  final List<MarketplaceAd> _userAds = [];

  List<MarketplaceAd> get allAds => _allAds;
  List<MarketplaceAd> get userAds => _userAds;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> fetchAllAds() async {
    try {
      final snapshot = await _firestore.collection('marketplace_ads')
          .orderBy('createdAt', descending: true)
          .get();
      _allAds.clear();
      for (var doc in snapshot.docs) {
        _allAds.add(MarketplaceAd.fromMap(doc.data(), doc.id));
      }
      notifyListeners();
    } catch (e) {
      print("Error fetching all ads: $e");
      rethrow;  // Propagate the error
    }
  }

  Future<void> fetchUserAds() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final snapshot = await _firestore
          .collection('marketplace_ads')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _userAds.clear();
      for (var doc in snapshot.docs) {
        _userAds.add(MarketplaceAd.fromMap(doc.data(), doc.id));
      }
      notifyListeners();
    } catch (e) {
      print("Error fetching user ads: $e");
      rethrow;  // Propagate the error
    }
  }

  Future<void> postAd(MarketplaceAd ad) async {
    try {
      await _firestore.collection('marketplace_ads').add(ad.toMap());
      await fetchAllAds();
      await fetchUserAds();
    } catch (e) {
      print("Error posting ad: $e");
      rethrow;  // Propagate the error so UI can react
    }
  }
}
