import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HospitalService with ChangeNotifier {
  final supabase = Supabase.instance.client;

  String? hospitalId;
  List<Map<String, dynamic>> requests = [];

  void setHospitalId(String id) {
    hospitalId = id;
    fetchRequests();
  }

Future<void> fetchRequests() async {
  if (hospitalId == null) return;

  // 1️⃣ Fetch hospital requests
  final hospitalResponse = await supabase
      .from('emergency_hospital')
      .select()
      .eq('hospital_id', hospitalId!)
      .eq('status', 'REQUESTED');

  final List<Map<String, dynamic>> tempRequests = [];

  // 2️⃣ For each request, fetch paramedic report
  for (final row in hospitalResponse) {
    final ambulanceId = row['ambulance_id'];

    Map<String, dynamic>? paramedicReport;

    if (ambulanceId != null && ambulanceId.toString().isNotEmpty) {
      final reportResponse = await supabase
          .from('paramedic_reports')
          .select()
          .eq('ambulance_id', ambulanceId)
          .limit(1);

      if (reportResponse.isNotEmpty) {
        paramedicReport = reportResponse.first;
      }
    }

    // 3️⃣ Combine data
    tempRequests.add({
      ...row,
      'paramedic_reports': paramedicReport,
    });
  }

  requests = tempRequests;
  notifyListeners();
}

  Future<void> confirm(String emergencyId) async {
    await supabase
        .from('emergency_hospital')
        .update({'status': 'CONFIRMED'})
        .eq('emergency_id', emergencyId)
        .eq('hospital_id', hospitalId!);

    fetchRequests();
  }

  Future<void> reject(String emergencyId) async {
    await supabase
        .from('emergency_hospital')
        .update({'status': 'REJECTED'})
        .eq('emergency_id', emergencyId)
        .eq('hospital_id', hospitalId!);

    fetchRequests();
  }
}
