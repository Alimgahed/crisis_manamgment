import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class IncidentsMapScreen extends StatefulWidget {
  const IncidentsMapScreen({super.key});

  @override
  State<IncidentsMapScreen> createState() => _IncidentsMapScreenState();
}

class _IncidentsMapScreenState extends State<IncidentsMapScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _incidents = [];
  Map<String, dynamic>? _selectedIncident;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _setupIncidentsStream();
  }

  void _setupIncidentsStream() {
    _db.collection('incidents').snapshots().listen(
      (snapshot) {
        final incidents = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'lat': (data['location']['lat'] as num).toDouble(),
            'lng': (data['location']['lng'] as num).toDouble(),
            'type': data['type'] ?? 'Unknown',
            'status': data['status'] ?? 'Unknown',
            'description': data['description'] ?? 'No description available',
            'createdAt': data['createdAt'] != null
                ? (data['createdAt'] as Timestamp).toDate()
                : null,
          };
        }).toList();

        if (mounted) {
          setState(() {
            _incidents = incidents;
            _loading = false;
            // Keep selected incident if it still exists, otherwise select first
            if (_selectedIncident != null) {
              final stillExists = incidents.any(
                (incident) => incident['id'] == _selectedIncident!['id'],
              );
              if (!stillExists && incidents.isNotEmpty) {
                _selectedIncident = incidents.first;
              } else if (stillExists) {
                // Update selected incident with new data
                _selectedIncident = incidents.firstWhere(
                  (incident) => incident['id'] == _selectedIncident!['id'],
                );
              }
            } else if (incidents.isNotEmpty) {
              _selectedIncident = incidents.first;
            }
          });

          // Show notification for new incidents
          if (incidents.length > _incidents.length) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.new_releases, color: Colors.white),
                    SizedBox(width: 8),
                    Text('New incident reported!'),
                  ],
                ),
                backgroundColor: Colors.blue.shade700,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading incidents: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  Color _getStatusColor(String status) {
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

  IconData _getIncidentIcon(String type) {
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

  List<Marker> _buildMarkers() {
    return _incidents.map((incident) {
      final isSelected = _selectedIncident?['id'] == incident['id'];
      final color = _getStatusColor(incident['status']);

      return Marker(
        width: isSelected ? 50 : 40,
        height: isSelected ? 50 : 40,
        point: LatLng(incident['lat'], incident['lng']),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedIncident = incident;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              _getIncidentIcon(incident['type']),
              color: color,
              size: isSelected ? 50 : 40,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidents Map'),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Stream will auto-refresh, just show a message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Live updates enabled'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Map Section
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter:
                              LatLng(28.0871, 30.7618), // Minya, Egypt
                          initialZoom: 13,
                          minZoom: 10,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.example.crisisManagement',
                          ),
                          MarkerLayer(markers: _buildMarkers()),
                        ],
                      ),
                      // Incidents count badge
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.report, size: 20, color: Colors.red),
                              const SizedBox(width: 6),
                              Text(
                                '${_incidents.length} Incidents',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Details Section
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: _selectedIncident == null
                        ? const Center(
                            child: Text(
                              'Select an incident on the map',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          _selectedIncident!['status'],
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _getIncidentIcon(
                                          _selectedIncident!['type'],
                                        ),
                                        color: _getStatusColor(
                                          _selectedIncident!['status'],
                                        ),
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedIncident!['type'],
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                _selectedIncident!['status'],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _selectedIncident!['status'],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Description
                                _buildInfoCard(
                                  icon: Icons.description,
                                  title: 'Description',
                                  content: _selectedIncident!['description'],
                                ),
                                const SizedBox(height: 12),
                                // Location
                                _buildInfoCard(
                                  icon: Icons.location_on,
                                  title: 'Location',
                                  content:
                                      'Lat: ${_selectedIncident!['lat'].toStringAsFixed(4)}, Lng: ${_selectedIncident!['lng'].toStringAsFixed(4)}',
                                ),
                                const SizedBox(height: 12),
                                // Date
                                if (_selectedIncident!['createdAt'] != null)
                                  _buildInfoCard(
                                    icon: Icons.access_time,
                                    title: 'Reported At',
                                    content: _formatDateTime(
                                      _selectedIncident!['createdAt'],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}