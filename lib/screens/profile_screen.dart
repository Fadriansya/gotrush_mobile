import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
      appBar: AppBar(title: const Text('Profil')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: auth.userDocStream(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};
          final name = data['name'] as String? ?? '';
          final phone = data['phone'] as String? ?? '';
          final email = data['email'] as String? ?? '';
          final status = data['status'] as String? ?? '';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.grey[200],
                    child: Icon(
                      Icons.person,
                      size: 48,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Nama', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text('Email', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(email, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Text('Telepon', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(phone, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                if (widget.role == 'driver') ...[
                  Text('Status', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(status, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Tutup'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _openEditDialog(context, uid, data),
                        child: const Text('Edit Profil'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            TextField(
              controller: phoneCtl,
              decoration: const InputDecoration(labelText: 'Telepon'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
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
                // use parent context to pop the dialog safely
                Navigator.of(context).pop();
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
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
