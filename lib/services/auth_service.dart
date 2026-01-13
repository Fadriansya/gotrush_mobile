import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get userChanges => _auth.userChanges();

  Future<UserCredential?> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'phone': phone,
        'email': email,
        'role': role,
        'fcm_token': null,
        'status': role == 'driver' ? 'offline' : null,
        'createdAt': FieldValue.serverTimestamp(),
        'last_login_at': FieldValue.serverTimestamp(),
      });

      notifyListeners();
      return cred;
    } on FirebaseAuthException catch (e) {
      debugPrint("🔥 Register error: ${e.message}");
      rethrow;
    } catch (e) {
      debugPrint("🔥 Unexpected error during register: $e");
      rethrow;
    }
  }

  Future<UserCredential?> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return cred;
    } on FirebaseAuthException catch (e) {
      debugPrint("🔥 Login error: ${e.message}");
      rethrow;
    } catch (e) {
      debugPrint("🔥 Unexpected error during login: $e");
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      debugPrint("🔥 Logout error: $e");
      rethrow;
    }
  }

  Future<String?> getUserRoleOnce() async {
    try {
      if (_auth.currentUser == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();

      if (!doc.exists) return null;

      final role = doc.data()?['role'] as String?;
      if (role == 'user' || role == 'driver') return role;

      return null;
    } catch (e) {
      debugPrint("🔥 getUserRoleOnce error: $e");
      return null;
    }
  }

  Future<void> updateFcmToken(String token) async {
    try {
      if (_auth.currentUser == null) return;

      await _firestore.collection('users').doc(_auth.currentUser!.uid).set({
        'fcm_token': token,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("🔥 updateFcmToken error: $e");
    }
  }

  Future<void> setDriverStatus(String status) async {
    try {
      if (_auth.currentUser == null) return;

      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'status': status,
      });
    } catch (e) {
      debugPrint("🔥 setDriverStatus error: $e");
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userDocStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  Future<void> updateLastLogin() async {
    if (_auth.currentUser == null) return;

    await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
      'last_login_at': FieldValue.serverTimestamp(),
    });
  }
}
