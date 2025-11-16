import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  Future<void> _softDeleteUser(String uid) async {
    // soft delete: set disabled true, hapus doc jika ingin permanent
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'disabled': true,
      'disabled_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daftar User',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: Colors.green.shade600,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'user')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Belum ada user.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final d = docs[idx];
              final data = d.data() as Map<String, dynamic>;
              final disabled = data['disabled'] == true;
              return Card(
                child: ListTile(
                  title: Text(data['name'] ?? 'No name'),
                  subtitle: Text(data['email'] ?? '-'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(disabled ? Icons.lock : Icons.lock_open),
                        tooltip: disabled
                            ? 'Sudah dinonaktifkan'
                            : 'Nonaktifkan akun',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Konfirmasi'),
                              content: Text(
                                disabled
                                    ? 'Batalkan nonaktifkan akun ini?'
                                    : 'Nonaktifkan akun ini (tidak akan bisa login)?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Ya'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _softDeleteUser(d.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Akun diupdate')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.redAccent,
                        ),
                        tooltip: 'Hapus dokumen user (Firestore)',
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Hapus akun'),
                              content: const Text(
                                'Hapus dokumen user di Firestore? (tidak menghapus Firebase Auth)',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(d.id)
                                .delete();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Dokumen user dihapus'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
