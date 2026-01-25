# Sampah Online

Sampah Online adalah aplikasi mobile cross-platform (Flutter) untuk memfasilitasi penjemputan sampah oleh layanan kurir/driver lokal. Aplikasi ini menyederhanakan proses pembuatan permintaan penjemputan oleh pengguna, penugasan dan workflow pengambilan oleh driver, serta pencatatan riwayat order.

README ini berisi panduan lengkap mulai dari konsep, arsitektur, setup lingkungan pengembangan, hingga progres fitur yang sudah diimplementasikan.

## Isi dokumen

- Ringkasan aplikasi
- Fitur utama
- Arsitektur & stack teknologi
- Struktur data Firestore (model penting)
- Setup & konfigurasi (lokal dan Firebase)
- Menjalankan aplikasi (dev/emulator/device)
- Catatan implementasi penting dan keputusan engineering
- Progres saat ini dan perubahan terbaru
- Troubleshooting umum
- Roadmap / TODO
- Cara berkontribusi

---

## Ringkasan Aplikasi

Pengguna (user) dapat membuat permintaan penjemputan sampah (alamat, berat, harga), sementara driver dapat melihat dan menerima pesanan terdekat, memperbarui status perjalanan (accepted → on_the_way → arrived → completed). Setelah selesai, order diarsipkan di koleksi `order_history` untuk keperluan audit/riwayat.

Fokus implementasi saat ini: performa, UX notifikasi, dan menghindari pembacaan jaringan berlebih pada tampilan riwayat dengan melakukan denormalisasi (menyimpan nama user/driver saat mengarsipkan order).

## Fitur Utama

- Pendaftaran & otentikasi (Firebase Auth)
- Halaman pengguna: buat order, lihat riwayat, notifikasi status order
- Halaman driver: daftar pesanan baru, terima pesanan, ubah status (Berangkat/Tiba/Selesai)
- Notifikasi lokal (client-side) untuk kejadian tertentu (driver mendekat)
- Riwayat order yang menyimpan snapshot data penting (alamat, berat, harga, nama pihak terkait)
- Sistem alert terpusat untuk SnackBar dan Dialog yang konsisten (floating snackbars + animated dialogs)

## Arsitektur & Tech Stack

- Flutter (Dart) — UI cross-platform
- Firebase
  - Authentication — sign-up / login
  - Firestore — penyimpanan data utama (collections: users, drivers, orders, order_history)
  - Cloud Functions (opsional/backfill)
- Packages utama (lihat `pubspec.yaml`): cloud_firestore, firebase_auth, firebase_core, provider, intl, geolocator, google_maps_flutter (opsional), flutter_local_notifications

### Struktur Kode (ringkasan)

- `lib/main.dart` — entry app
- `lib/screens/` — UI screens (user, driver, auth, profile, tracking, history)
- `lib/services/` — layanan: `auth_service.dart`, `order_service.dart`, `notification_service.dart` (lokal)
- `lib/widgets/` — reusable widgets (mis. `order_history_widget.dart`)
- `lib/utils/alerts.dart` — helper terpusat untuk alert (SnackBar/Dialog)

## Model Data (Firestore) — ringkasan

Berikut adalah koleksi/kunci penting dan contoh fields (konvensi saat ini):

- `users/{uid}`:
  - name: string
  - email: string
  - phone: string
  - role: 'user' | 'driver'

- `drivers/{driverId}`:
  - location: GeoPoint
  - updatedAt: timestamp
  - status: string (online/offline)

- `orders/{orderId}`:
  - user_id, driver_id (nullable until accepted)
  - address, location (GeoPoint), weight, price
  - status: 'waiting' | 'accepted' | 'on_the_way' | 'arrived' | 'completed' | 'archived'
  - created_at, updated_at

- `order_history/{orderId}` — copy snapshot ketika order diarsipkan:
  - includes: user_name, driver_name, address, weight, price, archived_at, completed_at, original_order_id

Catatan: aplikasi mengandalkan denormalisasi (menyimpan nama user/driver pada saat archive) untuk mengurangi jumlah bacaan dokumen saat menampilkan riwayat.

## Setup & Konfigurasi (Developer)

Berikut langkah ringkas untuk menjalankan aplikasi secara lokal.

Persyaratan:

- Flutter SDK (stable). Cek `flutter --version`.
- Firebase project dan akses untuk membuat konfigurasi (Android/iOS/Web).
- Android SDK / Xcode jika ingin build ke device.

Langkah:

1. Clone repo: git clone <repo>
2. Install dependencies:

```bash
flutter pub get
```

3. Firebase configuration:
   - Android: letakkan `google-services.json` di `android/app/`.
   - iOS: letakkan `GoogleService-Info.plist` di `ios/Runner/`.
   - Web: konfigurasikan `firebase_options.dart` (project sudah menyertakan file dasar `lib/firebase_options.dart`).

4. Google Maps API (opsional): buat API key dan tambahkan ke `AndroidManifest.xml` dan `Info.plist` jika memakai peta.

5. Jalankan pada emulator / device:

```bash
flutter run
```

atau untuk build release Android:

```bash
flutter build apk --release
```

## Clone dari GitHub (jika repo sudah dipush)

Jika Anda atau tim sudah mem-push repository ini ke GitHub, berikut cara meng-clone dan menyiapkan remote/branch dengan aman.

1. Clone repo (ganti URL dengan repo Anda):

```bash
git clone https://github.com/<username>/<repo>.git
cd <repo>
```

2. Jika Anda menggunakan SSH (lebih aman untuk push):

```bash
git clone git@github.com:<username>/<repo>.git
cd <repo>
```

3. Buat branch kerja untuk fitur/bugfix (jangan langsung commit ke `main`):

```bash
git checkout -b feat/your-feature-name
```

4. Menambahkan remote upstream (jika repo ini adalah fork dari upstream):

```bash
git remote add upstream https://github.com/<original-owner>/<repo>.git
git fetch upstream
```

5. Menyinkronkan branch `main` lokal dengan upstream `main`:

```bash
git checkout main
git fetch upstream
git merge upstream/main
```

6. Push branch Anda ke origin (GitHub):

```bash
git push -u origin feat/your-feature-name
```

Catatan keamanan:

- Jangan commit file yang berisi credential (mis. `google-services.json` yang berisi API key, atau file konfigurasi private). Gunakan `.gitignore` untuk mengecualikannya.
- Simpan kredensial sensitif seperti service account JSON untuk admin/backfill di tempat yang aman (secrets manager atau environment variables), jangan push ke repo publik.

Konfigurasi environment lokal (contoh):

- Setelah clone, copy `google-services.json` ke `android/app/` dan `GoogleService-Info.plist` ke `ios/Runner/` jika tersedia.
- Pastikan `lib/firebase_options.dart` berisi konfigurasi yang sesuai; file ini biasanya dihasilkan via `flutterfire configure`.

## Alert & Notifikasi — pusat dan konsistensi

Untuk menjaga konsistensi UX, project memiliki utilitas terpusat di `lib/utils/alerts.dart`:

- `showAppSnackBar(context, message, type: AlertType)` — floating snackbar bergaya (info/success/error/warning)
- `showAppDialog(context, title:, message:, type:, autoDismissDuration:)` — dialog dengan animasi masuk; untuk tipe `info` dialog akan auto-dismiss (non-blocking) secara default.

Implementasi ini juga memperbaiki beberapa bug UX yang menyebabkan dialog/notification menumpuk (yang sempat menyebabkan aplikasi terasa "freeze" pada skenario login). Untuk menghindari penggunaan `BuildContext` setelah titik async, ada helper tambahan `buildAppSnackBarFromTheme(theme, message, ...)` yang memungkinkan menangkap `ThemeData` dan `ScaffoldMessenger` sebelum menutup dialog, lalu menampilkan snackbar setelah operasi async selesai.

Contoh pola aman:

1. Tangkap messenger & theme sebelum menutup dialog:
   - `final messenger = ScaffoldMessenger.of(context);`
   - `final theme = Theme.of(context);`
2. Tutup dialog: `Navigator.of(dialogCtx).pop();`
3. Setelah async operasi selesai: `messenger.showSnackBar(buildAppSnackBarFromTheme(theme, 'Pesan', type: AlertType.success));`

## Progres & Perubahan Terbaru (highlight) Senin 30-Oktober-2025

Berikut ringkasan pekerjaan dan perbaikan utama yang telah dikerjakan pada kode:

- Perbaikan freeze ketika user login: pindahkan Firestore subscription ke `initState`, tambahkan guard `_dialogOpen` dan mekanisme debounce (3 detik) agar dialog dan notifikasi tidak tumpang tindih.
- Denormalisasi data pada saat archive: saat order diselesaikan dan di-archive, aplikasi menuliskan `user_name` dan `driver_name` ke `order_history` sehingga tampilan riwayat tidak perlu membaca dokumen `users/{uid}` per item.
- Centralized alerts: dibuat `lib/utils/alerts.dart` untuk menyatukan tampilan SnackBar dan Dialog (floating snackbars + animated dialog with auto-dismiss for info).
- Refactor: ganti pemanggilan langsung `ScaffoldMessenger.of(...).showSnackBar(...)` dan `showDialog(...)` di banyak screen menjadi pemanggilan ke helper yang baru.

Files penting yang diubah:

- `lib/screens/user/user_home.dart` — subscription & dialog guard + safe snackbar pattern.
- `lib/services/order_service.dart` — logic archive menambahkan nama ke `order_history`.
- `lib/screens/driver/driver_home.dart`, `lib/screens/register_screen.dart`, `lib/screens/profile_screen.dart`, `lib/screens/track_driver_simple.dart` — menggunakan helper alerts.

Analisa kualitas singkat:

- `flutter analyze` dijalankan selama pengerjaan; perubahan menghasilkan beberapa info-level warnings (non-fatal). Tidak ada error kompilasi yang diintroduksi oleh perubahan alerts.

## Backfill / Migration Data

Jika Anda ingin menambahkan `completed_at` atau `*_name` ke dokumen `order_history` yang sudah ada, beberapa opsi:

- Buat Cloud Function HTTP one-time yang mencari `order_history` tanpa field tertentu dan menulis kembali nilai yang diinginkan (gunakan token proteksi / config untuk keamanan).
- Jalankan skrip admin lokal (menggunakan Admin SDK) dengan kredensial service account — hati-hati (akses penuh ke DB).

Catatan: saat ini hanya order baru yang di-archive yang otomatis menambahkan `user_name` dan `driver_name`.

## Testing & Debugging

- Gunakan `flutter run --verbose` untuk melihat logs runtime.
- Gunakan `flutter analyze` untuk static analysis.
- Periksa network/billing Firestore jika aplikasi membaca dokumen banyak selama testing — denormalisasi dipakai untuk mengurangi biaya baca.

## Security & Production Notes

- Pastikan Firestore Rules yang ketat sebelum merilis (akses baca/tulis sesuai role user/driver).
- Batasi frekuensi update lokasi driver untuk menghemat biaya dan battery.
- Pindahkan logika kritikal (mis. penentuan driver terpilih atau penulisan archive) ke Cloud Function/Admin SDK bila perlu memastikan konsistensi dan menghindari race condition.

## Roadmap / TODO (singkat)

- Backfill historical `order_history` documents (HTTP Cloud Function + token protection).
- Pindahkan archive logic ke server-side function untuk keandalan.
- Tambah pengujian otomatis (unit & integration) untuk service utama.
- Integrasi peta/visualisasi driver (Google Maps) dan optimasi tracking.

## Cara Berkontribusi

- Fork repo → buat branch fitur → buat PR dengan deskripsi perubahan.
- Jalankan `flutter analyze` dan sertakan langkah reproduksi untuk bugfix.

## Kontak / Lisensi

- [`Nasrullah Akbar`](https://github.com/Nasrullah-Akbar-Fadriansyah)
- [`Yudi Alfarizi`](https://github.com/Yudi-Alfarizi)
- [`Achmad Syahrudin`](https://github.com/achmadsyahrdn)
- [`Aditya April Riandi`](https://github.com/aditya100402)
