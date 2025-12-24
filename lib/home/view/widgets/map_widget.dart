// ============================================================================
// ENHANCED MAP SCREEN - Arabic UI with Location Display
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../controller/home_controller.dart';

class IncidentsMapScreen extends StatefulWidget {
  const IncidentsMapScreen({super.key});

  @override
  State<IncidentsMapScreen> createState() => _IncidentsMapScreenState();
}

class _IncidentsMapScreenState extends State<IncidentsMapScreen> {
  final DashboardController controller = Get.find();
  final MapController mapController = MapController();
  String selectedFilter = 'الكل';

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'جاري تحميل الخريطة...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          _buildMapHeader(),
          Expanded(child: _buildMap()),
        ],
      );
    });
  }

  // ============================================================================
  // MAP HEADER
  // ============================================================================
  Widget _buildMapHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map, color: Color(0xFF1E3A5F), size: 28),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'خريطة الأزمات',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  Text(
                    'عرض جميع الأزمات على الخريطة',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              Obx(() => _buildIncidentCounter()),
            ],
          ),
          const SizedBox(height: 12),
          _buildFilterChips(),
        ],
      ),
    );
  }

  Widget _buildIncidentCounter() {
    final filteredIncidents = _getFilteredIncidents();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C5F8D).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C5F8D).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, color: Color(0xFF2C5F8D), size: 20),
          const SizedBox(width: 8),
          Text(
            '${filteredIncidents.length} أزمة',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C5F8D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['الكل', 'حرجة', 'عالية', 'متوسطة', 'منخفضة'];

    return Wrap(
      spacing: 8,
      children: filters.map((filter) {
        final isSelected = selectedFilter == filter;
        return FilterChip(
          label: Text(filter),
          selected: isSelected,
          onSelected: (_) {
            setState(() => selectedFilter = filter);
          },
          backgroundColor: Colors.grey[200],
          selectedColor: const Color(0xFF2C5F8D),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          avatar: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        );
      }).toList(),
    );
  }

  // ============================================================================
  // MAP
  // ============================================================================
  Widget _buildMap() {
    final filteredIncidents = _getFilteredIncidents();
    final markers = _buildMarkers(filteredIncidents);

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: const LatLng(28.0871, 30.7618),
            initialZoom: 12,
            minZoom: 3,
            maxZoom: 18,
            onTap: (_, __) {
              // Close any open dialogs on map tap
              if (Get.isDialogOpen ?? false) {
                Get.back();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.crisis_management',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        _buildMapControls(),
        _buildLegend(),
      ],
    );
  }

  List<Map<String, dynamic>> _getFilteredIncidents() {
    if (selectedFilter == 'الكل') {
      return controller.incidents;
    }

    final severityMap = {
      'حرجة': 'حرجة',
      'عالية': 'عالية',
      'متوسطة': 'متوسطة',
      'منخفضة': 'منخفضة',
    };

    final targetSeverity = severityMap[selectedFilter];
    return controller.incidents
        .where(
          (i) =>
              (i['severity'] ?? '').toString().toLowerCase() == targetSeverity,
        )
        .toList();
  }

  List<Marker> _buildMarkers(List<Map<String, dynamic>> incidents) {
    return incidents
        .map<Marker?>((incident) {
          final location = incident['location'];
          if (location == null) return null;

          final lat = (location['lat'] as num?)?.toDouble();
          final lng = (location['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return null;

          final severity = (incident['severity'] ?? '').toString();
          final status = (incident['status'] ?? '').toString();

          return Marker(
            point: LatLng(lat, lng),
            width: 50,
            height: 50,
            child: GestureDetector(
              onTap: () {
                mapController.move(LatLng(lat, lng), 17);
                controller.selectIncident(incident);
                _showEnhancedIncidentDetails(incident);
              },
              child: _buildMarkerWidget(severity, status),
            ),
          );
        })
        .whereType<Marker>()
        .toList();
  }

  Widget _buildMarkerWidget(String severity, String status) {
    final color = controller.getSeverityColor(severity);
    final isResolved = status == "تم حلها";

    return Stack(
      children: [
        // Pulse animation container
        if (!isResolved)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.3),
            ),
          ),
        // Main marker
        Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.location_on,
              size: 32,
              color: isResolved ? Colors.grey : color,
            ),
          ),
        ),
        // Status indicator
        if (isResolved)
          const Positioned(
            right: 0,
            top: 0,
            child: CircleAvatar(
              radius: 8,
              backgroundColor: Colors.green,
              child: Icon(Icons.check, color: Colors.white, size: 12),
            ),
          ),
      ],
    );
  }

  // ============================================================================
  // MAP CONTROLS
  // ============================================================================
  Widget _buildMapControls() {
    return Positioned(
      left: 16,
      bottom: 16,
      child: Column(
        children: [
          _buildControlButton(
            Icons.add,
            'تكبير',
            () => mapController.move(
              mapController.camera.center,
              mapController.camera.zoom + 1,
            ),
          ),
          const SizedBox(height: 8),
          _buildControlButton(
            Icons.remove,
            'تصغير',
            () => mapController.move(
              mapController.camera.center,
              mapController.camera.zoom - 1,
            ),
          ),
          const SizedBox(height: 8),
          _buildControlButton(
            Icons.my_location,
            'موقعي',
            () => mapController.move(const LatLng(28.0871, 30.7618), 12),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    String tooltip,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: const Color(0xFF2C5F8D)),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // LEGEND
  // ============================================================================
  Widget _buildLegend() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'درجة الخطورة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _buildLegendItem('حرجة', Colors.red),
            _buildLegendItem('عالية', Colors.orange),
            _buildLegendItem('متوسطة', Colors.yellow[700]!),
            _buildLegendItem('منخفضة', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  // ============================================================================
  // ENHANCED INCIDENT DETAILS SIDE PANEL
  // ============================================================================
  void _showEnhancedIncidentDetails(Map<String, dynamic> incident) {
    final incidentId = incident['id'];
    final location = incident['location'];
    final lat = location?['lat'];
    final lng = location?['lng'];

    Get.dialog(
      Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 450,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(-5, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header with close button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'تفاصيل الأزمة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'إغلاق',
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with icon
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: controller
                                    .getStatusColor(incident['status'])
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                controller.getIncidentIcon(
                                  incident['typeName'] ?? 'Unknown',
                                ),
                                color: controller.getStatusColor(
                                  incident['status'],
                                ),
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    incident['typeName'] ?? 'أزمة غير معروفة',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A5F),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: controller.getStatusColor(
                                            incident['status'],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          _getStatusArabic(incident['status']),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: controller
                                              .getSeverityColor(
                                                incident['severity'] ?? 'low',
                                              )
                                              .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: controller.getSeverityColor(
                                              incident['severity'] ?? 'low',
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          _getSeverityArabic(
                                            incident['severity'],
                                          ),
                                          style: TextStyle(
                                            color: controller.getSeverityColor(
                                              incident['severity'] ?? 'low',
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Description
                        _buildDetailSection(
                          'الوصف',
                          Icons.description,
                          incident['description'] ?? 'لا يوجد وصف',
                        ),

                        const SizedBox(height: 16),

                        // Location with map preview
                        if (lat != null && lng != null) ...[
                          _buildLocationSection(lat, lng),
                          const SizedBox(height: 16),
                        ],

                        // Team information
                        if (incident['team'] != null) ...[
                          _buildTeamSection(incident['team']),
                          const SizedBox(height: 16),
                        ],

                        // Steps/Missions
                        _buildStepsSection(incidentId),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: true,
      barrierColor: Colors.black54,
    );
  }

  // ============================================================================
  // DETAIL SECTIONS
  // ============================================================================
  Widget _buildDetailSection(String title, IconData icon, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2C5F8D), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(double lat, double lng) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF2C5F8D), size: 24),
              const SizedBox(width: 12),
              const Text(
                'الموقع',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openInMaps(lat, lng),
                icon: const Icon(Icons.zoom_in, size: 18),
                label: const Text('تكبير على الخريطة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C5F8D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.my_location, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'خط العرض: ${lat.toStringAsFixed(6)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_searching, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'خط الطول: ${lng.toStringAsFixed(6)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat, lng),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.crisis_management',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(lat, lng),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          size: 40,
                          color: Colors.red,
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

  Widget _buildTeamSection(Map<String, dynamic> team) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C5F8D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.people, color: Color(0xFF2C5F8D), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الفريق المسؤول',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  team['name'] ?? 'فريق غير معروف',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                if (team['branch'] != null)
                  Text(
                    team['branch'],
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsSection(String incidentId) {
    return Obx(() {
      final steps = controller.getStepsForIncident(incidentId);

      if (steps.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              'لا توجد خطوات مسجلة',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        );
      }

      final completedCount = steps.where((s) => s['status'] == true).length;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Text(
                  'خطوات العمل ($completedCount/${steps.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: completedCount / steps.length,
              backgroundColor: Colors.orange[100],
              valueColor: const AlwaysStoppedAnimation(Colors.orange),
            ),
            const SizedBox(height: 16),
            ...steps.map((step) {
              final isDone = step['status'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDone ? Colors.green : Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isDone ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step['title'] ?? 'خطوة',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          Text(
                            isDone ? 'مكتمل' : 'قيد التنفيذ',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDone ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      );
    });
  }

  // ============================================================================
  // HELPERS
  // ============================================================================
  String _getStatusArabic(String? status) {
    if (status == null) return 'غير معروف';
    switch (status.toLowerCase()) {
      case 'قيد الانتظار':
        return 'قيد الانتظار';
      case 'قيد التنفيذ':
        return 'قيد التنفيذ';
      case 'تم حلها':
        return 'تم حلها';
      default:
        return status;
    }
  }

  String _getSeverityArabic(String? severity) {
    if (severity == null) return 'منخفض';
    switch (severity.toLowerCase()) {
      case 'منخفضة':
        return 'منخفضة';
      case 'متوسطة':
        return 'متوسطة';
      case 'عالية':
        return 'عالية';
      case 'حرجة':
        return 'حرجة';
      default:
        return severity;
    }
  }

  void _openInMaps(double lat, double lng) {
    // Close bottom sheet
    Get.back();

    // Zoom to location on main map
    mapController.move(LatLng(lat, lng), 18);

    // Show confirmation snackbar
    Get.snackbar(
      'تم الانتقال',
      'تم الانتقال إلى موقع الحادثة على الخريطة',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }
}
