
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

  String? _selectedTypeId;
  String? _selectedTypeName;
  String? _selectedSeverity;
  final _descriptionController = TextEditingController();
  bool _loading = false;

  double? _lat;
  double? _lng;
  DateTime _currentDate = DateTime.now();

  final RxList<Map<String, dynamic>> _incidentTypes = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> _teams = <Map<String, dynamic>>[].obs;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadIncidentTypes();
    _loadTeams();
  }

  // ====== GET CURRENT LOCATION ======
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
    } catch (e) {
      Get.snackbar('Error', 'Could not get location: $e');
    }
  }

  // ====== LOAD INCIDENT TYPES ======
  Future<void> _loadIncidentTypes() async {
    final snapshot = await _db.collection('incident_types').get();
    _incidentTypes.assignAll(snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'],
        'defaultSeverity': data['defaultSeverity'],
        'steps': data['steps'],
      };
    }).toList());

    if (_incidentTypes.isNotEmpty) {
      setState(() {
        _selectedTypeId = _incidentTypes.first['id'];
        _selectedTypeName = _incidentTypes.first['name'];
        _selectedSeverity = _incidentTypes.first['defaultSeverity'];
      });
    }
  }

  // ====== LOAD TEAMS ======
  Future<void> _loadTeams() async {
    final snapshot = await _db.collection('teams').where('isAvailable', isEqualTo: true).get();
    _teams.assignAll(snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'],
        'branch': data['branch'],
        'lat': data['location']['lat'],
        'lng': data['location']['lng'],
      };
    }).toList());
  }

  // ====== FIND NEAREST TEAM ======
  Map<String, dynamic>? _findNearestTeam() {
    if (_lat == null || _lng == null || _teams.isEmpty) return null;

    double? minDistance;
    Map<String, dynamic>? nearestTeam;

    for (var team in _teams) {
      final teamLat = team['lat'] as double;
      final teamLng = team['lng'] as double;
      final distance = Geolocator.distanceBetween(_lat!, _lng!, teamLat, teamLng);

      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
        nearestTeam = team;
      }
    }
    return nearestTeam;
  }

  // ====== SUBMIT INCIDENT ======
  Future<void> _submit() async {
    if (_selectedTypeId == null || _lat == null || _lng == null) {
      Get.snackbar('Error', 'Please select type and allow location');
      return;
    }

    setState(() => _loading = true);

    try {
      // 1️⃣ Find nearest team
      final nearestTeam = _findNearestTeam();

      // 2️⃣ Add Incident
      final incidentRef = await _db.collection('incidents').add({
        'typeId': _selectedTypeId,
        'typeName': _selectedTypeName,
        'status': 'Pending',
        'severity': _selectedSeverity,
        'description': _descriptionController.text,
        'location': {'lat': _lat, 'lng': _lng},
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

      // 3️⃣ Copy steps from template
      final typeDoc = await _db.collection('incident_types').doc(_selectedTypeId).get();
      final steps = (typeDoc.data()?['steps'] as List<dynamic>? ?? []);

      final stepsCol = _db.collection('incident_steps');
      for (var step in steps) {
        await stepsCol.add({
          'incidentId': incidentRef.id,
          'stepId': step['id'],
          'title': step['title'],
          'order': step['order'],
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      Get.snackbar('Success', 'Incident created successfully');
      _descriptionController.clear();
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Incident')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Incident Type Dropdown
            Obx(
              () => DropdownButtonFormField<String>(
                value: _selectedTypeId,
                decoration: const InputDecoration(labelText: 'Incident Type'),
                items: _incidentTypes.map<DropdownMenuItem<String>>((type) {
                  return DropdownMenuItem<String>(
                    value: type['id'] as String,
                    child: Text(type['name'] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  final type = _incidentTypes.firstWhere((t) => t['id'] == val);
                  setState(() {
                    _selectedTypeId = type['id'] as String;
                    _selectedTypeName = type['name'] as String;
                    _selectedSeverity = type['defaultSeverity'] as String?;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // Location
            Text(
              'Location: ${_lat?.toStringAsFixed(5)}, ${_lng?.toStringAsFixed(5)}',
            ),
            const SizedBox(height: 12),

            // Date
            Text('Date: ${_currentDate.toString()}'),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Create Incident'),
            ),
          ],
        ),
      ),
    );
  }
}
