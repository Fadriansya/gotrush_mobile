import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/alerts.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // controllers (lebih aman)
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  String _role = 'user';
  bool _isLoading = false;

  // Visibility toggle via ValueNotifier (tidak pernah null)
  final ValueNotifier<bool> _showPassword = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _showConfirmPassword = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _showPassword.dispose();
    _showConfirmPassword.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthService>();

    try {
      await auth.register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        role: _role,
      );

      if (!mounted) return;
      showAppSnackBar(
        context,
        'Registrasi berhasil! Silakan login.',
        type: AlertType.success,
      );

      Navigator.pushReplacementNamed(context, '/login');
    } on Exception catch (e) {
      // Tangani FirebaseAuthException khusus (jika pakai)
      String message = e.toString();
      try {
        final ex = e as dynamic;
        if (ex.code != null) {
          if (ex.code == 'email-already-in-use') {
            message =
                'Email sudah terdaftar. Coba login atau gunakan email lain.';
          } else if (ex.code == 'invalid-email') {
            message = 'hanya format @gmail.com yang didukung.';
          } else if (ex.code == 'weak-password') {
            message = 'Password terlalu lemah.';
          } else {
            message = ex.message ?? ex.toString();
          }
        }
      } catch (_) {
        // tetap pakai message default
      }

      if (mounted) {
        showAppSnackBar(
          context,
          'Gagal registrasi: $message',
          type: AlertType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFB2E4C6),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
              child: SizedBox(
                width: size.width * 0.95,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.green[100],
                        child: Icon(
                          Icons.person_add_alt_1,
                          size: 42,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Buat Akun Baru',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D9D58),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Name
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Nama Lengkap',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.green[50],
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Phone
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly, // ⬅ hanya angka
                        ],
                        decoration: InputDecoration(
                          labelText: 'Nomor Telepon',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.green[50],
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Nomor telepon wajib diisi';
                          }

                          if (!RegExp(r'^\d+$').hasMatch(v)) {
                            return 'Nomor telepon hanya boleh angka';
                          }

                          if (v.length < 10) {
                            return 'Nomor telepon minimal 10 digit';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // Email
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.green[50],
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email wajib diisi';
                          }
                          final regex = RegExp(
                            r'^[^@]+@gmail\.com$',
                            caseSensitive: false,
                          );
                          if (!regex.hasMatch(v.trim())) {
                            return 'hanya format @gmail.com yang diterima.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Password (ValueListenableBuilder untuk toggle)
                      ValueListenableBuilder<bool>(
                        valueListenable: _showPassword,
                        builder: (_, show, __) {
                          return TextFormField(
                            controller: _passwordCtrl,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  show
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () =>
                                    _showPassword.value = !_showPassword.value,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.green[50],
                            ),
                            obscureText: !show,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password tidak boleh kosong';
                              }
                              final passwordRegExp = RegExp(
                                r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9]).{6,}$',
                              );

                              if (!passwordRegExp.hasMatch(v)) {
                                return 'Password 6+ karakter, huruf besar, kecil, dan angka';
                              }

                              return null;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Confirm password
                      ValueListenableBuilder<bool>(
                        valueListenable: _showConfirmPassword,
                        builder: (_, show, __) {
                          return TextFormField(
                            controller: _confirmPasswordCtrl,
                            decoration: InputDecoration(
                              labelText: 'Konfirmasi Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  show
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () => _showConfirmPassword.value =
                                    !_showConfirmPassword.value,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.green[50],
                            ),
                            obscureText: !show,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Konfirmasi password wajib diisi';
                              }
                              if (v != _passwordCtrl.text) {
                                return 'Password tidak cocok';
                              }
                              return null;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Role
                      DropdownButtonFormField<String>(
                        // prefer initialValue over deprecated `value` for form fields
                        initialValue: _role,
                        decoration: InputDecoration(
                          labelText: 'Daftar sebagai',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.green[50],
                        ),
                        items: const [
                          DropdownMenuItem(value: 'user', child: Text('User')),
                          DropdownMenuItem(
                            value: 'driver',
                            child: Text('Driver'),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _role = val ?? 'user');
                        },
                      ),
                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () {
                                  _handleRegister();
                                },
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Daftar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Sudah punya akun?'),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              '/login',
                            ),
                            child: const Text(
                              'Login',
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
      ),
    );
  }
}
