import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

class AddIncidentScreen extends StatefulWidget {
  const AddIncidentScreen({Key? key}) : super(key: key);

  @override
  State<AddIncidentScreen> createState() => _AddIncidentScreenState();
}

class _AddIncidentScreenState extends State<AddIncidentScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MapController _mapController = MapController();

  // Controllers
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  // State Variables
  String? _selectedTypeId;
  String? _selectedTypeName;
  String? _selectedSeverity = 'متوسطة';
  bool _loading = false;

  // Default Location (Minya, Egypt)
  LatLng _selectedLocation = const LatLng(28.1091, 30.7503);

  final RxList<Map<String, dynamic>> _incidentTypes =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> _teams = <Map<String, dynamic>>[].obs;

  // Professional Color Scheme
  final Color primaryColor = const Color(0xFF1565C0);
  final Color secondaryColor = const Color(0xFF0D47A1);
  final Color accentColor = const Color(0xFF42A5F5);
  final Color surfaceColor = const Color(0xFFF8F9FA);
  final Color cardColor = Colors.white;
  final Color successColor = const Color(0xFF2E7D32);
  final Color warningColor = const Color(0xFFED6C02);
  final Color errorColor = const Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    await _loadIncidentTypes();
    await _loadTeams();
    await _getCurrentLocation();
    setState(() => _loading = false);
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar(
          'تنبيه',
          'خدمة الموقع غير مفعلة',
          backgroundColor: warningColor,
          colorText: Colors.white,
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar(
            'تنبيه',
            'تم رفض إذن الموقع',
            backgroundColor: warningColor,
            colorText: Colors.white,
          );
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_selectedLocation, 15.0);
    } catch (e) {
      debugPrint("Location error: $e");
      Get.snackbar(
        'خطأ',
        'فشل في الحصول على الموقع',
        backgroundColor: errorColor,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _loadIncidentTypes() async {
    try {
      final snapshot = await _db.collection('incident_types').get();
      _incidentTypes.assignAll(
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
      );
      if (_incidentTypes.isNotEmpty) {
        setState(() {
          _selectedTypeId = _incidentTypes.first['id'];
          _selectedTypeName = _incidentTypes.first['name'];
        });
      }
    } catch (e) {
      debugPrint("Error loading incident types: $e");
    }
  }

  Future<void> _loadTeams() async {
    try {
      final snapshot = await _db
          .collection('teams')
          .where('isAvailable', isEqualTo: true)
          .get();
      _teams.assignAll(
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
      );
    } catch (e) {
      debugPrint("Error loading teams: $e");
    }
  }

  Map<String, dynamic>? _findNearestTeam() {
    if (_teams.isEmpty) return null;
    double? minDistance;
    Map<String, dynamic>? nearestTeam;

    for (var team in _teams) {
      final distance = Geolocator.distanceBetween(
        _selectedLocation.latitude,
        _selectedLocation.longitude,
        team['location']['lat'],
        team['location']['lng'],
      );
      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
        nearestTeam = team;
      }
    }
    return nearestTeam;
  }

  Future<void> _submitIncident() async {
    if (_descriptionController.text.trim().isEmpty) {
      Get.snackbar(
        'تنبيه',
        'يرجى كتابة وصف للأزمة',
        backgroundColor: warningColor,
        colorText: Colors.white,
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final nearestTeam = _findNearestTeam();

      // 1. Create incident document
      final incidentRef = await _db.collection('incidents').add({
        'typeId': _selectedTypeId,
        'typeName': _selectedTypeName,
        'status': 'قيد الانتظار',
        'severity': _selectedSeverity,
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': {
          'lat': _selectedLocation.latitude,
          'lng': _selectedLocation.longitude,
        },
        'team': nearestTeam != null
            ? {
                'id': nearestTeam['id'],
                'name': nearestTeam['name'],
                'branch': nearestTeam['branch'],
              }
            : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update team availability
      if (nearestTeam != null) {
        await _db.collection('teams').doc(nearestTeam['id']).update({
          'isAvailable': false,
          'currentIncidentId': incidentRef.id,
        });
      }

      // 3. Add incident steps
      final currentType = _incidentTypes.firstWhere(
        (t) => t['id'] == _selectedTypeId,
      );
      final stepsData = (currentType['steps'] as List<dynamic>? ?? []);

      if (stepsData.isNotEmpty) {
        WriteBatch batch = _db.batch();
        for (var step in stepsData) {
          DocumentReference stepRef = _db.collection('incident_steps').doc();
          batch.set(stepRef, {
            'incidentId': incidentRef.id,
            'stepId': step['id'] ?? '',
            'title': step['title'] ?? 'خطوة غير محددة',
            'order': step['order'] ?? 0,
            'status': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      Get.back();
      Get.snackbar(
        'نجاح',
        'تم تسجيل البلاغ بنجاح وتوجيه الفريق المتاح',
        backgroundColor: successColor,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في إرسال البلاغ: $e',
        backgroundColor: errorColor,
        colorText: Colors.white,
        icon: const Icon(Icons.error_outline, color: Colors.white),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isWeb = MediaQuery.of(context).size.width > 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: surfaceColor,
        appBar: _buildAppBar(),
        body: _loading && _incidentTypes.isEmpty
            ? _buildLoadingScreen()
            : Center(
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: _buildWebLayout(),
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.add_alert, size: 28),
          SizedBox(width: 12),
          Text(
            'إضافة بلاغ جديد',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ],
      ),
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      toolbarHeight: 70,
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor),
          const SizedBox(height: 20),
          Text(
            'جاري التحميل...',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildWebLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildMapCard()),
        const SizedBox(width: 32),
        _buildFormCard(),
      ],
    );
  }

  Widget _buildMapCard() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "موقع الأزمة",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "انقر على الخريطة لتحديد الموقع بدقة",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _getCurrentLocation,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.my_location,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedLocation,
                  initialZoom: 13.0,
                  onTap: (tapPos, point) =>
                      setState(() => _selectedLocation = point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation,
                        width: 60,
                        height: 60,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: errorColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Icon(
                              Icons.location_on,
                              color: errorColor,
                              size: 50,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('تفاصيل البلاغ', Icons.info_outline),
          const SizedBox(height: 24),

          _buildLabel("نوع الأزمة"),
          const SizedBox(height: 8),
          Obx(
            () => _buildDropdown(
              value: _selectedTypeId,
              icon: Icons.category_outlined,
              items: _incidentTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t['id'] as String,
                      child: Text(
                        t['name'],
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                final type = _incidentTypes.firstWhere(
                  (element) => element['id'] == val,
                );
                setState(() {
                  _selectedTypeId = val;
                  _selectedTypeName = type['name'];
                });
              },
            ),
          ),

          const SizedBox(height: 24),
          _buildLabel("مستوى الخطورة"),
          const SizedBox(height: 8),
          _buildDropdown(
            value: _selectedSeverity,
            icon: Icons.priority_high_outlined,
            items: ['منخفضة', 'متوسطة', 'عالية', 'حرجة']
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        _getSeverityIcon(s),
                        const SizedBox(width: 8),
                        Text(s, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedSeverity = val),
          ),

          const SizedBox(height: 24),
          _buildLabel("العنوان (اختياري)"),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _addressController,
            icon: Icons.location_city_outlined,
            hint: "مثال: شارع الجمهورية، المنيا",
            maxLines: 1,
          ),

          const SizedBox(height: 24),
          _buildLabel("وصف تفصيلي للموقف"),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _descriptionController,
            icon: Icons.description_outlined,
            hint: "اشرح الحالة بالتفصيل هنا...",
            maxLines: 5,
          ),

          const SizedBox(height: 32),
          _buildSubmitButton(),

          const SizedBox(height: 16),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: primaryColor, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        items: items,
        onChanged: onChanged,
        dropdownColor: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required int maxLines,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 12 : 0),
            child: Icon(icon, color: primaryColor, size: 22),
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          shadowColor: primaryColor.withOpacity(0.3),
        ),
        onPressed: _loading ? null : _submitIncident,
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(width: 12),
                  Text(
                    "إرسال البلاغ فوراً",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'سيتم توجيه أقرب فريق متاح تلقائياً',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getSeverityIcon(String severity) {
    Color color;
    IconData icon;

    switch (severity) {
      case 'منخفضة':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case 'متوسطة':
        color = Colors.orange;
        icon = Icons.warning_amber_outlined;
        break;
      case 'عالية':
        color = Colors.deepOrange;
        icon = Icons.error_outline;
        break;
      case 'حرجة':
        color = Colors.red;
        icon = Icons.dangerous_outlined;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Icon(icon, color: color, size: 20);
  }
}

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';

// class FirestoreSeedScreen extends StatelessWidget {
//   const FirestoreSeedScreen({super.key});

//   static final FirebaseFirestore _db = FirebaseFirestore.instance;

//   /// MAIN SEED
//   Future<void> _seedAll(BuildContext context) async {
//     try {
//       // 1️⃣ Seed Templates
//       await _seedIncidentTypes();
//       await _seedTeams();

//       // 2️⃣ Seed Current Incidents (Empty for now)
//       await _createCurrentIncidents();

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('✅ تم تعبئة Firestore بنجاح')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('❌ خطأ: $e')),
//       );
//     }
//   }

//   // ================= INCIDENT TYPES =================
//   static Future<void> _seedIncidentTypes() async {
//     final col = _db.collection('incident_types');

//     await col.doc('pipe_break').set({
//       'name': 'كسر ماسورة',
//       'defaultSeverity': 'حرجة',
//       'steps': [
//         {'id': 's1', 'title': 'إغلاق الصمام الرئيسي', 'order': 1},
//         {'id': 's2', 'title': 'تأمين المنطقة', 'order': 2},
//         {'id': 's3', 'title': 'إصلاح الماسورة', 'order': 3},
//         {'id': 's4', 'title': 'إعادة المياه', 'order': 4},
//       ],
//       'createdAt': FieldValue.serverTimestamp(),
//     });

//     await col.doc('water_cut').set({
//       'name': 'انقطاع المياه',
//       'defaultSeverity': 'متوسطة',
//       'steps': [
//         {'id': 's1', 'title': 'فحص المصدر', 'order': 1},
//         {'id': 's2', 'title': 'إرسال فريق الصيانة', 'order': 2},
//         {'id': 's3', 'title': 'استعادة الخدمة', 'order': 3},
//       ],
//       'createdAt': FieldValue.serverTimestamp(),
//     });

//     await col.doc('clog_network').set({
//       'name': 'انسداد الشبكة',
//       'defaultSeverity': 'متوسطة',
//       'steps': [
//         {'id': 's1', 'title': 'تحديد موقع الانسداد', 'order': 1},
//         {'id': 's2', 'title': 'إرسال فريق التسليك', 'order': 2},
//         {'id': 's3', 'title': 'تنظيف وإعادة التشغيل', 'order': 3},
//       ],
//       'createdAt': FieldValue.serverTimestamp(),
//     });

//     await col.doc('water_pollution').set({
//       'name': 'تلوث المياه',
//       'defaultSeverity': 'حرجة',
//       'steps': [
//         {'id': 's1', 'title': 'إيقاف التوزيع', 'order': 1},
//         {'id': 's2', 'title': 'فحص المصدر', 'order': 2},
//         {'id': 's3', 'title': 'معالجة المياه', 'order': 3},
//         {'id': 's4', 'title': 'إعادة التوزيع', 'order': 4},
//       ],
//       'createdAt': FieldValue.serverTimestamp(),
//     });
//   }

//   // ================= TEAMS =================
//   static Future<void> _seedTeams() async {
//     final col = _db.collection('teams');

//     await col.doc('team_minya_1').set({
//       'name': 'فريق الصيانة 1',
//       'branch': 'المنيا المركز',
//       'isAvailable': true,
//       'location': {'lat': 28.091, 'lng': 30.757},
//       'createdAt': FieldValue.serverTimestamp(),
//     });

//     await col.doc('team_minya_2').set({
//       'name': 'فريق الطوارئ 2',
//       'branch': 'المنيا الجديدة',
//       'isAvailable': true,
//       'location': {'lat': 28.109, 'lng': 30.751},
//       'createdAt': FieldValue.serverTimestamp(),
//     });

//     await col.doc('team_minya_3').set({
//       'name': 'فريق التسليك 3',
//       'branch': 'سمالوط',
//       'isAvailable': true,
//       'location': {'lat': 28.204, 'lng': 30.765},
//       'createdAt': FieldValue.serverTimestamp(),
//     });

//     await col.doc('team_minya_4').set({
//       'name': 'فريق الجودة 4',
//       'branch': 'مغاغة',
//       'isAvailable': true,
//       'location': {'lat': 28.263, 'lng': 30.753},
//       'createdAt': FieldValue.serverTimestamp(),
//     });
//   }

//   // ================= CURRENT INCIDENTS =================
//   static Future<void> _createCurrentIncidents() async {
//     final incidentsCol = _db.collection('incidents');

//     final exampleIncidents = [
//       {
//         'typeId': 'pipe_break',
//         'typeName': 'كسر ماسورة',
//         'status': 'قيد التنفيذ',
//         'severity': 'حرجة',
//         'description': 'كسر ماسورة رئيسية في شارع 1',
//         'teamId': 'team_minya_1',
//       },
//       {
//         'typeId': 'water_cut',
//         'typeName': 'انقطاع المياه',
//         'status': 'قيد الانتظار',
//         'severity': 'متوسطة',
//         'description': 'انقطاع مياه في شارع 2',
//         'teamId': 'team_minya_2',
//       },
//       {
//         'typeId': 'clog_network',
//         'typeName': 'انسداد الشبكة',
//         'status': 'قيد التنفيذ',
//         'severity': 'متوسطة',
//         'description': 'انسداد في شبكة الصرف الصحي',
//         'teamId': 'team_minya_3',
//       },
//       {
//         'typeId': 'water_pollution',
//         'typeName': 'تلوث المياه',
//         'status': 'قيد التنفيذ',
//         'severity': 'حرجة',
//         'description': 'تلوث مياه في حي مغاغة',
//         'teamId': 'team_minya_4',
//       },
//     ];

//     final teamsCol = _db.collection('teams');
//     final stepsCol = _db.collection('incident_steps');

//     for (var incident in exampleIncidents) {
//       final teamDoc = await teamsCol.doc(incident['teamId']).get();
//       final incidentRef = await incidentsCol.add({
//         'typeId': incident['typeId'],
//         'typeName': incident['typeName'],
//         'status': incident['status'],
//         'severity': incident['severity'],
//         'description': incident['description'],
//         'location': teamDoc.data()?['location'] ?? {'lat': 28.091, 'lng': 30.757},
//         'team': teamDoc.data(),
//         'createdAt': FieldValue.serverTimestamp(),
//         'updatedAt': FieldValue.serverTimestamp(),
//       });

//       // Copy steps from template
//       final template = await _db.collection('incident_types').doc(incident['typeId']).get();
//       final steps = (template.data()?['steps'] as List<dynamic>? ?? []);

//       for (var step in steps) {
//         await stepsCol.add({
//           'incidentId': incidentRef.id,
//           'stepId': step['id'],
//           'title': step['title'],
//           'order': step['order'],
//           'status': 'pending',
//           'updatedAt': FieldValue.serverTimestamp(),
//         });
//       }
//     }
//   }

//   // ================= UI =================
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('تعبئة Firestore (الحوادث)')),
//       body: Center(
//         child: ElevatedButton.icon(
//           icon: const Icon(Icons.cloud_upload),
//           label: const Text('تعبئة Firestore بالحوادث'),
//           onPressed: () => _seedAll(context),
//         ),
//       ),
//     );
//   }
// }

