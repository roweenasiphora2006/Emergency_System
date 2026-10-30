import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/hospital_service.dart'; // ✅ Added this import

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _hospitalIdController = TextEditingController();

  bool _isLoading = false;

  void _handleLogin() async {
  final hospitalId = _hospitalIdController.text.trim();

  if (hospitalId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Enter Hospital ID')),
    );
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('hospital_id', hospitalId);

  Provider.of<HospitalService>(context, listen: false)
      .setHospitalId(hospitalId);

  Navigator.pushReplacementNamed(context, '/dashboard');
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_hospital, size: 100, color: Colors.redAccent),
              SizedBox(height: 20),
              Text(
                'Hospital Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 40),
              TextField(
                controller: _hospitalIdController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Hospital ID',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.redAccent),
                  ),
                  prefixIcon: Icon(Icons.badge, color: Colors.white70),
                ),
              ),
              SizedBox(height: 20),
             
              SizedBox(height: 30),
              _isLoading
                  ? CircularProgressIndicator(color: Colors.redAccent)
                  : ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'LOGIN',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
