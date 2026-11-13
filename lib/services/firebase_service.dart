import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  FirebaseAuth? get auth =>
      Firebase.apps.isNotEmpty ? FirebaseAuth.instance : null;
  FirebaseFirestore? get firestore =>
      Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;

  /// Check whether user is logged in
  User? get currentUser => auth?.currentUser;

  Future<String?> getAccessToken() async => currentUser?.getIdToken();

  Future<void> signOut() async {
    try {
      await auth?.signOut();
    } catch (e) {
      debugPrint('Firebase signOut notice: $e');
    }
  }

  /// Save diagnosis scan result to Firestore collection 'scans'
  Future<void> saveDiagnosisResult({
    required String diseaseName,
    required String confidence,
    required String severity,
    String? fieldName,
  }) async {
    try {
      final store = firestore;
      if (store == null) return;
      await store.collection('scans').add({
        'disease': diseaseName,
        'confidence': confidence,
        'severity': severity,
        'field': fieldName,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': currentUser?.uid ?? 'guest_user',
      });
    } catch (e) {
      debugPrint('Firestore Save Notice: $e');
    }
  }

  /// Stream of field scans
  Stream<QuerySnapshot<Map<String, dynamic>>> getScansStream() {
    final store = firestore;
    if (store == null) return const Stream.empty();
    return store
        .collection('scans')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
