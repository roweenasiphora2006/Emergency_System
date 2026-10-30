import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/hospital_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
 @override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final prefs = await SharedPreferences.getInstance();
    final savedHospitalId = prefs.getString('hospital_id');

    if (savedHospitalId != null) {
      final hospitalService =
          Provider.of<HospitalService>(context, listen: false);

      hospitalService.setHospitalId(savedHospitalId);
    }
  });
}

  @override
  Widget build(BuildContext context) {
    final hospitalService = Provider.of<HospitalService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Hospital Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: hospitalService.requests.isEmpty
            ? Center(child: Text('No pending emergencies'))
            : ListView.builder(
                itemCount: hospitalService.requests.length,
                itemBuilder: (context, index) {
                  final req = hospitalService.requests[index];

                  return Card(
                    child: ListTile(
                      title: Text(
                          'Emergency ID: ${req['emergency_id']}'),
                      subtitle: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Status: ${req['status']}'),
                          if (req['paramedic_reports'] != null) ...[
                            Text(
                                'Patient: ${req['paramedic_reports']['patient_name']}'),
                            Text(
                                'Age: ${req['paramedic_reports']['age']}'),
                            Text(
                                'Gender: ${req['paramedic_reports']['gender']}'),
                            Text(
                                'Severity: ${req['paramedic_reports']['severity']}'),
                            Text(
                                'Complaint: ${req['paramedic_reports']['chief_complaint']}'),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.close,
                                color: Colors.red),
                            onPressed: () => hospitalService
                                .reject(req['emergency_id']),
                          ),
                          IconButton(
                            icon: Icon(Icons.check,
                                color: Colors.green),
                            onPressed: () => hospitalService
                                .confirm(req['emergency_id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
