import 'dart:async';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DashboardController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  RxInt selectedIndex = 0.obs;
  void setSelectedIndex(int index) {
    selectedIndex.value = index;
    update();
  }

  // ================= STATE =================
  final RxList<Map<String, dynamic>> incidents = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> incidentTypes = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> teams = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> steps = <Map<String, dynamic>>[].obs;

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  final Rx<Map<String, dynamic>?> selectedIncident = Rx<Map<String, dynamic>?>(null);
  final RxString selectedFilter = 'الكل'.obs;
  final RxInt activeIncidents = 0.obs;
  final RxInt criticalIncidents = 0.obs;
  final RxInt resolvedToday = 0.obs;

  // Cache للحوادث لمنع التكرار
  final Map<String, Map<String, dynamic>> _incidentCache = {};

  // ================= STREAMS =================
  StreamSubscription<QuerySnapshot>? incidentsSub;
  StreamSubscription<QuerySnapshot>? _incidentTypesSub;
  StreamSubscription<QuerySnapshot>? _teamsSub;
  StreamSubscription<QuerySnapshot>? _stepsSub;
  StreamSubscription<DocumentSnapshot>? _selectedIncidentSub;

  bool _teamReleased = false;
  bool _isFirstLoad = true;

  // ================= SOUND URLS =================
  static const String defaultSound = 'https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg';
  static const String resolvedSound = 'https://actions.google.com/sounds/v1/alarms/digital_watch_alarm_long.ogg';

  // ================= LIFECYCLE =================
  @override
  void onInit() {
    super.onInit();
    _requestNotificationPermission();
    _setupStreams();

    ever<Map<String, dynamic>?>(selectedIncident, (incident) {
      final id = incident?['id'];
      if (id != null) {
        _teamReleased = false;
        _listenToSelectedIncident(id);
      }
    });
  }

  @override
  void onClose() {
    incidentsSub?.cancel();
    _incidentTypesSub?.cancel();
    _teamsSub?.cancel();
    _stepsSub?.cancel();
    _selectedIncidentSub?.cancel();
    super.onClose();
  }

  // ================= NOTIFICATION PERMISSION =================
  Future<void> _requestNotificationPermission() async {
    if (html.Notification.supported) {
      if (html.Notification.permission == 'default') {
        await html.Notification.requestPermission();
      }
    }
  }

  // ================= SHOW NOTIFICATION =================
  void _showNotification(String title, String body, String severity, {String? soundUrl}) {
    if (!html.Notification.supported) return;
    if (html.Notification.permission != 'granted') return;

    // Web notification
    final notification = html.Notification(
      title,
      body: body,
      icon: _getNotificationIcon(severity),
      tag: 'incident-notification',
    );
    Timer(const Duration(seconds: 6), () => notification.close());

    // Play sound
    final audio = html.AudioElement()
      ..src = soundUrl ?? defaultSound
      ..autoplay = true;
  }

  String _getNotificationIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'حرجة':
        return 'https://cdn-icons-png.flaticon.com/512/3524/3524335.png';
      case 'high':
      case 'عالية':
        return 'https://cdn-icons-png.flaticon.com/512/3524/3524388.png';
      case 'medium':
      case 'متوسطة':
        return 'https://cdn-icons-png.flaticon.com/512/3524/3524386.png';
      default:
        return 'https://cdn-icons-png.flaticon.com/512/3524/3524387.png';
    }
  }

  // ================= MAIN STREAMS =================
  void _setupStreams() {
    // 🔹 الحوادث
    incidentsSub = _db.collection('incidents').snapshots().listen(
      (snapshot) {
        final loaded = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'typeId': data['typeId'],
            'typeName': data['typeName'],
            'status': data['status'],
            'severity': data['severity'],
            'address': data['address'],
            'description': data['description'],
            'location': data['location'],
            'team': data['team'],
            'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
            'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate(),
          };
        }).toList();

        // Notification Logic
        for (final incident in loaded) {
          final id = incident['id'];
          final old = _incidentCache[id];

          if (old == null && !_isFirstLoad) {
            // 🆕 حادثة جديدة
            _showNotification(
              '🚨 حادثة جديدة',
              incident['typeName'] ?? 'حادثة',
              incident['severity'] ?? 'low',
            );
          }

          if (old != null && old['status'] != incident['status']) {
            // حالة تم حلها → صوت خاص
            if (incident['status'] == 'تم حلها') {
              _showNotification(
                '✅ حادثة تم حلها',
                'الحالة: تم حلها',
                incident['severity'] ?? 'low',
                soundUrl: resolvedSound,
              );
            } else {
              // تحديث حالة عادية
              _showNotification(
                '🔄 تحديث حالة حادثة',
                'الحالة: ${incident['status']}',
                incident['severity'] ?? 'low',
              );
            }
          }

          if (old != null && old['severity'] != incident['severity']) {
            // تغيير خطورة
            _showNotification(
              '⚠️ تغيير درجة الخطورة',
              'الخطورة: ${incident['severity']}',
              incident['severity'],
            );
          }

          _incidentCache[id] = Map<String, dynamic>.from(incident);
        }

        incidents.assignAll(loaded);
        _calculateStats();

        if (_isFirstLoad) _isFirstLoad = false;
        isLoading.value = false;
      },
      onError: (e) {
        errorMessage.value = 'خطأ في تحميل الحوادث: $e';
        isLoading.value = false;
      },
    );

    // 🔹 أنواع الحوادث
    _incidentTypesSub = _db.collection('incident_types').snapshots().listen((snapshot) {
      incidentTypes.assignAll(
        snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'],
            'defaultSeverity': data['defaultSeverity'],
            'steps': data['steps'] ?? [],
          };
        }).toList(),
      );
    });

    // 🔹 الفرق
    _teamsSub = _db.collection('teams').snapshots().listen((snapshot) {
      teams.assignAll(
        snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'],
            'branch': data['branch'],
            'isAvailable': data['isAvailable'] ?? true,
            'location': data['location'],
          };
        }).toList(),
      );
    });

    // 🔹 كل الخطوات
    _stepsSub = _db.collection('incident_steps').snapshots().listen((snapshot) {
      steps.assignAll(
        snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'incidentId': data['incidentId'],
            'title': data['title'],
            'order': data['order'],
            'status': data['status'],
          };
        }).toList(),
      );
    });
  }

  // ================= SELECTED INCIDENT =================
  void _listenToSelectedIncident(String incidentId) {
    _selectedIncidentSub?.cancel();

    _selectedIncidentSub = _db.collection('incidents').doc(incidentId).snapshots().listen((doc) async {
      if (!doc.exists) return;

      final data = doc.data()!;
      final status = data['status'];
      final team = data['team'];

      selectedIncident.value = {
        'id': doc.id,
        'typeId': data['typeId'],
        'typeName': data['typeName'],
        'status': status,
        'severity': data['severity'],
        'description': data['description'],
        'location': data['location'],
        'address': data['address'],
        'team': team,
        'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
        'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate(),
      };

      if ((status.toLowerCase() == 'resolved' || status == 'تم حلها') && !_teamReleased) {
        _teamReleased = true;
        await _releaseTeamFromIncident(team);
      }
    });
  }

  // ================= TEAM RELEASE =================
  Future<void> _releaseTeamFromIncident(Map<String, dynamic>? team) async {
    if (team == null) return;

    final String? teamId = team['id'];
    if (teamId == null) return;

    final teamRef = _db.collection('teams').doc(teamId);
    final snap = await teamRef.get();

    if (!snap.exists) return;

    final isAvailable = snap['isAvailable'] ?? true;
    if (!isAvailable) {
      await teamRef.update({'isAvailable': true});
    }
  }

  // ================= UPDATE INCIDENT =================
  Future<void> updateIncidentStatusAndSeverity({required String status, required String severity}) async {
    final incident = selectedIncident.value;
    if (incident == null) return;

    final incidentId = incident['id'];

    final incidentRef = _db.collection('incidents').doc(incidentId);

    await incidentRef.update({
      'status': status.toLowerCase(),
      'severity': severity.toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (status.toLowerCase() == 'resolved' || status == 'تم حلها') {
      await _markAllStepsCompleted(incidentId);
    }
  }

  Future<void> _markAllStepsCompleted(String incidentId) async {
    final query = await _db.collection('incident_steps').where('incidentId', isEqualTo: incidentId).get();
    if (query.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'status': true});
    }
    await batch.commit();
  }

  // ================= LOGIC =================
  void _calculateStats() {
    activeIncidents.value = incidents.where((i) => i['status'] != 'Resolved' && i['status'] != 'تم حلها').length;
    criticalIncidents.value = incidents.where((i) => (i['severity'] as String).toLowerCase() == 'critical' || (i['severity'] as String).toLowerCase() == 'حرجة').length;

    final now = DateTime.now();
    resolvedToday.value = incidents.where((i) {
      final dt = i['updatedAt'] as DateTime?;
      return (i['status'] == 'Resolved' || i['status'] == 'تم حلها') && dt != null && dt.day == now.day && dt.month == now.month && dt.year == now.year;
    }).length;
  }

  List<Map<String, dynamic>> get filteredIncidents {
    if (selectedFilter.value == 'الكل') return incidents;
    return incidents.where((i) => i['status'] == selectedFilter.value).toList();
  }

  List<Map<String, dynamic>> getStepsForIncident(String incidentId) {
    return steps.where((s) => s['incidentId'] == incidentId).toList()
      ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
  }

  void selectIncident(Map<String, dynamic> incident) => selectedIncident.value = incident;
  void setFilter(String filter) => selectedFilter.value = filter;

  // ================= UI HELPERS =================
  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'قيد الانتظار':
        return Colors.orange;
      case 'قيد التنفيذ':
        return Colors.blue;
      case 'تم حلها':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'منخفضة':
        return Colors.green;
      case 'medium':
      case 'متوسطة':
        return Colors.orange;
      case 'high':
      case 'عالية':
      case 'critical':
      case 'حرجة':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData getIncidentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
      case 'حريق':
        return Icons.local_fire_department;
      case 'flood':
      case 'فيضان':
        return Icons.water;
      case 'accident':
      case 'حادث':
        return Icons.car_crash;
      case 'medical':
      case 'طبي':
      case 'طبية':
        return Icons.medical_services;
      default:
        return Icons.location_on;
    }
  }

  void refreshData() => isLoading.value = true;
}
