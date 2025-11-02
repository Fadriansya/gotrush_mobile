import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/alerts.dart';

class ProfileScreen extends StatefulWidget {
  final String role; // 'user' or 'driver'
  const ProfileScreen({super.key, this.role = 'user'});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loadingImage = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: Text('User belum login')),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Profil',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Konfirmasi'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;
              try {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                showAppSnackBar(
                  context,
                  'Berhasil keluar',
                  type: AlertType.success,
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
              } catch (e) {
                if (!context.mounted) return;
                showAppSnackBar(
                  context,
                  'Gagal keluar: $e',
                  type: AlertType.error,
                );
              }
            },
            tooltip: 'Keluar',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF66BB6A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: auth.userDocStream(uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            final data = snapshot.data!.data() ?? {};
            final name = (data['name'] as String?) ?? '';
            final phone = (data['phone'] as String?) ?? '';
            final email = (data['email'] as String?) ?? '';
            final status = (data['status'] as String?) ?? '';
            final photoUrl = (data['photoUrl'] as String?) ?? '';

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    // top card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 46,
                                backgroundColor: Colors.white24,
                                child: ClipOval(
                                  child: SizedBox(
                                    width: 86,
                                    height: 86,
                                    child: _loadingImage
                                        ? const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          )
                                        : (photoUrl.isNotEmpty
                                              ? FadeInImage.assetNetwork(
                                                  placeholder:
                                                      'assets/images/profile.png',
                                                  image: photoUrl,
                                                  fit: BoxFit.cover,
                                                  imageErrorBuilder:
                                                      (
                                                        _,
                                                        __,
                                                        ___,
                                                      ) => Image.asset(
                                                        'assets/images/profile.png',
                                                        fit: BoxFit.cover,
                                                      ),
                                                )
                                              : Image.asset(
                                                  'assets/images/profile.png',
                                                  fit: BoxFit.cover,
                                                )),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -6,
                                bottom: -6,
                                child: Material(
                                  color: Colors.white,
                                  shape: const CircleBorder(),
                                  elevation: 4,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => _showPhotoOptions(
                                      context,
                                      uid,
                                      photoUrl,
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isEmpty ? 'Pengguna' : name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Chip(
                                      backgroundColor: Colors.white24,
                                      label: Text(
                                        widget.role.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (widget.role == 'driver')
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: status.toLowerCase() == 'aktif'
                                              ? Colors.greenAccent.shade700
                                              : Colors.orangeAccent,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          status.isEmpty
                                              ? 'Tidak ada status'
                                              : status,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.email_outlined),
                              title: const Text('Email'),
                              subtitle: Text(email.isEmpty ? '-' : email),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.phone_outlined),
                              title: const Text('Telepon'),
                              subtitle: Text(phone.isEmpty ? '-' : phone),
                            ),
                            if (widget.role == 'driver') ...[
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.info_outline),
                                title: const Text('Status'),
                                subtitle: Text(status.isEmpty ? '-' : status),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            label: const Text('Tutup'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _openEditDialog(context, uid, data),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Profil'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.green.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openEditDialog(
    BuildContext context,
    String uid,
    Map<String, dynamic> data,
  ) {
    final nameCtl = TextEditingController(text: data['name'] as String? ?? '');
    final phoneCtl = TextEditingController(
      text: data['phone'] as String? ?? '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Edit Profil',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telepon',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final newName = nameCtl.text.trim();
                        final newPhone = phoneCtl.text.trim();
                        if (newName.isEmpty) {
                          showAppSnackBar(
                            context,
                            'Nama tidak boleh kosong',
                            type: AlertType.error,
                          );
                          return;
                        }
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .update({'name': newName, 'phone': newPhone});
                          if (!context.mounted) return;
                          Navigator.of(ctx).pop();
                          showAppSnackBar(
                            context,
                            'Profil diperbarui',
                            type: AlertType.success,
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          showAppSnackBar(
                            context,
                            'Gagal menyimpan: $e',
                            type: AlertType.error,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPhotoOptions(
    BuildContext context,
    String uid,
    String currentPhotoUrl,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadImage(context, uid);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Hapus Foto'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmRemovePhoto(context, uid, currentPhotoUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Batal'),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(BuildContext context, String uid) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _loadingImage = true);

      final file = File(picked.path);
      final ref = fb_storage.FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('$uid.jpg');

      final uploadTask = ref.putFile(file);
      final snap = await uploadTask.whenComplete(() {});
      final downloadUrl = await snap.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'photoUrl': downloadUrl,
      });

      if (!mounted) return;

      if (!context.mounted) return;
      showAppSnackBar(
        context,
        'Foto profil diperbarui',
        type: AlertType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        'Gagal mengunggah foto: $e',
        type: AlertType.error,
      );
    } finally {
      if (mounted) setState(() => _loadingImage = false);
    }
  }

  void _confirmRemovePhoto(
    BuildContext context,
    String uid,
    String currentPhotoUrl,
  ) {
    if (currentPhotoUrl.isEmpty) {
      showAppSnackBar(
        context,
        'Tidak ada foto untuk dihapus',
        type: AlertType.error,
      );
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Foto'),
        content: const Text('Apakah Anda yakin ingin menghapus foto profil?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        if (!mounted) return;
        await _removePhoto(uid, currentPhotoUrl);
      }
    });
  }

  Future<void> _removePhoto(String uid, String currentPhotoUrl) async {
    try {
      setState(() => _loadingImage = true);
      // Try deleting the file in storage if it exists under user_photos/$uid.jpg
      try {
        final ref = fb_storage.FirebaseStorage.instance
            .ref()
            .child('user_photos')
            .child('$uid.jpg');
        await ref.delete();
      } catch (_) {
        // ignore errors deleting storage (file might not exist)
      }
      // Clear field in firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'photoUrl': '',
      });
      if (!mounted) return;
      showAppSnackBar(context, 'Foto profil dihapus', type: AlertType.success);
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        'Gagal menghapus foto: $e',
        type: AlertType.error,
      );
    } finally {
      if (mounted) setState(() => _loadingImage = false);
    }
  }
}
