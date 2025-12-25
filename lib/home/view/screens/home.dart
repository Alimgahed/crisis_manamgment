import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crisis_management/home/controller/home_controller.dart';
import 'package:crisis_management/home/view/widgets/analysis.dart';
import 'package:crisis_management/home/view/widgets/header.dart';
import 'package:crisis_management/home/view/widgets/map_widget.dart';
import 'package:crisis_management/home/view/widgets/side_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
class CrisisDashboard extends StatelessWidget {
  const CrisisDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    Get.put(DashboardController(), permanent: false);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: GetBuilder<DashboardController>(
          builder: (controller) {
            return Row(
              children: [
                buildSidebar(controller),
                Obx(() {
                  switch (controller.selectedIndex.value) {
                    case 0:
                      return _buildDashboardView(controller);
                    case 1:
                      return const Expanded(child: IncidentsMapScreen());
                    case 2:
                      return _buildTeamsView(controller);
                    case 3:
                      return Expanded(child: WaterCompanyAnalyticsDashboard());
                    case 4:
                      return _buildSettingsView();
                    default:
                      return _buildDashboardView(controller);
                  }
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboardView(DashboardController controller) {
    return Expanded(
      child: Column(
        children: [
          buildHeader(controller),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 2, child: _buildIncidentsList(controller)),
                Expanded(flex: 3, child: _buildDetailsPanel(controller)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentsList(DashboardController controller) {
    final severityMap = {'low': 'منخفض', 'medium': 'متوسط', 'high': 'عالي'};

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'الأزمات النشطة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                const Spacer(),
                Obx(
                  () => Text(
                    '${controller.filteredIncidents.length} أزمة',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              final filteredList = controller.filteredIncidents;

              if (filteredList.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد حوادث',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: filteredList.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final incident = filteredList[index];

                  return Obx(() {
                    final isSelected =
                        controller.selectedIncident.value?['id'] ==
                        incident['id'];

                    final severityKey = (incident['severity'] ?? 'low')
                        .toString()
                        .toLowerCase();
                    final severityLabel =
                        severityMap[severityKey] ??
                        (incident['severity'] ?? 'منخفض');

                    return InkWell(
                      onTap: () => controller.selectIncident(incident),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2C5F8D).withOpacity(0.1)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: controller
                                    .getStatusColor(incident['status'])
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                controller.getIncidentIcon(
                                  incident['typeName'] ?? 'Unknown',
                                ),
                                color: controller.getStatusColor(
                                  incident['status'],
                                ),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    incident['typeName'] ?? 'حادث غير معروف',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    incident['description'] ?? 'لا يوجد وصف',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: controller
                                              .getSeverityColor(
                                                incident['severity'] ?? 'low',
                                              )
                                              .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          severityLabel,
                                          style: TextStyle(
                                            color: controller.getSeverityColor(
                                              incident['severity'] ?? 'low',
                                            ),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (incident['createdAt'] != null)
                                        Text(
                                          _formatTime(incident['createdAt']),
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: controller.getStatusColor(
                                  incident['status'],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                incident['status'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel(DashboardController controller) {
    return Obx(() {
      final incident = controller.selectedIncident.value;

      if (incident == null) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              'اختر أزمة لعرض التفاصيل',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // بطاقة العنوان
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: controller
                                .getStatusColor(incident['status'])
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            controller.getIncidentIcon(
                              incident['typeName'] ?? 'حادث غير معروف',
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
                                incident['typeName'] ?? 'حادث غير معروف',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A5F),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: controller.getStatusColor(
                                        incident['status'],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      incident['status'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: controller
                                          .getSeverityColor(
                                            incident['severity'] ?? 'low',
                                          )
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: controller.getSeverityColor(
                                          incident['severity'] ?? 'low',
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'درجة الخطورة: ${incident['severity']?.toUpperCase() ?? 'منخفض'}',
                                      style: TextStyle(
                                        color: controller.getSeverityColor(
                                          incident['severity'] ?? 'low',
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Builder(
                          builder: (context) {
                            return IconButton(
                              // Modern Blue Icon
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                color: Colors.blue,
                                size: 28,
                              ),
                              onPressed: () {
                                final incident =
                                    controller.selectedIncident.value;
                                if (incident == null) return;

                                String selectedStatus = incident['status'];
                                   
                                    
                                String selectedSeverity = incident['severity'];
                                  

                                // Custom Dialog for a professional "Menu" feel
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    titlePadding: EdgeInsets.zero,
                                    backgroundColor: Colors.white,
                                    contentPadding: const EdgeInsets.all(20),
                                    content: StatefulBuilder(
                                      builder: (context, setState) {
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Header Section
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons
                                                      .settings_suggest_rounded,
                                                  color: Colors.blue,
                                                ),
                                                const SizedBox(width: 10),
                                                const Text(
                                                  'تعديل بيانات الأزمة',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(
                                                      0xFF0D47A1,
                                                    ), // Deep Blue
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(
                                              height: 30,
                                              thickness: 1,
                                            ),

                                            // Status Dropdown
                                            _buildLabel("حالة الأزمة"),
                                            _buildDropdown(
                                              value: selectedStatus,
                                              icon:
                                                  Icons.hourglass_empty_rounded,
                                              items: const [
                                                DropdownMenuItem(
                                                  value: 'قيد الانتظار',
                                                  child: Text('قيد الانتظار'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'قيد التنفيذ',
                                                  child: Text('قيد التنفيذ'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'تم حلها',
                                                  child: Text('تم حلها'),
                                                ),
                                              ],
                                              onChanged: (v) => setState(
                                                () => selectedStatus = v!,
                                              ),
                                            ),
                                            const SizedBox(height: 16),

                                            // Severity Dropdown
                                            _buildLabel("شدة الأزمة"),
                                            _buildDropdown(
                                              value: selectedSeverity,
                                              icon: Icons.speed_rounded,
                                              items: const [
                                                DropdownMenuItem(
                                                  value: 'منخفضة',
                                                  child: Text('منخفضة'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'متوسطة',
                                                  child: Text('متوسطة'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'عالية',
                                                  child: Text('عالية'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'حرجة',
                                                  child: Text('حرجة'),
                                                ),
                                              ],
                                              onChanged: (v) => setState(
                                                () => selectedSeverity = v!,
                                              ),
                                            ),
                                            const SizedBox(height: 24),

                                            // Action Buttons
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text(
                                                      'إلغاء',
                                                      style: TextStyle(
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  flex: 2,
                                                  child: ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.blue[700],
                                                      foregroundColor:
                                                          Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 12,
                                                          ),
                                                    ),
                                                    onPressed: () async {
                                                      Navigator.pop(context);
                                                      await controller
                                                          .updateIncidentStatusAndSeverity(
                                                            status:
                                                                selectedStatus,
                                                            severity:
                                                                selectedSeverity,
                                                          );
                                                    },
                                                    child: const Text(
                                                      'تحديث الأزمة',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        // Helper for labels
                      ],
                    ),
                    if (incident['createdAt'] != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'تم الإنشاء: ${_formatTime(incident['createdAt'])}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          if (incident['updatedAt'] != null) ...[
                            const SizedBox(width: 16),
                            Icon(
                              Icons.update,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'تم التحديث: ${_formatTime(incident['updatedAt'])}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // الوصف
              _buildInfoCard(
                'الوصف',
                Icons.description,
                incident['description'] ?? 'لا يوجد وصف متاح',
              ),

              const SizedBox(height: 16),

              // الموقع
              if (incident['location'] != null)
                _buildLocationCard(incident['location'],
                    incident['address']),

              const SizedBox(height: 16),

              // الفريق
              if (incident['team'] != null) _buildTeamCard(incident['team']),

              const SizedBox(height: 16),

              // الخطوات / المهام
              _buildStepsCard(controller, incident['id']),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildInfoCard(String title, IconData icon, String content) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2C5F8D), size: 24),
          const SizedBox(width: 16),
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
                const SizedBox(height: 8),
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

  Widget _buildLocationCard(Map<String, dynamic> location, String?address) {
    final lat = location['lat'];
    final lng = location['lng'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF2C5F8D), size: 24),
              const SizedBox(width: 12),
              Text(
                address??"",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'الإحداثيات: ($lat, $lng)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.my_location, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'خط العرض: $lat خط الطول: $lng',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C5F8D).withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group, color: Color(0xFF2C5F8D), size: 24),
              const SizedBox(width: 12),
              const Text(
                'الفريق المسؤول',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF2C5F8D).withOpacity(0.1),
                child: const Icon(Icons.people, color: Color(0xFF2C5F8D)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team['name'] ?? 'فريق غير معروف',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (team['branch'] != null)
                      Text(
                        team['branch'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              // Container(
              //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              //   decoration: BoxDecoration(
              //     color: (team['isAvailable'] ?? false)
              //         ? Colors.green.withOpacity(0.1)
              //         : Colors.red.withOpacity(0.1),
              //     borderRadius: BorderRadius.circular(12),
              //     border: Border.all(
              //       color: (team['isAvailable'] ?? false)
              //           ? Colors.green
              //           : Colors.red,
              //     ),
              //   ),
              //   child: Text(
              //     (team['isAvailable'] ?? false) ? 'متاح' : 'مشغول',
              //     style: TextStyle(
              //       fontSize: 11,
              //       fontWeight: FontWeight.w600,
              //       color: (team['isAvailable'] ?? false)
              //           ? Colors.green
              //           : Colors.red,
              //     ),
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepsCard(DashboardController controller, String? incidentId) {
    if (incidentId == null) return const SizedBox.shrink();

    final steps = controller.getStepsForIncident(incidentId);
    if (steps.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Text(
                'خطوات العمل (${steps.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.map((step) {
            final status = step['status'];
            final isCompleted = status == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green.withOpacity(0.05)
                    : Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCompleted
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  // مربع الاختيار
                  Checkbox(
                    value: isCompleted,
                    activeColor: Colors.green,
                    onChanged: (val) async {
                      final newStatus = val! ? true : false;
                      step['status'] = newStatus;
                      await FirebaseFirestore.instance
                          .collection('incident_steps')
                          .doc(step['id'])
                          .update({
                            'status': newStatus,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                      // تحديث واجهة المستخدم
                    },
                  ),

                  const SizedBox(width: 8),

                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : Text(
                              '${step['order']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['title'] ?? 'خطوة بدون اسم',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCompleted
                                ? Colors.grey
                                : const Color(0xFF1E3A5F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isCompleted ? 'مكتمل' : 'قيد التنفيذ',
                          style: TextStyle(
                            fontSize: 11,
                            color: isCompleted ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w500,
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
  }

  // عرض الفرق
  Widget _buildTeamsView(DashboardController controller) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.people, color: Color(0xFF1E3A5F), size: 28),
                SizedBox(width: 12),
                Text(
                  'إدارة الفرق',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.teams.isEmpty) {
                return const Center(child: Text('لا توجد فرق متاحة'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                itemCount: controller.teams.length,
                itemBuilder: (context, index) {
                  final team = controller.teams[index];
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C5F8D).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.group,
                                color: Color(0xFF2C5F8D),
                                size: 24,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (team['isAvailable'] ?? false)
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                (team['isAvailable'] ?? false)
                                    ? 'متاح'
                                    : 'مشغول',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: (team['isAvailable'] ?? false)
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          team['name'] ?? 'فريق غير معروف',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (team['branch'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            team['branch'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // Analytics View

Widget _title(String text) {
  return Text(
    text,
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  );
}

Widget _kpi(String title, int value, IconData icon, Color color) {
  return Container(
    width: 220,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 6),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 12),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(color: Colors.grey)),
      ],
    ),
  );
}

Widget _row(String label, int value, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              color: color,

              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}







  // Settings View
  Widget _buildSettingsView() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Coming Soon', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'غير معروف';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    final mins = difference.inMinutes;
    final hours = difference.inHours;
    final days = difference.inDays;

    String minutesText(int v) {
      if (v <= 0) return 'قبل لحظات';
      if (v == 1) return 'قبل دقيقة';
      if (v == 2) return 'قبل دقيقتين';
      if (v >= 3 && v <= 10) return 'قبل $v دقائق';
      return 'قبل $v دقيقة';
    }

    String hoursText(int v) {
      if (v == 1) return 'قبل ساعة';
      if (v == 2) return 'قبل ساعتين';
      if (v >= 3 && v <= 10) return 'قبل $v ساعات';
      return 'قبل $v ساعة';
    }

    String daysText(int v) {
      if (v == 1) return 'قبل يوم';
      if (v == 2) return 'قبل يومين';
      if (v >= 3 && v <= 10) return 'قبل $v أيام';
      return 'قبل $v يوم';
    }

    if (mins < 60) {
      return minutesText(mins);
    } else if (hours < 24) {
      return hoursText(hours);
    } else if (days < 7) {
      return daysText(days);
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

// 1. Professional Label Helper
Widget _buildLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6.0),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey,
      ),
    ),
  );
}

// 2. Custom Blue Dropdown Style
Widget _buildDropdown({
  required String value,
  required IconData icon,
  required List<DropdownMenuItem<String>> items,
  required ValueChanged<String?> onChanged,
}) {
  return DropdownButtonFormField<String>(
    value: value,
    icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.blue),
    decoration: InputDecoration(
      prefixIcon: Icon(icon, color: Colors.blue[300], size: 20),
      filled: true,
      fillColor: Colors.blue[50]?.withOpacity(0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[100]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
      ),
    ),
    items: items,
    onChanged: onChanged,
  );
}
