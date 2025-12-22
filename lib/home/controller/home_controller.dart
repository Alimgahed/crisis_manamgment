// ============================================================================
// DASHBOARD CONTROLLER - FIXED VERSION
// ============================================================================
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class DashboardController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
RxInt selectedIndex = 0.obs;
   void setSelectedIndex(int index) {
    selectedIndex.value = index;
    update();
   }
  
  // Observable state
  final RxList<Map<String, dynamic>> incidents = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final Rx<Map<String, dynamic>?> selectedIncident = Rx<Map<String, dynamic>?>(null);
  final RxString selectedFilter = 'All'.obs;
  final RxInt activeIncidents = 0.obs;
  final RxInt criticalIncidents = 0.obs;
  final RxInt resolvedToday = 0.obs;

  StreamSubscription<QuerySnapshot>? _incidentsSubscription;

  @override
  void onInit() {
    super.onInit();
    _setupIncidentsStream();
  }

  @override
  void onClose() {
    _incidentsSubscription?.cancel();
    super.onClose();
  }

  void _setupIncidentsStream() {
    _incidentsSubscription = _db.collection('incidents').snapshots().listen(
      (snapshot) {
        final List<Map<String, dynamic>> loadedIncidents = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'lat': (data['location']?['lat'] as num?)?.toDouble() ?? 0.0,
            'lng': (data['location']?['lng'] as num?)?.toDouble() ?? 0.0,
            'type': data['type'] ?? 'Unknown',
            'status': data['status'] ?? 'Pending',
            'description': data['description'] ?? 'No description',
            'createdAt': data['createdAt'] != null
                ? (data['createdAt'] as Timestamp).toDate()
                : null,
            'team_work': _parseTeamWork(data['team_work']),
            'severity': data['severity'] ?? 'medium',
          };
        }).toList();

        // Update incidents list - this triggers UI update
        incidents.assignAll(loadedIncidents);
        
        // Recalculate stats
        _calculateStats();
        
        // Update loading state
        isLoading.value = false;

        // Update selected incident if it exists in new data
        if (selectedIncident.value != null) {
          final updatedIncident = loadedIncidents.firstWhereOrNull(
            (i) => i['id'] == selectedIncident.value!['id']
          );
          if (updatedIncident != null) {
            selectedIncident.value = updatedIncident;
          } else if (loadedIncidents.isNotEmpty) {
            selectedIncident.value = loadedIncidents.first;
          }
        } else if (loadedIncidents.isNotEmpty) {
          selectedIncident.value = loadedIncidents.first;
        }

        // Force UI refresh
        update();
      },
      onError: (e) {
        errorMessage.value = 'Error loading incidents: $e';
        isLoading.value = false;
        update();
      },
    );
  }

  Map<String, dynamic>? _parseTeamWork(dynamic teamWorkData) {
    if (teamWorkData == null) return null;
    if (teamWorkData is Map) {
      return {
        'user_name': teamWorkData['user_name'] ?? 'Unknown',
        'missions': teamWorkData['missions'] ?? [],
      };
    }
    return null;
  }

  void _calculateStats() {
    activeIncidents.value = incidents.where((i) => 
      i['status'] != 'Resolved' && i['status'] != 'Closed'
    ).length;
    
    criticalIncidents.value = incidents.where((i) => 
      i['severity'] == 'critical' || i['status'] == 'Critical'
    ).length;
    
    final now = DateTime.now();
    resolvedToday.value = incidents.where((i) {
      final createdAt = i['createdAt'] as DateTime?;
      return i['status'] == 'Resolved' && 
             createdAt != null && 
             createdAt.day == now.day &&
             createdAt.month == now.month &&
             createdAt.year == now.year;
    }).length;
  }

  List<Map<String, dynamic>> get filteredIncidents {
    if (selectedFilter.value == 'All') return incidents;
    return incidents.where((i) => 
      i['status'] == selectedFilter.value
    ).toList();
  }

  void selectIncident(Map<String, dynamic> incident) {
    selectedIncident.value = incident;
    update();
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
    update();
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData getIncidentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department;
      case 'flood':
        return Icons.water;
      case 'accident':
        return Icons.car_crash;
      case 'medical':
        return Icons.medical_services;
      case 'crime':
        return Icons.warning;
      default:
        return Icons.location_on;
    }
  }
  Color getSeverityColor(String severity) {
  switch (severity.toLowerCase()) {
    case 'high':
    case 'critical':
      return Colors.red;

    case 'medium':
      return Colors.orange;

    case 'low':
      return Colors.green;

    default:
      return Colors.grey;
  }
}


  // Manual refresh method
  void refreshData() {
    isLoading.value = true;
    update();
  }
}