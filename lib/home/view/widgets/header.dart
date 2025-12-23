import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/home_controller.dart';

Widget buildHeader(DashboardController controller) {
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'لوحة تحكم الأزمات',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'مراقبة وإدارة الحوادث في الوقت الحقيقي',
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),

        Obx(
          () => Wrap(
            spacing: 8,
            children: ['الكل', 'قيد الانتظار', 'قيد التنفيذ', 'حرجة', 'تم حلها']
                .map(
                  (filter) => FilterChip(
                    label: Text(filter),
                    selected: controller.selectedFilter.value == filter,
                    onSelected: (_) => controller.setFilter(filter),
                    backgroundColor: Colors.grey[200],
                    selectedColor: const Color(0xFF2C5F8D),
                    labelStyle: TextStyle(
                      color: controller.selectedFilter.value == filter
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: controller.selectedFilter.value == filter
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        const SizedBox(width: 16),

        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined),
          style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => controller.refreshData(),
          icon: const Icon(Icons.refresh),
          style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
        ),
      ],
    ),
  );
}
