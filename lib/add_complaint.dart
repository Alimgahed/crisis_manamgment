import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

class AddIncidentScreen extends StatefulWidget {
  const AddIncidentScreen({Key? key}) : super(key: key);

  @override
  State<AddIncidentScreen> createState() => _AddIncidentScreenState();
}

class _AddIncidentScreenState extends State<AddIncidentScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Controllers
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  // State Variables
  String? _selectedTypeId;
  String? _selectedTypeName;
  String? _selectedSeverity; // always Arabic
  bool _loading = false;
  double? _lat;
  double? _lng;

  final RxList<Map<String, dynamic>> _incidentTypes =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> _teams = <Map<String, dynamic>>[].obs;

  // Professional Blue Palette
  final Color primaryBlue = const Color(0xFF1565C0);
  final Color accentBlue = const Color(0xFFE3F2FD);
  final Color successGreen = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _loadIncidentTypes();
    _loadTeams();
  }

  // ====== GET CURRENT LOCATION ======
  Future<void> _handleLocation() async {
    setState(() => _loading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });

      Get.snackbar(
        'نجاح',
        'تم تحديد إحداثيات موقعك الحالي بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: successGreen,
        colorText: Colors.white,
        margin: const EdgeInsets.all(15),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر الوصول إلى الموقع الجغرافي');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ====== DATA LOADING ======
  Future<void> _loadIncidentTypes() async {
    final snapshot = await _db.collection('incident_types').get();
    _incidentTypes.assignAll(
      snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'defaultSeverity': data['defaultSeverity'], // low/medium/high
          'steps': data['steps'],
        };
      }).toList(),
    );

    if (_incidentTypes.isNotEmpty) {
      setState(() {
        _selectedTypeId = _incidentTypes.first['id'];
        _selectedTypeName = _incidentTypes.first['name'];
        // convert English default to Arabic
        final defaultSeverity = _incidentTypes.first['defaultSeverity'];
        _selectedSeverity = defaultSeverity == 'medium'
            ? 'متوسطة'
            : defaultSeverity == 'high'
                ? 'عالية'
                : 'منخفضة';
      });
    }
  }

  Future<void> _loadTeams() async {
    final snapshot = await _db
        .collection('teams')
        .where('isAvailable', isEqualTo: true)
        .get();
    _teams.assignAll(
      snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'branch': data['branch'],
          'lat': data['location']['lat'],
          'lng': data['location']['lng'],
        };
      }).toList(),
    );
  }

  Map<String, dynamic>? _findNearestTeam() {
    if (_lat == null || _lng == null || _teams.isEmpty) return null;
    double? minDistance;
    Map<String, dynamic>? nearestTeam;

    for (var team in _teams) {
      final teamLat = team['lat'] as double;
      final teamLng = team['lng'] as double;
      final distance = Geolocator.distanceBetween(
        _lat!,
        _lng!,
        teamLat,
        teamLng,
      );

      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
        nearestTeam = team;
      }
    }
    return nearestTeam;
  }

  // ====== SUBMIT INCIDENT & UPDATE TEAM STATUS ======
  Future<void> _submit() async {
    if (_selectedTypeId == null) {
      Get.snackbar('تنبيه', 'يرجى اختيار نوع الأزمة أولاً');
      return;
    }

    setState(() => _loading = true);
    try {
      final nearestTeam = _findNearestTeam();

      // Save severity directly in Arabic
      final severityToSave = _selectedSeverity ?? 'منخفضة';

      // 1. Add Incident Document
      final incidentRef = await _db.collection('incidents').add({
        'typeId': _selectedTypeId,
        'typeName': _selectedTypeName,
        'status': 'قيد الانتظار',
        'severity': severityToSave,
        'address': _addressController.text,
        'description': _descriptionController.text,
        'location': _lat != null ? {'lat': _lat, 'lng': _lng} : null,
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

      // 2. Mark assigned team as Unavailable
      if (nearestTeam != null) {
        await _db.collection('teams').doc(nearestTeam['id']).update({
          'isAvailable': false,
        });
      }

      // 3. Create Mission Steps
      final typeDoc = await _db
          .collection('incident_types')
          .doc(_selectedTypeId)
          .get();
      final steps = (typeDoc.data()?['steps'] as List<dynamic>? ?? []);

      WriteBatch batch = _db.batch();
      for (var step in steps) {
        DocumentReference stepRef = _db.collection('incident_steps').doc();
        batch.set(stepRef, {
          'incidentId': incidentRef.id,
          'stepId': step['id'],
          'title': step['title'],
          'order': step['order'],
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      Get.back();
      Get.snackbar(
        'تم البلاغ',
        nearestTeam != null
            ? 'تم توجيه فريق ${nearestTeam['name']} إلى موقع الأزمة'
            : 'تم تسجيل الأزمة بنجاح (لا يوجد فريق متاح حالياً)',
        backgroundColor: primaryBlue,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ غير متوقع: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'تبليغ عن أزمة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: primaryBlue,
          elevation: 0,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentBlue,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: primaryBlue),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'سيتم تحديد أقرب فريق متاح تلقائياً بناءً على موقعك الجغرافي.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // Incident Type Dropdown
              _sectionTitle("نوع الأزمة"),
              Obx(
                () => DropdownButtonFormField<String>(
                  value: _selectedTypeId,
                  icon: Icon(Icons.keyboard_arrow_down, color: primaryBlue),
                  decoration: _inputDecoration(Icons.category_outlined),
                  items: _incidentTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type['id'] as String,
                          child: Text(type['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final type = _incidentTypes.firstWhere(
                      (t) => t['id'] == val,
                    );
                    setState(() {
                      _selectedTypeId = type['id'];
                      _selectedTypeName = type['name'];
                      _selectedSeverity = type['defaultSeverity'] == 'medium'
                          ? 'متوسطة'
                          : type['defaultSeverity'] == 'high'
                              ? 'عالية'
                              : 'منخفضة';
                    });
                  },
                ),
              ),
              const SizedBox(height: 15),

              // Severity Dropdown in Arabic
              _sectionTitle("شدة الأزمة"),
              DropdownButtonFormField<String>(
                value: _selectedSeverity,
                icon: Icon(Icons.keyboard_arrow_down, color: primaryBlue),
                decoration: _inputDecoration(Icons.warning_amber_outlined),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'منخفضة',
                    child: Text('منخفضة'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'متوسطة',
                    child: Text('متوسطة'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'عالية',
                    child: Text('عالية'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSeverity = val);
                },
              ),
              const SizedBox(height: 20),

              // Description
              _sectionTitle("وصف الأزمة"),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: _inputDecoration(
                  Icons.edit_note,
                  hint: "يرجى تقديم وصف موجز للموقف...",
                ),
              ),
              const SizedBox(height: 25),

              // Location
              _sectionTitle("الموقع الجغرافي"),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          hintText: "أدخل العنوان يدوياً (اختياري)",
                          prefixIcon: Icon(Icons.map_outlined),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        _lat != null
                            ? Icons.location_on
                            : Icons.location_off_outlined,
                        color: _lat != null ? successGreen : Colors.grey,
                      ),
                      title: Text(
                        _lat == null
                            ? "تحديد الموقع الحالي"
                            : "تم تحديد الإحداثيات",
                        style: TextStyle(
                          color: _lat != null ? successGreen : Colors.black87,
                          fontWeight: _lat != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: _lat != null
                          ? Text(
                              "${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}",
                            )
                          : null,
                      trailing: TextButton.icon(
                        onPressed: _handleLocation,
                        icon: const Icon(Icons.gps_fixed, size: 18),
                        label: const Text("تحديث"),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "إرسال البلاغ الآن",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== Styling Helpers ======
  InputDecoration _inputDecoration(IconData icon, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryBlue),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryBlue, width: 2),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey[700],
        ),
      ),
    );
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

