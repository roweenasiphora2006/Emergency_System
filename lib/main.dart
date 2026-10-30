import 'package:flutter/material.dart';
import 'driver/driver_app.dart';
import 'hospital/main.dart';
import 'victim/victim_app.dart';
import 'paramedic/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'role_selection/role_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hosuedvpcpvvlnuyhpxu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhvc3VlZHZwY3B2dmxudXlocHh1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5NTU4MDUsImV4cCI6MjA4MzUzMTgwNX0.YqDykE-gRlSaysjnJoTh-QDV8WqvWuUM0K5vtUd5mr4',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Emergency Response System',
      initialRoute: '/',
      routes: {
  '/': (context) => const RoleSelectionScreen(),

  // DRIVER LOGIN SCREEN
  '/driver': (context) => LoginScreen(),

  '/user': (context) => const VictimApp(),

   '/paramedic': (context) => const ParamedicEntry(),
  '/hospital': (context) => const HospitalEntry(),
},

    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title Coming Soon',
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
