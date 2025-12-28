import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String email = '', password = '';
  bool isLoading = false;
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();

  Future<void> _handleLogin(AuthService auth) async {
    setState(() => isLoading = true);

    try {
      final userCredential = await auth.login(email.trim(), password);
      final uid = userCredential?.user?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (!doc.exists) {
          await _showErrorDialog(
            title: 'Akun tidak ditemukan',
            message:
                'Data pengguna tidak ditemukan di database. Ingin mendaftar?',
            actionLabel: 'Daftar',
            action: () => Navigator.pushNamed(context, '/register'),
          );
          return;
        }

        final role = doc.data()?['role'] as String?;
        if (role == 'driver') {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/driver');
        } else if (role == 'user') {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/user');
        } else if (role == 'admin') {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          await _showErrorDialog(
            title: 'Akses ditolak',
            message:
                'Akun ini tidak memiliki role yang valid. Ingin mendaftar ulang?',
            actionLabel: 'Daftar',
            action: () => Navigator.pushNamed(context, '/register'),
          );
          return;
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          // Pesan khusus sesuai permintaan
          message = 'Password tidak ada, coba masukkan ulang';
        case 'user-not-found':
          message = 'Email belum terdaftar. Coba daftar terlebih dahulu.';
        case 'user-disabled':
          message = 'Akun dinonaktifkan. Hubungi admin.';
        case 'too-many-requests':
          message = 'Terlalu banyak percobaan. Coba lagi nanti.';
        case 'invalid-email':
          message = 'Format email tidak valid.';
        case 'network-request-failed':
          message = 'Gagal terhubung ke jaringan. Periksa koneksi internetmu.';
        default:
          message = 'Login gagal: ${e.message ?? e.code}';
      }

      await _showErrorDialog(title: 'Login gagal', message: message);
    } catch (e) {
      await _showErrorDialog(title: 'Login gagal', message: e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _showErrorDialog({
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? action,
  }) async {
    if (mounted) setState(() => isLoading = false);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Flexible(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          if (actionLabel != null && action != null)
            TextButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                action();
              },
              icon: const Icon(Icons.login),
              label: Text(actionLabel),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFB2E4C6),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.green[200],
                      child: Icon(
                        Icons.recycling,
                        size: 48,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Selamat Datang!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Masuk untuk melanjutkan',
                      style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.green[50],
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (v) => email = v,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email tidak boleh kosong';
                        }
                        final val = v.trim().toLowerCase();
                        // Validasi hanya boleh email Gmail
                        final isGmail = val.endsWith('@gmail.com');
                        if (!isGmail) {
                          return 'Hanya email @gmail.com yang diizinkan';
                        }
                        // Cek pola dasar email
                        final emailRegex = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                        );
                        if (!emailRegex.hasMatch(val)) {
                          return 'Format email tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.green[50],
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Tampilkan password'
                              : 'Sembunyikan password',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      onChanged: (v) => password = v,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Password tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (_formKey.currentState?.validate() ??
                                    false) {
                                  await _handleLogin(auth);
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Login',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Belum punya akun?'),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/register'),
                          child: const Text(
                            'Daftar',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
