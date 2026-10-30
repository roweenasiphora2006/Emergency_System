import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/hospital_service.dart';


class HospitalEntry extends StatelessWidget {
  const HospitalEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HospitalService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Hospital Dashboard',
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.red,
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => LoginScreen(),
          '/dashboard': (context) => DashboardScreen(),
        },
      ),
    );
  }
}
