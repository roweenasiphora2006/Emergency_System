import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'unified_patient_assessment_screen.dart';

class WaitingScreen extends StatefulWidget {
  final String ambulanceId;

  const WaitingScreen({super.key, required this.ambulanceId});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkArrival();
    });
  }
Future<void> _checkArrival() async {
  final response = await Supabase.instance.client
      .from('ambulance_assignments')
      .select()
      .eq('status', 'ARRIVED_AT_PICKUP')
      .eq('driver_id', widget.ambulanceId) // 🔴 IMPORTANT
      .limit(1);

  if (response.isNotEmpty) {
    _timer?.cancel();

    final assignmentId = response[0]['id'];

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedPatientAssessmentScreen(
          ambulanceAssignmentId: assignmentId,
          ambulanceId: widget.ambulanceId, // 🔴 ADD THI
        ),
      ),
    );
  }
}

  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'Waiting for ambulance to arrive at pickup...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
