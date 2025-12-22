import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddIncidentScreen extends StatefulWidget {
  const AddIncidentScreen({super.key});

  @override
  State<AddIncidentScreen> createState() => _AddIncidentScreenState();
}

class _AddIncidentScreenState extends State<AddIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final _typeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  String _status = 'Pending';
  String _severity = 'medium';
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final lat = double.parse(_latController.text);
      final lng = double.parse(_lngController.text);

      await _db.collection('incidents').add({
        'type': _typeController.text.trim(),
        'status': _status, // Pending | In Progress | Resolved
        'severity': _severity, // low | medium | high
        'description': _descriptionController.text.trim(),
        'location': {
          'lat': lat,
          'lng': lng,
        },
        'team_work': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Incident added successfully')),
        );
        _formKey.currentState!.reset();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
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
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _field(_typeController, 'Incident Type', 'fire / flood / accident'),
              const SizedBox(height: 12),

              _field(_descriptionController, 'Description',
                  'Describe the incident', maxLines: 3),
              const SizedBox(height: 12),

              _dropdown(
                label: 'Status',
                value: _status,
                items: const ['Pending', 'In Progress', 'Resolved'],
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),

              _dropdown(
                label: 'Severity',
                value: _severity,
                items: const ['low', 'medium', 'high'],
                onChanged: (v) => setState(() => _severity = v!),
              ),
              const SizedBox(height: 12),

              _field(_latController, 'Latitude', '28.0871',
                  keyboard: TextInputType.number),
              const SizedBox(height: 12),

              _field(_lngController, 'Longitude', '30.7618',
                  keyboard: TextInputType.number),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Create Incident'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
