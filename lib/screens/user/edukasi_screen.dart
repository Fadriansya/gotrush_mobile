import 'package:flutter/material.dart';

class EdukasiScreen extends StatefulWidget {
  const EdukasiScreen({super.key});

  @override
  State<EdukasiScreen> createState() => _EdukasiScreenState();
}

class _EdukasiScreenState extends State<EdukasiScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  int _sectionIndex =
      0; // 0: Pengantar, 1: Jenis, 2: Kelebihan/Kekurangan, 3: 3R & Tips
  List<bool> _expanded = [false, false, false, false];
  int _tipsIndex = 0;
  bool _introExpanded = false;

  // Checklists (aksi praktis)
  final List<String> _introChecklist = const [
    'Pisahkan basah (organik) dan kering (anorganik) di rumah.',
    'Bawa tumbler & tas kain saat bepergian/belanja.',
    'Bersihkan & keringkan plastik/kaca sebelum disetor.',
    'Setorkan ke bank sampah/pengepul secara berkala.',
    'Kurangi barang sekali pakai, pilih produk isi ulang.',
  ];

  final Map<String, List<String>> _jenisChecklist = const {
    'Organik': [
      'Sediakan wadah tertutup untuk sisa makanan.',
      'Mulai kompos/biopori untuk sampah dapur.',
      'Jangan campur organik dengan plastik/kaca.',
    ],
    'Anorganik': [
      'Cuci dan keringkan plastik/kaca sebelum disortir.',
      'Pisahkan kertas dari sampah basah.',
      'Pelajari kode plastik (PET/PP/HDPE).',
    ],
    'B3 (Berbahaya & Beracun)': [
      'Simpan baterai/lampu dalam wadah tertutup.',
      'Serahkan ke pengelola B3 berizin.',
      'Jangan dibakar atau dibuang ke sampah umum.',
    ],
    'E-waste (Elektronik)': [
      'Backup data perangkat sebelum diserahkan.',
      'Kirim ke layanan daur ulang resmi/retailer.',
      'Hindari bongkar sendiri tanpa SOP.',
    ],
    'Sampah Medis Rumah Tangga': [
      'Pisahkan dan simpan tertutup.',
      'Ikuti panduan fasilitas kesehatan setempat.',
      'Jangan dibuang sembarangan.',
    ],
  };
  final Map<String, List<String>> _saranTindakan = const {
    'Organik': [
      'Pisahkan sampah organik dari plastik sejak awal.',
      'Tiriskan sisa makanan agar tidak menimbulkan bau.',
      'Olah menjadi kompos atau masukkan ke lubang biopori.',
      'Gunakan sebagai pakan ternak jika memungkinkan dan aman.',
      'Hindari mencampur dengan popok atau bahan kimia.',
    ],
    'Anorganik': [
      'Cuci dan keringkan plastik, kaca, atau logam.',
      'Pisahkan berdasarkan jenis material.',
      'Pipihkan botol dan kardus untuk hemat ruang.',
      'Setorkan ke bank sampah atau pengepul resmi.',
      'Jangan membakar sampah anorganik.',
    ],
    'B3 (Berbahaya & Beracun)': [
      'Simpan dalam wadah tertutup dan berlabel.',
      'Jauhkan dari jangkauan anak-anak dan hewan.',
      'Jangan dibakar atau dibuang ke saluran air.',
      'Serahkan ke pengelola limbah B3 berizin.',
    ],
    'E-waste (Elektronik)': [
      'Backup dan hapus data pribadi sebelum dibuang.',
      'Lepaskan baterai jika memungkinkan.',
      'Gunakan layanan daur ulang elektronik resmi.',
      'Jangan membongkar atau membakar perangkat.',
    ],
    'Sampah Medis Rumah Tangga': [
      'Masukkan ke kantong tertutup dan kuat (double bag).',
      'Pisahkan dari sampah lainnya.',
      'Rusak masker atau sarung tangan sebelum dibuang.',
      'Ikuti panduan puskesmas atau fasilitas kesehatan.',
    ],
  };

  final List<String> _prosActions = const [
    'Tetapkan sistem 2 tong: basah & kering.',
    'Jadwalkan setoran mingguan ke bank sampah.',
    'Ajak keluarga tetangga ikut memilah.',
    'Gunakan produk isi ulang & kemasan minimal.',
  ];

  final List<String> _threeRWeekly = const [
    'Minggu 1: Kurangi belanja plastik sekali pakai 50%.',
    'Minggu 2: Kumpulkan & setorkan anorganik bersih.',
    'Minggu 3: Mulai kompos sisa dapur kecil.',
    'Minggu 4: Audit sampah rumah dan perbaiki kebiasaan.',
  ];

  final List<Map<String, String>> _tipsHarian = [
    {
      'title': 'Bawa Botol Minum',
      'desc': 'Kurangi botol plastik sekali pakai dengan membawa tumbler.',
    },
    {
      'title': 'Belanja Pakai Tas Kain',
      'desc': 'Tolak kantong plastik, gunakan tas kain lipat di dompet.',
    },
    {
      'title': 'Pisahkan Sampah Basah & Kering',
      'desc':
          'Mulai pemilahan sederhana: organik (basah) dan anorganik (kering).',
    },
    {
      'title': 'Gunakan Kembali Kardus',
      'desc': 'Reuse kardus untuk penyimpanan atau pengiriman ulang.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _expanded = List<bool>.filled(5, false); // jumlah panel Jenis Sampah
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edukasi Daur Ulang',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: 'poppins',
          ),
        ),
        backgroundColor: Color.fromARGB(255, 4, 147, 9),
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            _buildSectionTabs(),
            const Divider(height: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _buildSectionBody(_sectionIndex),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          ScaleTransition(
            scale: _pulseScale,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(
                  42,
                  68,
                  65,
                  65,
                ).withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.recycling, color: Colors.teal, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Belajar Kelola Sampah',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Pahami jenis, dampak, serta cara pengolahan yang tepat. ',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTabs() {
    final labels = const [
      'Pengantar',
      'Jenis Sampah',
      'Kelebihan & Kekurangan',
      '3R & Tips',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _sectionIndex == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: selected,
              selectedColor: Colors.teal,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => setState(() => _sectionIndex = i),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionBody(int index) {
    switch (index) {
      case 0:
        return _buildIntroSection();
      case 1:
        return _buildJenisSection();
      case 2:
        return _buildProsConsSection();
      case 3:
        return _build3RTipsSection();
      default:
        return const SizedBox.shrink();
    }
  }

  // ===================== Section 0: Pengantar =====================
  Widget _buildIntroSection() {
    final items = [
      {
        'title': 'Apa itu Sampah?',
        'icon': Icons.delete_outline,
        'desc':
            'Sampah adalah sisa kegiatan manusia atau proses alam yang tidak lagi digunakan. Secara umum terbagi menjadi organik (mudah terurai) dan anorganik (sulit terurai). Tanpa pengelolaan yang baik, sampah dapat menimbulkan masalah: bau tidak sedap, penyakit akibat vektor (lalat/tikus), penyumbatan saluran air hingga banjir, dan degradasi ekosistem. \n\nMengelola sampah dimulai dari sumbernya: rumah, kantor, sekolah. Kunci utamanya adalah pemilahan, pengurangan penggunaan barang sekali pakai, penggunaan kembali, dan daur ulang sesuai jenis materialnya.',
      },
      {
        'title': 'Dampak Lingkungan',
        'icon': Icons.warning_amber_rounded,
        'desc':
            'Penumpukan sampah memicu pencemaran tanah (lindi), air (bahan kimia berbahaya), dan udara (pembakaran terbuka menghasilkan dioksin). Mikroplastik dari kemasan plastik masuk ke rantai makanan melalui air dan biota, berisiko pada kesehatan manusia. Di Tempat Pembuangan Akhir (TPA), sampah organik yang menumpuk mengeluarkan gas metana, salah satu gas rumah kaca yang berkontribusi terhadap perubahan iklim. Pengelolaan yang tepat membantu menekan dampak-dampak tersebut.',
      },
      {
        'title': 'Manfaat Pengelolaan',
        'icon': Icons.eco_outlined,
        'desc':
            'Pengelolaan sampah yang tepat mengurangi beban TPA, menghemat sumber daya (material kembali dimanfaatkan), dan menciptakan peluang ekonomi: bank sampah, pengepul, dan UMKM pengrajin daur ulang. Lingkungan menjadi lebih bersih, kesehatan masyarakat meningkat, dan kualitas hidup membaik. \n\nPemerintah, pelaku usaha, dan masyarakat memiliki peran. Kebiasaan kecil seperti membawa tumbler, tas kain, serta memilah sampah basah-kering di rumah akan berdampak besar jika dilakukan secara konsisten.',
      },
      {
        'title': 'Mengapa Pemilahan Penting?',
        'icon': Icons.category,
        'desc':
            'Pemilahan sejak awal menentukan keberhasilan daur ulang. Sampah yang tercampur (basah dengan kering) akan menurunkan kualitas material daur ulang dan sering berakhir di TPA. Dengan memisahkan organik (sisa makanan, daun) dan anorganik (plastik, kertas, kaca, logam), proses pengolahan berikutnya menjadi efisien, bernilai ekonomis, dan ramah lingkungan.',
      },
      {
        'title': 'Peran Individu & Komunitas',
        'icon': Icons.group_outlined,
        'desc':
            'Individu berperan sebagai penghasil sekaligus pengelola sampah di level rumah tangga. Komunitas dapat membentuk kelompok bank sampah, melakukan edukasi, dan menyelenggarakan program penukaran sampah. Sekolah dan kantor bisa menyediakan tempat pemilahan serta kebijakan pengurangan plastik sekali pakai. Sinergi ini mempercepat terciptanya budaya bersih dan bertanggung jawab.',
      },
    ];

    final visibleItems = _introExpanded ? items : items.take(2).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ...List.generate(visibleItems.length, (i) {
            return _animatedCard(
              index: i,
              child: _infoCard(
                icon: visibleItems[i]['icon'] as IconData,
                title: visibleItems[i]['title'] as String,
                desc: visibleItems[i]['desc'] as String,
              ),
            );
          }),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: Icon(
                _introExpanded ? Icons.expand_less : Icons.expand_more,
              ),
              label: Text(
                _introExpanded ? 'Tutup' : 'Baca Selengkapnya',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.teal,
                ),
              ),
              onPressed: () => setState(() => _introExpanded = !_introExpanded),
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 8),
          ...List.generate(_introChecklist.length, (i) {
            return _animatedCard(
              index: i + 10,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_introChecklist[i])),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===================== Section 1: Jenis =====================
  Widget _buildJenisSection() {
    final panels = [
      {
        'header': 'Organik',
        'icon': Icons.grass,
        'body':
            'Contoh: sisa makanan, daun, ranting, ampas kopi.\n'
            'Karakteristik: mudah terurai secara biologis.\n\n'
            'Pengolahan:\n'
            '• Kompos (takakura/komposter)\n'
            '• Biopori\n'
            '• Pakan ternak tertentu\n\n'
            'Catatan: Jangan dicampur dengan anorganik.',
      },
      {
        'header': 'Anorganik',
        'icon': Icons.recycling,
        'body':
            'Contoh: plastik, kaca, logam, kertas.\n'
            'Karakteristik: sulit terurai tapi bernilai ekonomi.\n\n'
            'Pengolahan:\n'
            '• Daur ulang\n'
            '• Reuse jika aman\n\n'
            'Catatan: Cuci & keringkan sebelum disetor.',
      },
      {
        'header': 'B3 (Berbahaya & Beracun)',
        'icon': Icons.health_and_safety,
        'body':
            'Contoh: baterai, lampu, oli, cat.\n\n'
            'Pengolahan:\n'
            '• Simpan terpisah\n'
            '• Serahkan ke pengelola berizin\n\n'
            'Catatan: Jangan dibakar.',
      },
      {
        'header': 'E-waste',
        'icon': Icons.memory,
        'body':
            'Contoh: HP, laptop, charger.\n\n'
            'Pengolahan:\n'
            '• Daur ulang elektronik resmi\n\n'
            'Catatan: Backup data dulu.',
      },
      {
        'header': 'Sampah Medis Rumah Tangga',
        'icon': Icons.healing,
        'body':
            'Contoh: masker, sarung tangan.\n\n'
            'Pengolahan:\n'
            '• Simpan tertutup\n'
            '• Ikuti panduan fasilitas kesehatan',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: panels.length,
      itemBuilder: (context, i) {
        final panel = panels[i];
        final checklist = _jenisChecklist[panel['header']] ?? <String>[];

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ExpansionTile(
            maintainState: true,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Icon(panel['icon'] as IconData, color: Colors.teal),
            title: Text(
              panel['header'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            children: [
              Text(
                panel['body'] as String,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Icon(Icons.checklist, color: Colors.teal),
                  SizedBox(width: 8),
                  Text(
                    'Checklist Pemilahan',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...checklist.map(
                (e) => InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showInfo(panel['header'] as String, e),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.touch_app,
                          color: Colors.teal,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===================== Section 2: Kelebihan & Kekurangan =====================
  Widget _buildProsConsSection() {
    final pros = [
      'Mengurangi volume sampah di TPA dan potensi banjir.',
      'Menghemat energi & sumber daya (bahan baku kembali dimanfaatkan).',
      'Menciptakan peluang ekonomi: bank sampah, UMKM kreasi daur ulang.',
      'Meningkatkan kualitas lingkungan & kesehatan masyarakat.',
      'Mendorong inovasi material dan desain produk yang lebih sirkular.',
    ];
    final cons = [
      'Membutuhkan pemilahan yang konsisten di rumah & tempat kerja.',
      'Biaya & fasilitas daur ulang belum merata di semua wilayah.',
      'Kualitas material daur ulang dapat menurun (downcycling).',
      'Kontaminasi sampah (basah-kering tercampur) menghambat proses.',
      'Kesadaran dan edukasi publik perlu waktu agar menjadi budaya.',
    ];

    final jenisCatatan = [
      {
        'title': 'Organik',
        'plus': 'Mudah jadi kompos, emisi lebih rendah bila dikelola baik.',
        'minus': 'Berbau & menarik hama bila tercampur/terbengkalai.',
      },
      {
        'title': 'Plastik/Kertas',
        'plus': 'Bernilai ekonomi, dapat diolah berulang (tergantung jenis).',
        'minus': 'Mikroplastik & kontaminasi menurunkan kualitas daur ulang.',
      },
      {
        'title': 'B3 & E-waste',
        'plus': 'Memulihkan logam berharga, menghindari pencemaran berat.',
        'minus': 'Perlu jalur khusus berizin & edukasi pengguna.',
      },
      {
        'title': 'Kaca & Logam',
        'plus':
            'Daya tahan tinggi, daur ulang efisien (khususnya aluminium/kaleng).',
        'minus': 'Bahaya pecah/terluka saat penanganan; perlu pemilahan baik.',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _animatedCard(
            index: 0,
            child: _prosConsCard(
              title: 'Kelebihan Daur Ulang',
              items: pros,
              icon: Icons.thumb_up_alt,
            ),
          ),
          _animatedCard(
            index: 1,
            child: _prosConsCard(
              title: 'Kekurangan/Tantangan',
              items: cons,
              icon: Icons.thumb_down_alt,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Icon(Icons.checklist, color: Colors.teal),
              SizedBox(width: 8),
              Text(
                'Aksi yang Disarankan',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(_prosActions.length, (i) {
            return _animatedCard(
              index: i + 20,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_prosActions[i])),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const Text(
            'Catatan per Jenis',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...List.generate(jenisCatatan.length, (i) {
            final j = jenisCatatan[i];
            return _animatedCard(
              index: i + 2,
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        j['title']!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text(j['plus']!)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text(j['minus']!)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===================== Section 3: 3R & Tips =====================
  Widget _build3RTipsSection() {
    final threeR = [
      {
        'icon': Icons.remove_circle_outline,
        'title': 'Reduce (Kurangi)',
        'desc':
            'Kurangi konsumsi barang sekali pakai dan pilih produk isi ulang.',
      },
      {
        'icon': Icons.replay,
        'title': 'Reuse (Gunakan Kembali)',
        'desc': 'Gunakan kembali wadah/kardus yang masih layak pakai.',
      },
      {
        'icon': Icons.recycling,
        'title': 'Recycle (Daur Ulang)',
        'desc': 'Pilah sesuai jenis material agar bisa didaur ulang.',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(threeR.length, (i) {
            final t = threeR[i];
            return _animatedCard(
              index: i,
              child: ListTile(
                leading: Icon(t['icon'] as IconData, color: Colors.teal),
                title: Text(t['title'] as String),
                subtitle: Text(t['desc'] as String),
                tileColor: Colors.teal.withAlpha((0.06 * 255).round()),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(Icons.lightbulb, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Tips Harian',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _tipsCard(
              key: ValueKey(_tipsIndex),
              tip: _tipsHarian[_tipsIndex],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Ganti Tips'),
              onPressed: () {
                setState(
                  () => _tipsIndex = (_tipsIndex + 1) % _tipsHarian.length,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(Icons.calendar_today, color: Colors.teal),
              SizedBox(width: 8),
              Text(
                'Rencana Mingguan 3R',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_threeRWeekly.length, (i) {
            return _animatedCard(
              index: i + 30,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_threeRWeekly[i])),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===================== Helpers =====================
  Widget _animatedCard({required int index, required Widget child}) {
    // Animasi ringan: slide + fade, dengan sedikit penundaan per index.
    final delayMs = 60 * index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + delayMs),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        );
      },
    );
  }

  void _showInfo(String category, String text) {
    final actions = _saranTindakan[category] ?? const [];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        category,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(text),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Icon(Icons.lightbulb, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Saran Tindakan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...actions.map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Expanded(child: Text(e)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.withAlpha((0.08 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(desc),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prosConsCard({
    required String title,
    required List<String> items,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tipsCard({required Map<String, String> tip, Key? key}) {
    return Card(
      key: key,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.tips_and_updates, color: Colors.orange),
        title: Text(
          tip['title']!,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(tip['desc']!),
      ),
    );
  }
}
