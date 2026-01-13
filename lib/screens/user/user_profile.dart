import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../utils/alerts.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isUpdatingProfile = false;
  bool _isUpdatingPassword = false;
  bool _showPasswordFields = false;
  bool _isGoogleUser = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.currentUser;

      if (user != null) {
        _isGoogleUser = user.providerData.any(
          (p) => p.providerId == "google.com",
        );

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
        }
      }
    } catch (e) {
      showAppSnackBar(
        context,
        'Gagal memuat data profil: $e',
        type: AlertType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(message),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
              child: const Text("Batal", style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.pop(context, false),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
              ),
              child: const Text(
                "Lanjutkan",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _updateProfile() async {
    if (_isUpdatingProfile) return;
    if (!_formKey.currentState!.validate()) return;

    final confirm = await _showConfirmationDialog(
      title: "Konfirmasi Perubahan",
      message: "Yakin ingin memperbarui profil?",
    );
    if (!confirm) return;

    setState(() => _isUpdatingProfile = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      await user.updateDisplayName(_nameController.text.trim());
      await FirebaseFirestore.instance.collection("users").doc(user.uid).update(
        {
          "name": _nameController.text.trim(),
          "phone": _phoneController.text.trim(),
        },
      );

      showAppSnackBar(
        context,
        "Profil berhasil diperbarui",
        type: AlertType.success,
      );
    } catch (e) {
      showAppSnackBar(context, "Gagal memperbarui: $e", type: AlertType.error);
    } finally {
      setState(() => _isUpdatingProfile = false);
    }
  }

  Future<void> _updatePassword() async {
    if (_isUpdatingPassword) return;
    if (_isGoogleUser) return;

    final confirm = await _showConfirmationDialog(
      title: "Konfirmasi Ubah Password",
      message: "Yakin ingin mengganti password?",
    );
    if (!confirm) return;

    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      showAppSnackBar(context, "Semua field wajib diisi");
      return;
    }

    if (_newPasswordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      showAppSnackBar(context, "Password baru tidak sama");
      return;
    }

    setState(() => _isUpdatingPassword = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text.trim(),
      );

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPasswordController.text.trim());

      showAppSnackBar(
        context,
        "Password berhasil diganti",
        type: AlertType.success,
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _showPasswordFields = false);
    } catch (e) {
      showAppSnackBar(
        context,
        "Gagal mengubah password: $e",
        type: AlertType.error,
      );
    } finally {
      setState(() => _isUpdatingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < 350;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmall ? 24 : 28,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green[700]!,
                                  Colors.green[500]!,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(10),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: const CircleAvatar(
                                    radius: 42,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.person,
                                      size: 48,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                Text(
                                  _nameController.text.isEmpty
                                      ? "User"
                                      : _nameController.text,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  user?.email ?? "",
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(200),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          _buildInputCard(
                            child: TextFormField(
                              controller: _nameController,
                              decoration: _inputDecoration(
                                label: "Nama Lengkap",
                                icon: Icons.person,
                              ),
                              validator: (v) => v!.trim().isEmpty
                                  ? "Nama tidak boleh kosong"
                                  : null,
                            ),
                          ),

                          const SizedBox(height: 16),

                          _buildInputCard(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: _inputDecoration(
                                label: "Nomor Telepon",
                                icon: Icons.phone,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isUpdatingProfile
                                  ? null
                                  : _updateProfile,
                              style: elevatedBtn(),
                              child: _isUpdatingProfile
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    )
                                  : const Text(
                                      "Perbarui Profil",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          if (!_isGoogleUser) ...[
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Keamanan Akun",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            _buildInputCard(
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.lock,
                                        color: Colors.green[700],
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          "Ubah Password",
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _showPasswordFields
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                        ),
                                        onPressed: () {
                                          setState(
                                            () => _showPasswordFields =
                                                !_showPasswordFields,
                                          );
                                        },
                                      ),
                                    ],
                                  ),

                                  if (_showPasswordFields) ...[
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _currentPasswordController,
                                      obscureText: true,
                                      decoration: _passwordInput(
                                        "Password Saat Ini",
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _newPasswordController,
                                      obscureText: true,
                                      decoration: _passwordInput(
                                        "Password Baru",
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: true,
                                      decoration: _passwordInput(
                                        "Konfirmasi Password Baru",
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isUpdatingPassword
                                            ? null
                                            : _updatePassword,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[700],
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: _isUpdatingPassword
                                            ? const CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              )
                                            : const Text(
                                                "Ubah Password",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.green[700]),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  InputDecoration _passwordInput(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildInputCard({required Widget child}) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }

  ButtonStyle elevatedBtn() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.green[700],
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
