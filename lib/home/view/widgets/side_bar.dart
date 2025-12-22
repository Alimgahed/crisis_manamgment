 import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/home_controller.dart';

Widget buildSidebar(DashboardController controller) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E3A5F),
            Color(0xFF2C5F8D),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Crisis\nManagement',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white24, height: 1),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Obx(() => Column(
              children: [
                _buildStatCard(
                  'Active',
                  controller.activeIncidents.value.toString(),
                  Icons.warning_amber_rounded,
                  Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildStatCard(
                  'Critical',
                  controller.criticalIncidents.value.toString(),
                  Icons.error_outline,
                  Colors.red,
                ),
                const SizedBox(height: 12),
                _buildStatCard(
                  'Resolved Today',
                  controller.resolvedToday.value.toString(),
                  Icons.check_circle_outline,
                  Colors.green,
                ),
              ],
            )),
          ),
          
          const Divider(color: Colors.white24, height: 1),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(Icons.dashboard, 'Dashboard', 0),
                _buildNavItem(Icons.map, 'Map View', 1),
                _buildNavItem(Icons.people, 'Teams', 2),
                _buildNavItem(Icons.analytics, 'Analytics', 3),
                _buildNavItem(Icons.settings, 'Settings', 4),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin User',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Administrator',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_vert, color: Colors.white.withOpacity(0.7)),
              ],
            ),
          ),
        ],
      ),
    );
  }
   Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index,) {
     final DashboardController controller = Get.find<DashboardController>();
    return GestureDetector(
      onTap: () {
        controller.setSelectedIndex(index);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: controller.selectedIndex.value == index
              ? Colors.white.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: controller.selectedIndex.value == index
                ? Colors.white
                : Colors.white.withOpacity(0.7),
          ),
          title: Text(
            label,
            style: TextStyle(
              color: controller.selectedIndex.value == index
                  ? Colors.white
                  : Colors.white.withOpacity(0.7),
              fontWeight: controller.selectedIndex.value == index
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
          dense: true,
        ),
      ),
    );
  }

  