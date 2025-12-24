// ============================================================================
// OPTIMIZED SIDEBAR - Fixed Navigation & State Management
// ============================================================================

import 'package:crisis_management/add_complaint.dart';
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
        colors: [Color(0xFF1E3A5F), Color(0xFF2C5F8D)],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 10,
          offset: Offset(2, 0),
        ),
      ],
    ),
    child: Column(
      children: [
        _buildHeader(),
        const Divider(color: Colors.white24, height: 1),
        _buildStatCards(controller),
        const Divider(color: Colors.white24, height: 1),
        Expanded(child: _buildNavigation(controller)),
        _buildUserProfile(),
      ],
    ),
  );
}

// ============================================================================
// HEADER
// ============================================================================
Widget _buildHeader() {
  return Container(
    padding: const EdgeInsets.all(24),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shield, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'إدارة\nالأزمات',
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
  );
}

// ============================================================================
// STAT CARDS
// ============================================================================
Widget _buildStatCards(DashboardController controller) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Obx(() => Column(
      children: [
        _buildStatCard(
          'نشطة',
          controller.activeIncidents.value.toString(),
          Icons.warning_amber_rounded,
          Colors.orange,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'حرجة',
          controller.criticalIncidents.value.toString(),
          Icons.error_outline,
          Colors.red,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'تم حلها اليوم',
          controller.resolvedToday.value.toString(),
          Icons.check_circle_outline,
          Colors.green,
        ),
      ],
    )),
  );
}

Widget _buildStatCard(String label, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(0.18)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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

// ============================================================================
// NAVIGATION - FIXED VERSION
// ============================================================================
Widget _buildNavigation(DashboardController controller) {
  return ListView(
    padding: const EdgeInsets.symmetric(vertical: 8),
    children: [
      _buildNavItem(
        controller: controller,
        icon: Icons.dashboard,
        label: 'لوحة التحكم',
        index: 0,
      ),
      _buildNavItem(
        controller: controller,
        icon: Icons.map,
        label: 'عرض الخريطة',
        index: 1,
      ),
      _buildNavItem(
        controller: controller,
        icon: Icons.people,
        label: 'الفرق',
        index: 2,
      ),
      _buildNavItem(
        controller: controller,
        icon: Icons.analytics,
        label: 'التحليلات',
        index: 3,
      ),
      _buildNavItem(
        controller: controller,
        icon: Icons.add_circle_outline,
        label: 'إضافة أزمة',
        index: 5,
        customAction: () {
          Get.to(() => const AddIncidentScreen());
        },
      ),
      _buildNavItem(
        controller: controller,
        icon: Icons.settings,
        label: 'الإعدادات',
        index: 4,
      ),
    ],
  );
}

// ============================================================================
// NAV ITEM - FIXED VERSION
// ============================================================================
Widget _buildNavItem({
  required DashboardController controller,
  required IconData icon,
  required String label,
  required int index,
  VoidCallback? customAction,
}) {
  return Obx(() {
    final bool isSelected = controller.selectedIndex.value == index;

    return InkWell(
      onTap: () {
        if (customAction != null) {
          // Execute custom action (like navigation to Add Incident)
          customAction();
        } else {
          // Update selected index for normal navigation
          controller.setSelectedIndex(index);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.white.withOpacity(0.15) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(color: Colors.white.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? Colors.white 
                  : Colors.white.withOpacity(0.7),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? Colors.white 
                      : Colors.white.withOpacity(0.7),
                  fontWeight: isSelected 
                      ? FontWeight.w600 
                      : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  });
}

// ============================================================================
// USER PROFILE
// ============================================================================
Widget _buildUserProfile() {
  return Container(
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
                'المسؤول',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                'مشرف',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: Colors.white.withOpacity(0.7),
          ),
          color: const Color(0xFF2C5F8D),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'الملف الشخصي',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'الإعدادات',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'تسجيل الخروج',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'profile':
                // Handle profile navigation
                Get.snackbar(
                  'الملف الشخصي',
                  'سيتم فتح الملف الشخصي قريباً',
                  backgroundColor: Colors.blue,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                );
                break;
              case 'settings':
                // Handle settings navigation
                final controller = Get.find<DashboardController>();
                controller.setSelectedIndex(4);
                break;
              case 'logout':
                // Handle logout
                Get.dialog(
                  AlertDialog(
                    title: const Text('تسجيل الخروج'),
                    content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Get.back();
                          // Add logout logic here
                          Get.snackbar(
                            'تم تسجيل الخروج',
                            'تم تسجيل الخروج بنجاح',
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('تسجيل الخروج'),
                      ),
                    ],
                  ),
                );
                break;
            }
          },
        ),
      ],
    ),
  );
}

// ============================================================================
// ALTERNATIVE: Enhanced Navigation Item with Animation
// ============================================================================
class EnhancedNavItem extends StatelessWidget {
  final DashboardController controller;
  final IconData icon;
  final String label;
  final int index;
  final VoidCallback? customAction;

  const EnhancedNavItem({
    Key? key,
    required this.controller,
    required this.icon,
    required this.label,
    required this.index,
    this.customAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool isSelected = controller.selectedIndex.value == index;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.white.withOpacity(0.15) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(color: Colors.white.withOpacity(0.3))
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (customAction != null) {
                customAction!();
              } else {
                controller.setSelectedIndex(index);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      icon,
                      color: isSelected 
                          ? Colors.white 
                          : Colors.white.withOpacity(0.7),
                      size: isSelected ? 24 : 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.7),
                        fontWeight: isSelected 
                            ? FontWeight.w600 
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isSelected ? 1.0 : 0.0,
                    child: Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
     
