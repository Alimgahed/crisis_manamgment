import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../controller/home_controller.dart';

class IncidentsMapScreen extends GetView<DashboardController> {
  const IncidentsMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      return Column(
        children: [
          const SizedBox(height: 8),
          Text(
            'Incidents: ${controller.incidents.length}',
            style: const TextStyle(fontSize: 16),
          ),
          Expanded(child: _map()),
        ],
      );
    });
  }
Widget _map() {
  final markers = controller.incidents
      .map<Marker?>((i) {
        final lat = (i['lat'] as num?)?.toDouble();
        final lng = (i['lng'] as num?)?.toDouble();

        if (lat == null || lng == null) return null;
        if (lat.isNaN || lng.isNaN) return null;

        final severity = (i['severity'] ?? 'low').toString();

        return Marker(
          point: LatLng(lat, lng),
          width: 40,
          height: 40,
          child: Icon(
            Icons.location_on,
            color: controller.getSeverityColor(severity), // 🔥 HERE
            size: 36,
          ),
        );
      })
      .whereType<Marker>()
      .toList();

  return FlutterMap(
    options: const MapOptions(
      initialCenter: LatLng(28.0871, 30.7618),
      initialZoom: 13,
      minZoom: 3,
      maxZoom: 18,
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.crisis_management',
      ),
      MarkerLayer(markers: markers),
    ],
  );
}
}
