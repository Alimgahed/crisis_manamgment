import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddComplaintScreen extends StatefulWidget {
  const AddComplaintScreen({super.key});

  @override
  State<AddComplaintScreen> createState() => _AddComplaintScreenState();
}

class _AddComplaintScreenState extends State<AddComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // 1️⃣ Add complaint
      final complaintRef = await _db.collection('complaints').add({
        'source': 'hotline',
        'type': _typeController.text,
        'areaId': _areaController.text,
        'location': {
          'lat': double.parse(_latController.text),
          'lng': double.parse(_lngController.text),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'linkedIncidentId': null,
      });

      // 2️⃣ Create incident
      final incidentRef = await _db.collection('incidents').add({
        'type': _typeController.text,
        'status': 'open',
        'severity': 'medium',
        'location': {
          'lat': double.parse(_latController.text),
          'lng': double.parse(_lngController.text),
        },
        'complaintsCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3️⃣ Link complaint → incident (transaction)
      await _db.runTransaction((tx) async {
        tx.update(complaintRef, {
          'linkedIncidentId': incidentRef.id,
        });
      });

      // 4️⃣ Audit log
      await _db.collection('audit_logs').add({
        'entityType': 'incident',
        'entityId': incidentRef.id,
        'action': 'incident_created_from_hotline',
        'userId': 'system',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Incident created successfully')),
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
      appBar: AppBar(
        title: const Text('Add Hotline Complaint'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(
                  labelText: 'Complaint Type',
                  hintText: 'water_cut / leak / low_pressure',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(
                  labelText: 'Area ID',
                  hintText: 'nasr_city',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _latController,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lngController,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
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
}
