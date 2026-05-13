// ═══════════════════════════════════════════════════════════════════════════════
// CivicEye — Merged Application
// Combines: main.dart (Smart City Dashboard) + image_classifier.dart (ML Kit)
// Changes: ImageClassifierScreen added as 4th admin-only tab "Classify"
//          CivicIssueClassifier / ClassificationResult / CivicCategory live here
//          _SubmitReportPage accepts prefillCategory + prefillImageBytes
//          "Save as Report" button added to classifier result card
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SmartCityApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  static const bg = Color(0xFF04060F);
  static const surface = Color(0xFF0B0F1E);
  static const card = Color(0xFF111827);
  static const cardBorder = Color(0xFF1E2A3A);
  static const accent = Color(0xFF00E5FF);
  static const accentGlow = Color(0x3300E5FF);
  static const accentSoft = Color(0xFF0097A7);
  static const gold = Color(0xFFFFD700);
  static const goldSoft = Color(0xFFB8960C);
  static const danger = Color(0xFFFF3D5A);
  static const warning = Color(0xFFFF9100);
  static const success = Color(0xFF00E676);
  static const textPrimary = Color(0xFFF0F4FF);
  static const textSecondary = Color(0xFF7A8BA0);
  static const textMuted = Color(0xFF3A4A5A);

  static LinearGradient get accentGradient => const LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF0097FF)],
  );
  static LinearGradient get goldGradient => const LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────
class AlertItem {
  final String title;
  final String level;
  final double x;
  final double y;
  final String zone;
  const AlertItem(this.title, this.level, this.x, this.y, this.zone);
}

class CivilianReport {
  final String id;
  final String category;
  final String description;
  final String area;
  final Uint8List? image;
  final DateTime submittedAt;
  String status;

  CivilianReport({
    required this.id,
    required this.category,
    required this.description,
    required this.area,
    this.image,
    required this.submittedAt,
    this.status = "Pending",
  });
}

const List<AlertItem> kAlerts = [
  AlertItem("Garbage Overflow — Ward 12", "HIGH", 0.62, 0.38, "Zone A"),
  AlertItem("Drain Block Risk — Sector B", "MED", 0.45, 0.55, "Zone C"),
  AlertItem("Traffic Congestion — Main Rd", "MED", 0.70, 0.60, "Zone B"),
  AlertItem("Power Fluctuation — Zone 3", "LOW", 0.30, 0.70, "Zone D"),
  AlertItem("Water Leak — Pipeline 7A", "HIGH", 0.55, 0.25, "Zone A"),
];

const List<String> kCategories = [
  "Garbage / Waste", "Road Damage", "Drainage / Flooding",
  "Street Light", "Water Supply", "Traffic Issue", "Other",
];

const List<IconData> kCategoryIcons = [
  Icons.delete_outline_rounded, Icons.construction_rounded,
  Icons.water_rounded, Icons.lightbulb_outline_rounded,
  Icons.water_drop_outlined, Icons.traffic_rounded, Icons.more_horiz_rounded,
];

Color levelColor(String level) {
  switch (level) {
    case "HIGH": return AppTheme.danger;
    case "MED":  return AppTheme.warning;
    default:     return AppTheme.gold;
  }
}

Color statusColor(String status) {
  switch (status) {
    case "Resolved": return AppTheme.success;
    case "Reviewed": return AppTheme.accent;
    default:         return AppTheme.warning;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ① IMAGE CLASSIFIER
// ─────────────────────────────────────────────────────────────────────────────

class CivicCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<String> keywords;

  const CivicCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.keywords,
  });
}

const List<CivicCategory> civicCategories = [
  CivicCategory(
    name: 'Garbage',
    icon: Icons.delete_outline,
    color: Color(0xFFE53935),
    keywords: [
      'garbage', 'trash', 'waste', 'rubbish', 'litter', 'junk',
      'street garbage', 'roadside waste', 'overflowing trash', 'garbage pile',
      'waste pile', 'garbage heap', 'open dumping', 'illegal dumping',
      'dumped waste', 'public waste', 'municipal waste', 'waste accumulation',
      'plastic waste', 'plastic bags', 'food waste', 'household waste',
      'packaging waste', 'discarded items', 'garbage bags', 'paper waste',
      'mixed waste', 'solid waste', 'dirty road', 'unclean street', 'filth',
      'debris', 'pollution', 'unsanitary', 'dirty surroundings',
      'waste on road', 'trash on street', 'sanitation issue', 'poor sanitation',
      'unclean public area', 'civic issue', 'urban waste problem',
      'waste management issue', 'roadside garbage bags', 'overflowing garbage',
      'scattered waste', 'plastic litter', 'dumpyard', 'trash dumping spot',
      'garbage beside road', 'waste near sidewalk', 'bbmp garbage',
      'municipal cleaning issue', 'street dumping', 'public cleanliness issue',
    ],
  ),
  CivicCategory(
    name: 'Pot Holes',
    icon: Icons.warning_amber_outlined,
    color: Color(0xFFFF6F00),
    keywords: [
      'pothole', 'road', 'crack', 'asphalt', 'pavement', 'hole',
      'damage', 'broken road', 'gravel', 'surface', 'pit',
      'street damage', 'road damage', 'tarmac', 'concrete', 'bump',
    ],
  ),
  CivicCategory(
    name: 'Street',
    icon: Icons.streetview,
    color: Color(0xFF1565C0),
    keywords: [
      'street', 'road', 'sidewalk', 'footpath', 'lane', 'avenue',
      'boulevard', 'path', 'walkway', 'curb', 'gutter', 'median',
      'pedestrian', 'crossing', 'sign', 'traffic light', 'lamp post',
    ],
  ),
  CivicCategory(
    name: 'Water',
    icon: Icons.water_drop_outlined,
    color: Color(0xFF0288D1),
    keywords: [
      'water', 'flood', 'puddle', 'leak', 'pipe', 'overflow',
      'waterlogging', 'drain', 'sewage', 'wet', 'pool', 'river',
      'rain', 'moisture', 'stagnant', 'tap', 'valve', 'burst pipe',
    ],
  ),
  CivicCategory(
    name: 'Traffic',
    icon: Icons.traffic_outlined,
    color: Color(0xFF6A1B9A),

    keywords: [

      // Core traffic terms
      'traffic',
      'traffic jam',
      'road congestion',
      'vehicle congestion',
      'heavy traffic',
      'busy road',
      'crowded road',
      'urban traffic',

      // Vehicle types
      'car',
      'bus',
      'truck',
      'motorcycle',
      'bike',
      'scooter',
      'auto rickshaw',
      'vehicle',
      'commercial vehicle',

      // Indian traffic scene
      'city traffic',
      'indian traffic',
      'metro traffic',
      'crowded intersection',
      'junction traffic',
      'signal traffic',

      // Traffic conditions
      'slow moving vehicles',
      'traffic buildup',
      'gridlock',
      'road blockage',
      'lane congestion',
      'vehicle queue',
      'bumper to bumper traffic',

      // Road infrastructure
      'traffic signal',
      'traffic light',
      'intersection',
      'junction',
      'main road',
      'flyover traffic',
      'road divider',

      // Civic/transport issues
      'parking violation',
      'illegal parking',
      'road obstruction',
      'traffic violation',
      'public transport traffic',

      // Scene indicators from images
      'multiple vehicles',
      'crowded street',
      'rush hour',
      'busy junction',
      'dense traffic',
      'urban mobility issue',
    ],
  ),
  CivicCategory(
    name: 'Drainage',
    icon: Icons.plumbing_outlined,
    color: Color(0xFF2E7D32),
    keywords: [
      'drain', 'drainage', 'sewer', 'manhole', 'gutter', 'canal',
      'pipe', 'blockage', 'clog', 'overflow', 'open drain', 'channel',
      'culvert', 'storm drain', 'grille', 'cover', 'stench',
    ],
  ),
];

class CivicIssueClassifier {
  final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.4),
  );

  Future<ClassificationResult> classify(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final labels = await _labeler.processImage(inputImage);

    if (labels.isEmpty) {
      return ClassificationResult(
        category: null, detectedLabels: [], matchedKeyword: null, confidence: 0,
      );
    }

    Map<CivicCategory, double> scores = {};
    for (final label in labels) {
      final labelText = label.label.toLowerCase();
      for (final category in civicCategories) {
        for (final keyword in category.keywords) {
          if (labelText.contains(keyword) || keyword.contains(labelText)) {
            scores[category] = (scores[category] ?? 0) + label.confidence;
          }
        }
      }
    }

    if (scores.isEmpty) {
      return ClassificationResult(
        category: null,
        detectedLabels: labels.map((l) => l.label).toList(),
        matchedKeyword: null,
        confidence: 0,
      );
    }

    final best = scores.entries.reduce((a, b) => a.value > b.value ? a : b);

    String? matchedKeyword;
    for (final label in labels) {
      for (final keyword in best.key.keywords) {
        if (label.label.toLowerCase().contains(keyword) ||
            keyword.contains(label.label.toLowerCase())) {
          matchedKeyword = label.label;
          break;
        }
      }
      if (matchedKeyword != null) break;
    }

    return ClassificationResult(
      category: best.key,
      detectedLabels: labels.map((l) => l.label).toList(),
      matchedKeyword: matchedKeyword,
      confidence: (best.value * 100).clamp(0, 100),
    );
  }

  void dispose() => _labeler.close();
}

class ClassificationResult {
  final CivicCategory? category;
  final List<String> detectedLabels;
  final String? matchedKeyword;
  final double confidence;

  ClassificationResult({
    required this.category,
    required this.detectedLabels,
    required this.matchedKeyword,
    required this.confidence,
  });

  bool get isClassified => category != null;
}

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE CLASSIFIER SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ImageClassifierScreen extends StatefulWidget {
  const ImageClassifierScreen({super.key});
  @override
  State<ImageClassifierScreen> createState() => _ImageClassifierScreenState();
}

class _ImageClassifierScreenState extends State<ImageClassifierScreen> {
  final _classifier = CivicIssueClassifier();
  final _picker = ImagePicker();
  File? _selectedImage;
  ClassificationResult? _result;
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _selectedImage = File(picked.path);
      _result = null;
      _isLoading = true;
    });
    final result = await _classifier.classify(_selectedImage!);
    setState(() {
      _result = result;
      _isLoading = false;
    });
  }

  void _saveAsReport(ClassificationResult result) {
    Uint8List? imageBytes;
    try {
      imageBytes = _selectedImage?.readAsBytesSync();
    } catch (_) {}

    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textSecondary),
            onPressed: () => Navigator.pop(ctx),
          ),
          title: const Text(
            "File Report",
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: _SubmitReportPage(
          prefillCategory: result.category?.name,
          prefillImageBytes: imageBytes,
          onSubmit: (report) {
            // Bubble up to DashboardPage
            final dashboard = ctx.findAncestorStateOfType<_DashboardPageState>();
            dashboard?._addReport(report);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded, color: AppTheme.success, size: 14),
                ),
                const SizedBox(width: 12),
                Text("${report.id} filed from classifier!"),
              ]),
              backgroundColor: const Color(0xFF0D1A2A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              duration: const Duration(seconds: 3),
            ));
          },
        ),
      ),
    ));
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.35),
                    blurRadius: 12)
              ],
            ),
            child: const Icon(Icons.document_scanner_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("AI Issue Classifier", style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            )),
            Text("On-device ML Kit detection",
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ]),
        const SizedBox(height: 20),

        // Category chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: civicCategories.map((c) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: c.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.color.withOpacity(0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(c.icon, size: 13, color: c.color),
              const SizedBox(width: 5),
              Text(c.name, style: TextStyle(
                  fontSize: 11,
                  color: c.color,
                  fontWeight: FontWeight.w600)),
            ]),
          )).toList(),
        ),
        const SizedBox(height: 20),

        // Image preview
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFF080E1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _selectedImage != null
                  ? const Color(0xFF7C3AED).withOpacity(0.5)
                  : AppTheme.cardBorder,
              width: _selectedImage != null ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: _selectedImage == null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.2)),
              ),
              child: const Icon(Icons.add_photo_alternate_outlined,
                  size: 30, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 12),
            const Text('Upload an image to classify',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ])
              : _isLoading
              ? Stack(fit: StackFit.expand, children: [
            Image.file(_selectedImage!, fit: BoxFit.cover),
            Container(color: Colors.black54),
            const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.accent)),
          ])
              : Image.file(_selectedImage!, fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),

        // Pick buttons
        Row(children: [
          Expanded(
              child: _pickButton(Icons.camera_alt_rounded, 'Camera',
                      () => _pickImage(ImageSource.camera))),
          const SizedBox(width: 12),
          Expanded(
              child: _pickButton(Icons.photo_library_rounded, 'Gallery',
                      () => _pickImage(ImageSource.gallery))),
        ]),
        const SizedBox(height: 20),

        // Result card
        if (_result != null) _buildResultCard(_result!),
      ]),
    );
  }

  Widget _pickButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildResultCard(ClassificationResult result) {
    if (!result.isClassified) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1220),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(Icons.help_outline_rounded, color: AppTheme.warning, size: 20),
          const SizedBox(width: 12),
          const Expanded(
              child: Text(
                'Could not match any civic category.\nTry a clearer image.',
                style: TextStyle(
                    color: AppTheme.warning, fontSize: 13, height: 1.5),
              )),
        ]),
      );
    }

    final cat = result.category!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cat.color.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: cat.color.withOpacity(0.08), blurRadius: 20)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Category header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cat.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(cat.icon, color: cat.color, size: 26),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Detected Issue',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
            Text(cat.name, style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: cat.color,
            )),
          ]),
        ]),
        const SizedBox(height: 18),

        // Confidence bar
        Row(children: [
          Text('Confidence',
              style:
              TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const Spacer(),
          Text('${result.confidence.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cat.color,
                  fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: result.confidence / 100,
            backgroundColor: AppTheme.cardBorder,
            valueColor: AlwaysStoppedAnimation(cat.color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 16),

        if (result.matchedKeyword != null) ...[
          Text('Matched via: "${result.matchedKeyword}"',
              style: TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
        ],

        Text('ML Kit Labels Detected:',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: result.detectedLabels
              .map((l) => Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.cardBorder.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(l,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textPrimary)),
          ))
              .toList(),
        ),

        // ── Save as Report button ──────────────────────────────────────
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => _saveAsReport(result),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text("Save as Report",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────────────────────────────────────
class SmartCityApp extends StatelessWidget {
  const SmartCityApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "CivicEye",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppTheme.bg,
        colorScheme:
        const ColorScheme.dark(primary: AppTheme.accent),
      ),
      home: const LoginPage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN PAGE
// ─────────────────────────────────────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _idCtrl   = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure  = true;
  bool _loading  = false;
  String? _error;
  late AnimationController _bgCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl   = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _fadeCtrl.dispose();
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    final id   = _idCtrl.text.trim();
    final pass = _passCtrl.text;
    if (id == "main@civiceye" && pass == "civiceye1") {
      if (mounted)
        Navigator.pushReplacement(
            context, _fadeRoute(const DashboardPage(publicOnly: false)));
    } else if (id == "pub@civiceye" && pass == "civiceye2") {
      if (mounted)
        Navigator.pushReplacement(
            context, _fadeRoute(const DashboardPage(publicOnly: true)));
    } else {
      setState(() {
        _error = "Invalid credentials. Please try again.";
        _loading = false;
      });
    }
  }

  PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, a, __) => page,
    transitionsBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
    transitionDuration: const Duration(milliseconds: 600),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(children: [
        Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) =>
                  CustomPaint(painter: _LoginBgPainter(_bgCtrl.value)),
            )),
        SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Center(
                  child: SingleChildScrollView(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(children: [
                      const SizedBox(height: 40),
                      _buildLogo(),
                      const SizedBox(height: 48),
                      _buildLoginCard(),
                      const SizedBox(height: 24),
                      _buildHintCard(),
                      const SizedBox(height: 40),
                    ]),
                  )),
            )),
      ]),
    );
  }

  Widget _buildLogo() {
    return Column(children: [
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.accentGradient,
          boxShadow: [
            BoxShadow(
                color: AppTheme.accent.withOpacity(0.4),
                blurRadius: 40,
                spreadRadius: 8),
            BoxShadow(
                color: AppTheme.accent.withOpacity(0.15),
                blurRadius: 80,
                spreadRadius: 20),
          ],
        ),
        child: const Icon(Icons.remove_red_eye_rounded,
            color: Colors.white, size: 36),
      ),
      const SizedBox(height: 20),
      ShaderMask(
        shaderCallback: (b) => AppTheme.accentGradient.createShader(b),
        child: const Text("CIVICEYE",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 8,
            )),
      ),
      const SizedBox(height: 6),
      Text("AI URBAN INTELLIGENCE PLATFORM",
          style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              letterSpacing: 3)),
    ]);
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1220),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 20)),
          BoxShadow(
              color: AppTheme.accent.withOpacity(0.04), blurRadius: 60),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(2),
              )),
          const SizedBox(width: 12),
          const Text("Secure Access",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              )),
        ]),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text("Enter your portal credentials",
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
        ),
        const SizedBox(height: 28),
        _premiumField(
            ctrl: _idCtrl,
            hint: "Login ID",
            icon: Icons.alternate_email_rounded,
            label: "IDENTIFIER"),
        const SizedBox(height: 16),
        _premiumField(
          ctrl: _passCtrl,
          hint: "••••••••",
          icon: Icons.lock_outline_rounded,
          label: "PASSWORD",
          obscure: _obscure,
          suffix: IconButton(
            icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.textSecondary,
                size: 18),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border:
              Border.all(color: AppTheme.danger.withOpacity(0.25)),
            ),
            child: Row(children: [
              Icon(Icons.error_outline_rounded,
                  color: AppTheme.danger, size: 16),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(_error!,
                      style: TextStyle(
                          color: AppTheme.danger, fontSize: 12))),
            ]),
          ),
        ],
        const SizedBox(height: 28),
        _premiumButton(),
      ]),
    );
  }

  Widget _premiumButton() {
    return GestureDetector(
      onTap: _loading ? null : _login,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: _loading ? null : AppTheme.accentGradient,
          color: _loading ? AppTheme.cardBorder : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _loading
              ? []
              : [
            BoxShadow(
                color: AppTheme.accent.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Center(
            child: _loading
                ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent))
                : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login_rounded,
                      color: AppTheme.bg, size: 18),
                  const SizedBox(width: 10),
                  Text("ACCESS PORTAL",
                      style: TextStyle(
                        color: AppTheme.bg,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 2,
                      )),
                ])),
      ),
    );
  }

  Widget _buildHintCard() {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.info_outline_rounded,
              size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text("DEMO CREDENTIALS",
              style: TextStyle(
                  fontSize: 9,
                  color: AppTheme.textMuted,
                  letterSpacing: 2)),
        ]),
        const SizedBox(height: 10),
        _credRow("Admin Portal", "main@civiceye", "civiceye1",
            AppTheme.accent),
        const SizedBox(height: 6),
        _credRow(
            "Public Portal", "pub@civiceye", "civiceye2", AppTheme.gold),
      ]),
    );
  }

  Widget _credRow(
      String role, String id, String pass, Color color) {
    return Row(children: [
      Container(
          width: 6,
          height: 6,
          decoration:
          BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(role,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600)),
      const Spacer(),
      Text("$id  •  $pass",
          style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontFamily: 'monospace')),
    ]);
  }

  Widget _premiumField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    required String label,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(label,
            style: TextStyle(
              fontSize: 9,
              color: AppTheme.textSecondary,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            )),
      ),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF080E1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              letterSpacing: 0.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
            TextStyle(color: AppTheme.textMuted, fontSize: 14),
            prefixIcon: Padding(
              padding:
              const EdgeInsets.only(left: 16, right: 12),
              child: Icon(icon, color: AppTheme.accent, size: 18),
            ),
            prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: suffix,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            border: InputBorder.none,
          ),
        ),
      ),
    ]);
  }
}

class _LoginBgPainter extends CustomPainter {
  final double t;
  _LoginBgPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF060B1A),
              Color(0xFF04060F),
              Color(0xFF07091A)
            ],
          ).createShader(
              Rect.fromLTWH(0, 0, size.width, size.height)));
    final glow = Paint()
      ..maskFilter =
      const MaskFilter.blur(BlurStyle.normal, 120);
    glow.color = AppTheme.accent.withOpacity(0.06 + t * 0.04);
    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.2), 200, glow);
    glow.color =
        AppTheme.accentSoft.withOpacity(0.04 + t * 0.03);
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.75), 180, glow);
    final grid = Paint()
      ..color = AppTheme.accent.withOpacity(0.03)
      ..strokeWidth = 0.5;
    for (int i = 0; i < 20; i++) {
      canvas.drawLine(Offset(size.width * i / 20, 0),
          Offset(size.width * i / 20, size.height), grid);
    }
    for (int i = 0; i < 40; i++) {
      canvas.drawLine(Offset(0, size.height * i / 40),
          Offset(size.width, size.height * i / 40), grid);
    }
  }

  @override
  bool shouldRepaint(_LoginBgPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD PAGE
// ─────────────────────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  final bool publicOnly;
  const DashboardPage({super.key, required this.publicOnly});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _blinkCtrl;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  int _selectedTab = 0;
  final List<CivilianReport> _reports = [];

  @override
  void initState() {
    super.initState();
    if (widget.publicOnly) _selectedTab = 2;
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _blinkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(CurvedAnimation(
            parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _blinkCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _addReport(CivilianReport r) =>
      setState(() => _reports.insert(0, r));

  void _logout() => Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const LoginPage(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(children: [
        Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) =>
                  CustomPaint(painter: CityMapPainter(_pulseCtrl.value)),
            )),
        Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.bg.withOpacity(0.85),
                    AppTheme.bg.withOpacity(0.75)
                  ],
                ),
              ),
            )),
        SafeArea(
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _slideCtrl,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 12),
                      if (!widget.publicOnly) ...[
                        _buildTabBar(),
                        const SizedBox(height: 16),
                        Expanded(child: _buildContent()),
                      ] else ...[
                        _buildPublicBanner(),
                        const SizedBox(height: 12),
                        Expanded(
                            child: _SubmitReportPage(
                                onSubmit: _addReport)),
                      ],
                    ]),
              ),
            )),

        // Notification FAB — only on Monitor tab
        if (!widget.publicOnly && _selectedTab == 0)
          Positioned(
            right: 20,
            bottom: 248,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) => Transform.scale(
                  scale: 1.0 + _pulseCtrl.value * 0.08,
                  child: child),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [
                    AppTheme.danger,
                    Color(0xFFFF6B6B)
                  ]),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.danger.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2)
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 22),
                  onPressed: () =>
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Row(children: [
                          Icon(Icons.notifications_active,
                              color: Colors.white, size: 16),
                          SizedBox(width: 10),
                          Text("5 active alerts in your area"),
                        ]),
                        backgroundColor: AppTheme.card,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      )),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ShaderMask(
              shaderCallback: (b) =>
                  AppTheme.accentGradient.createShader(b),
              child: const Text("CIVICEYE",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 4,
                  )),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: AppTheme.gold.withOpacity(0.4)),
              ),
              child: Text(
                  widget.publicOnly ? "PUBLIC" : "ADMIN",
                  style: const TextStyle(
                      fontSize: 8,
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
            ),
          ]),
          Text("Urban Intelligence Platform",
              style: TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary)),
        ]),
        const Spacer(),
        _LiveDot(ctrl: _blinkCtrl),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _logout,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Icon(Icons.logout_rounded,
                color: AppTheme.textSecondary, size: 18),
          ),
        ),
      ]),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      (Icons.dashboard_outlined, Icons.dashboard_rounded, "Monitor"),
      (Icons.receipt_long_outlined, Icons.receipt_long_rounded, "Reports"),
      (Icons.add_photo_alternate_outlined,
      Icons.add_photo_alternate_rounded, "Report"),
      (Icons.document_scanner_outlined,
      Icons.document_scanner_rounded, "Classify"),
    ];
    final pendingCount =
        _reports.where((r) => r.status == "Pending").length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF080D18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
            children: List.generate(tabs.length, (i) {
              final isActive = _selectedTab == i;
              final isClassify = i == 3;
              return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: isActive
                          ? BoxDecoration(
                        gradient: isClassify
                            ? const LinearGradient(colors: [
                          Color(0xFF7C3AED),
                          Color(0xFF4F46E5)
                        ])
                            : AppTheme.accentGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: (isClassify
                                ? const Color(0xFF7C3AED)
                                : AppTheme.accent)
                                .withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      )
                          : null,
                      child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      isActive
                                          ? tabs[i].$2
                                          : tabs[i].$1,
                                      size: 17,
                                      color: isActive
                                          ? AppTheme.bg
                                          : AppTheme.textSecondary),
                                  const SizedBox(height: 3),
                                  Text(tabs[i].$3,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: isActive
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isActive
                                            ? AppTheme.bg
                                            : AppTheme.textSecondary,
                                        letterSpacing: 0.5,
                                      )),
                                ]),
                            if (i == 1 &&
                                pendingCount > 0 &&
                                !isActive)
                              Positioned(
                                  top: 0,
                                  right: 8,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: const BoxDecoration(
                                        color: AppTheme.danger,
                                        shape: BoxShape.circle),
                                    child: Center(
                                        child: Text('$pendingCount',
                                            style: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.white,
                                                fontWeight:
                                                FontWeight.bold))),
                                  )),
                          ]),
                    ),
                  ));
            })),
      ),
    );
  }

  Widget _buildPublicBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppTheme.gold.withOpacity(0.1),
            AppTheme.gold.withOpacity(0.05)
          ]),
          borderRadius: BorderRadius.circular(14),
          border:
          Border.all(color: AppTheme.gold.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.campaign_outlined,
                color: AppTheme.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Public Reporter Portal",
                style: TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            Text("Submit civic issues in your area",
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _ReportsListPage(reports: _reports);
      case 2:
        return _SubmitReportPage(onSubmit: _addReport);
      case 3:
        return const ImageClassifierScreen();
      default:
        return _buildDashboardTab();
    }
  }

  Widget _buildDashboardTab() {
    return Column(children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          _StatCard("Active Alerts", "12",
              Icons.warning_amber_rounded, AppTheme.danger),
          const SizedBox(width: 12),
          _StatCard(
              "Sensors", "182", Icons.sensors_rounded, AppTheme.accent),
          const SizedBox(width: 12),
          _StatCard("On-Field", "36", Icons.engineering_rounded,
              AppTheme.success),
          const SizedBox(width: 12),
          _StatCard("Reports", _reports.length.toString(),
              Icons.camera_alt_rounded, AppTheme.gold),
        ]),
      ),
      const Spacer(),
      _AlertsPanel(alerts: kAlerts, blinkCtrl: _blinkCtrl),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT CARD
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.08), blurRadius: 20)
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18)),
            const SizedBox(height: 14),
            FittedBox(
                child: Text(value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ))),
            const SizedBox(height: 2),
            Text(title,
                style: TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE DOT
// ─────────────────────────────────────────────────────────────────────────────
class _LiveDot extends StatelessWidget {
  final AnimationController ctrl;
  const _LiveDot({required this.ctrl});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppTheme.success.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.success
                    .withOpacity(0.5 + ctrl.value * 0.5),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.success
                          .withOpacity(ctrl.value * 0.6),
                      blurRadius: 6)
                ],
              )),
          const SizedBox(width: 6),
          const Text("LIVE",
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.success,
                  letterSpacing: 1.5)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERTS PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _AlertsPanel extends StatelessWidget {
  final List<AlertItem> alerts;
  final AnimationController blinkCtrl;
  const _AlertsPanel(
      {required this.alerts, required this.blinkCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF070B15),
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, -10))
        ],
      ),
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.bolt_rounded,
                      color: AppTheme.danger, size: 18),
                  const SizedBox(width: 8),
                  const Text("Live Alerts",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      )),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.danger.withOpacity(0.2)),
                  ),
                  child: Text(
                      "${alerts.where((a) => a.level == 'HIGH').length} HIGH",
                      style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ),
              ]),
        ),
        Expanded(
            child: ListView.builder(
              padding:
              const EdgeInsets.fromLTRB(20, 10, 20, 16),
              scrollDirection: Axis.horizontal,
              itemCount: alerts.length,
              itemBuilder: (_, i) =>
                  _AlertChip(alert: alerts[i]),
            )),
      ]),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final AlertItem alert;
  const _AlertChip({required this.alert});
  @override
  Widget build(BuildContext context) {
    final color = levelColor(alert.level);
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(alert.level,
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        )),
                  ),
                  Text(alert.zone,
                      style: TextStyle(
                          fontSize: 9, color: AppTheme.textMuted)),
                ]),
            const Spacer(),
            Icon(Icons.warning_amber_rounded,
                color: color, size: 22),
            const SizedBox(height: 6),
            Text(alert.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBMIT REPORT PAGE
// ─────────────────────────────────────────────────────────────────────────────
class _SubmitReportPage extends StatefulWidget {
  final ValueChanged<CivilianReport> onSubmit;
  final String? prefillCategory;
  final Uint8List? prefillImageBytes;

  const _SubmitReportPage({
    required this.onSubmit,
    this.prefillCategory,
    this.prefillImageBytes,
  });

  @override
  State<_SubmitReportPage> createState() => _SubmitReportPageState();
}

class _SubmitReportPageState extends State<_SubmitReportPage> {
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  int _selectedCategoryIndex = 0;
  final _descCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from classifier if provided
    if (widget.prefillCategory != null) {
      final idx = kCategories.indexWhere((c) =>
          c.toLowerCase().contains(
            widget.prefillCategory!.toLowerCase(),
          ));
      if (idx != -1) _selectedCategoryIndex = idx;
    }
    if (widget.prefillImageBytes != null) {
      _imageBytes = widget.prefillImageBytes;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final xf = await _picker.pickImage(
          source: src, imageQuality: 80, maxWidth: 1080);
      if (xf != null) {
        final bytes = await xf.readAsBytes();
        setState(() => _imageBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(Icons.error_outline_rounded,
                color: AppTheme.danger, size: 16),
            const SizedBox(width: 10),
            const Text(
                "Camera not available. Try gallery instead."),
          ]),
          backgroundColor: const Color(0xFF1A0D0D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C1525),
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 3,
                      decoration: BoxDecoration(
                          color: AppTheme.cardBorder,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text("Add Evidence Photo",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  )),
              const SizedBox(height: 4),
              Text("Attach a photo to strengthen your report",
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: _pickerBtn(
                        Icons.camera_alt_rounded,
                        "Camera",
                        AppTheme.accent, () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    })),
                const SizedBox(width: 12),
                Expanded(
                    child: _pickerBtn(
                        Icons.photo_library_rounded,
                        "Gallery",
                        AppTheme.gold, () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    })),
              ]),
            ]),
      ),
    );
  }

  Widget _pickerBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _submit() async {
    if (_areaCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(Icons.error_outline_rounded,
              color: AppTheme.danger, size: 16),
          const SizedBox(width: 10),
          const Text("Please fill in area and description"),
        ]),
        backgroundColor: const Color(0xFF1A0D0D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 900));
    final report = CivilianReport(
      id: "RPT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
      category: kCategories[_selectedCategoryIndex],
      description: _descCtrl.text.trim(),
      area: _areaCtrl.text.trim(),
      image: _imageBytes,
      submittedAt: DateTime.now(),
    );
    widget.onSubmit(report);
    setState(() {
      _submitting = false;
      _imageBytes = null;
      _descCtrl.clear();
      _areaCtrl.clear();
      _selectedCategoryIndex = 0;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded,
                  color: AppTheme.success, size: 14)),
          const SizedBox(width: 12),
          Text("${report.id} submitted successfully!"),
        ]),
        backgroundColor: const Color(0xFF0D1A2A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromClassifier = widget.prefillCategory != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.accent.withOpacity(0.3),
                      blurRadius: 12)
                ],
              ),
              child: Icon(Icons.add_location_alt_rounded,
                  color: AppTheme.bg, size: 20)),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("File a Report",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                )),
            Text(
                fromClassifier
                    ? "Pre-filled from AI classifier"
                    : "Document civic issues in your area",
                style: TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ]),

        // ── Classifier origin banner ───────────────────────────────────
        if (fromClassifier) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF7C3AED).withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Category \"${widget.prefillCategory}\" and photo were pre-filled by AI. "
                      "Please add your location to complete the report.",
                  style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF7C3AED)
                          .withOpacity(0.9),
                      height: 1.4),
                ),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 24),

        // Image upload
        GestureDetector(
          onTap: _showPicker,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFF080E1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _imageBytes != null
                    ? AppTheme.accent.withOpacity(0.5)
                    : AppTheme.cardBorder,
                width: _imageBytes != null ? 1.5 : 1,
              ),
              boxShadow: _imageBytes != null
                  ? [
                BoxShadow(
                    color: AppTheme.accent.withOpacity(0.1),
                    blurRadius: 20)
              ]
                  : [],
            ),
            child: _imageBytes == null
                ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.2)),
                      ),
                      child: Icon(Icons.add_a_photo_outlined,
                          color: AppTheme.accent, size: 28)),
                  const SizedBox(height: 14),
                  const Text("Attach Evidence Photo",
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text("Camera or Gallery  •  Optional",
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 11)),
                ])
                : Stack(fit: StackFit.expand, children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Image.memory(_imageBytes!,
                      fit: BoxFit.cover)),
              ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.4)
                          ],
                        )),
                  )),
              Positioned(
                  bottom: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: _showPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                            Colors.white.withOpacity(0.15)),
                      ),
                      child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded,
                                color: Colors.white, size: 13),
                            SizedBox(width: 5),
                            Text("Replace",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                  )),
              Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _imageBytes = null),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color:
                            AppTheme.danger.withOpacity(0.4)),
                      ),
                      child: Icon(Icons.close_rounded,
                          color: AppTheme.danger, size: 14),
                    ),
                  )),
            ]),
          ),
        ),
        const SizedBox(height: 24),

        Text("ISSUE CATEGORY",
            style: TextStyle(
              fontSize: 9,
              color: AppTheme.textSecondary,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: kCategories.length,
            itemBuilder: (_, i) {
              final sel = _selectedCategoryIndex == i;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedCategoryIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 78,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppTheme.accent.withOpacity(0.12)
                        : const Color(0xFF080E1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sel
                          ? AppTheme.accent.withOpacity(0.6)
                          : AppTheme.cardBorder,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(kCategoryIcons[i],
                            color: sel
                                ? AppTheme.accent
                                : AppTheme.textSecondary,
                            size: 20),
                        const SizedBox(height: 5),
                        Text(kCategories[i].split(' ').first,
                            style: TextStyle(
                              fontSize: 9,
                              color: sel
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                            textAlign: TextAlign.center),
                      ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),

        Text("LOCATION",
            style: TextStyle(
              fontSize: 9,
              color: AppTheme.textSecondary,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 10),
        _premiumTextField(
            ctrl: _areaCtrl,
            hint: "Ward 12, Koramangala, Sector B...",
            icon: Icons.location_on_rounded),

        // ── Address nudge when coming from classifier ──────────────────
        if (fromClassifier) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                size: 11, color: AppTheme.accent),
            const SizedBox(width: 5),
            Text("Enter the location where this issue was spotted",
                style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.accent.withOpacity(0.8))),
          ]),
        ],

        const SizedBox(height: 18),

        Text("DESCRIPTION",
            style: TextStyle(
              fontSize: 9,
              color: AppTheme.textSecondary,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 10),
        _premiumTextField(
            ctrl: _descCtrl,
            hint: "Describe the issue clearly...",
            icon: Icons.notes_rounded,
            maxLines: 3),
        const SizedBox(height: 28),

        GestureDetector(
          onTap: _submitting ? null : _submit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 58,
            decoration: BoxDecoration(
              gradient:
              _submitting ? null : AppTheme.accentGradient,
              color: _submitting ? AppTheme.cardBorder : null,
              borderRadius: BorderRadius.circular(18),
              boxShadow: _submitting
                  ? []
                  : [
                BoxShadow(
                    color: AppTheme.accent.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Center(
                child: _submitting
                    ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accent))
                    : Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded,
                          color: AppTheme.bg, size: 18),
                      const SizedBox(width: 10),
                      Text("SUBMIT REPORT",
                          style: TextStyle(
                            color: AppTheme.bg,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 2,
                          )),
                    ])),
          ),
        ),
      ]),
    );
  }

  Widget _premiumTextField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF080E1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(
            color: AppTheme.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          TextStyle(color: AppTheme.textMuted, fontSize: 13),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(icon, color: AppTheme.accent, size: 18),
          ),
          prefixIconConstraints:
          const BoxConstraints(minWidth: 0, minHeight: 0),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORTS LIST
// ─────────────────────────────────────────────────────────────────────────────
class _ReportsListPage extends StatelessWidget {
  final List<CivilianReport> reports;
  const _ReportsListPage({required this.reports});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inbox_outlined,
                    size: 40, color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            const Text("No Reports Yet",
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text("Switch to Report tab to file an issue",
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ]));
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(children: [
          Text("${reports.length} reports filed",
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.warning.withOpacity(0.2)),
            ),
            child: Text(
                "${reports.where((r) => r.status == 'Pending').length} pending",
                style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
      Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: reports.length,
            itemBuilder: (_, i) =>
                _ReportCard(report: reports[i]),
          )),
    ]);
  }
}

class _ReportCard extends StatelessWidget {
  final CivilianReport report;
  const _ReportCard({required this.report});

  String _fmt(DateTime dt) =>
      "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final sc = statusColor(report.status);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ReportDetailSheet(report: report),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1220),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(17)),
            child: SizedBox(
              width: 75,
              height: 85,
              child: report.image != null
                  ? Image.memory(report.image!, fit: BoxFit.cover)
                  : Container(
                  color: AppTheme.cardBorder.withOpacity(0.3),
                  child: Icon(Icons.image_outlined,
                      color: AppTheme.textMuted, size: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(report.category,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis)),
                        Container(
                          margin: const EdgeInsets.only(right: 14),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: sc.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: sc.withOpacity(0.3)),
                          ),
                          child: Text(report.status,
                              style: TextStyle(
                                color: sc,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              )),
                        ),
                      ]),
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.location_on_rounded,
                            size: 11, color: AppTheme.accent),
                        const SizedBox(width: 3),
                        Expanded(
                            child: Text(report.area,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.accent
                                      .withOpacity(0.8),
                                ),
                                overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 3),
                      Text(report.description,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Text(
                          "${report.id}  •  ${_fmt(report.submittedAt)}",
                          style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.textMuted,
                              letterSpacing: 0.3)),
                    ]),
              )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORT DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _ReportDetailSheet extends StatefulWidget {
  final CivilianReport report;
  const _ReportDetailSheet({required this.report});
  @override
  State<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends State<_ReportDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (_, sc) => SingleChildScrollView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
                child: Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                        color: AppTheme.cardBorder,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.id,
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                                letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Text(r.category,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            )),
                      ]),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF080E1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: DropdownButton<String>(
                      value: r.status,
                      dropdownColor: const Color(0xFF0A1525),
                      underline: const SizedBox(),
                      isDense: true,
                      style: TextStyle(
                          color: statusColor(r.status),
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                      items: ["Pending", "Reviewed", "Resolved"]
                          .map((s) => DropdownMenuItem(
                          value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null)
                          setState(() => r.status = v);
                      },
                    ),
                  ),
                ]),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.location_on_rounded,
                  size: 14, color: AppTheme.accent),
              const SizedBox(width: 5),
              Text(r.area,
                  style: TextStyle(
                      color: AppTheme.accent, fontSize: 13)),
            ]),
            if (r.image != null) ...[
              const SizedBox(height: 18),
              ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(r.image!,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover)),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF070C18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("DESCRIPTION",
                        style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.textMuted,
                            letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text(r.description,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          height: 1.6,
                        )),
                  ]),
            ),
            const SizedBox(height: 12),
            Text(
              "Filed: ${r.submittedAt.day}/${r.submittedAt.month}/${r.submittedAt.year} at "
                  "${r.submittedAt.hour.toString().padLeft(2, '0')}:${r.submittedAt.minute.toString().padLeft(2, '0')}",
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CITY MAP PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class CityMapPainter extends CustomPainter {
  final double pulse;
  CityMapPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.2, -0.3),
            radius: 1.2,
            colors: const [
              Color(0xFF0D1830),
              Color(0xFF060A14),
              Color(0xFF04060F)
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, w, h)));

    final gridP = Paint()
      ..color = AppTheme.accent.withOpacity(0.04)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 16; i++) {
      canvas.drawLine(
          Offset(w * i / 16, 0), Offset(w * i / 16, h), gridP);
      canvas.drawLine(
          Offset(0, h * i / 16), Offset(w, h * i / 16), gridP);
    }

    final road1 = Paint()
      ..color = AppTheme.accent.withOpacity(0.12)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final road2 = Paint()
      ..color = AppTheme.accent.withOpacity(0.07)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * .05, h * .5), Offset(w * .95, h * .5), road1);
    canvas.drawLine(
        Offset(w * .5, h * .05), Offset(w * .5, h * .95), road1);
    canvas.drawLine(
        Offset(w * .15, h * .2), Offset(w * .85, h * .8), road2);
    canvas.drawLine(
        Offset(w * .15, h * .8), Offset(w * .85, h * .2), road2);
    canvas.drawLine(
        Offset(w * .3, h * .05), Offset(w * .3, h * .95), road2);
    canvas.drawLine(
        Offset(w * .7, h * .05), Offset(w * .7, h * .95), road2);
    canvas.drawLine(
        Offset(w * .05, h * .3), Offset(w * .95, h * .3), road2);
    canvas.drawLine(
        Offset(w * .05, h * .7), Offset(w * .95, h * .7), road2);

    final wr = Rect.fromCenter(
        center: Offset(w * .75, h * .65),
        width: w * .24,
        height: h * .13);
    canvas.drawOval(
        wr,
        Paint()
          ..color = const Color(0xFF0A2040).withOpacity(0.7));
    canvas.drawOval(
        wr,
        Paint()
          ..color = const Color(0xFF0066AA).withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    for (final a in kAlerts) {
      final cx = w * a.x;
      final cy = h * a.y;
      final c = levelColor(a.level);
      canvas.drawCircle(
          Offset(cx, cy),
          35,
          Paint()
            ..color = c.withOpacity(0.08)
            ..maskFilter =
            const MaskFilter.blur(BlurStyle.normal, 20));
      canvas.drawCircle(
          Offset(cx, cy),
          10 + pulse * 10,
          Paint()
            ..color = c.withOpacity(0.25 + pulse * 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      canvas.drawCircle(
          Offset(cx, cy),
          5 + pulse * 5,
          Paint()
            ..color = c.withOpacity(0.15 + pulse * 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      canvas.drawCircle(
          Offset(cx, cy), 5, Paint()..color = c.withOpacity(0.9));
      canvas.drawCircle(Offset(cx, cy), 3,
          Paint()..color = Colors.white.withOpacity(0.8));
    }

    final tp = TextPainter(
      text: TextSpan(
        text: "BENGALURU METRO  •  12.9716°N  77.5946°E",
        style: TextStyle(
            color: AppTheme.accent.withOpacity(0.2),
            fontSize: 9,
            letterSpacing: 2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, h - 18));
  }

  @override
  bool shouldRepaint(CityMapPainter old) => old.pulse != pulse;
}