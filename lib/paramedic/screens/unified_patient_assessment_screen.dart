import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';


class UnifiedPatientAssessmentScreen extends StatefulWidget {
  final String ambulanceAssignmentId;
  final String ambulanceId; // 🔴 ADD THIS

  const UnifiedPatientAssessmentScreen({
    super.key,
    required this.ambulanceAssignmentId,
    required this.ambulanceId,
  });


  @override
  State<UnifiedPatientAssessmentScreen> createState() =>
      _UnifiedPatientAssessmentScreenState();
}

class _UnifiedPatientAssessmentScreenState
    extends State<UnifiedPatientAssessmentScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- Patient Details State ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String? _selectedGender;
  String? _selectedBloodGroup;

  // Vitals
  final TextEditingController _pulseController = TextEditingController();
  final TextEditingController _respRateController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _spo2Controller = TextEditingController();
  final TextEditingController _bpController = TextEditingController();

  // --- Chief Complaint State ---
  String? _selectedComplaint;
  String? _selectedSubComplaint;
  final TextEditingController _otherComplaintController =
      TextEditingController();

  final List<String> _complaints = [
    'Cardiac Arrest',
    'Pregnancy (Labour pains/complications)',
    'Trauma & Injury',
    'Breathing Difficulty',
    'Seizures',
    'Poisoning / Overdose',
    'Stroke (Paralysis/Slurred Speech)',
    'Diabetic Emergency',
    'General Emergency',
  ];

  // --- Assessment State ---
  String _consciousnessLevel = 'Alert';
  String _severityLevel = 'Mild';
  final TextEditingController _symptomsController = TextEditingController();

  final List<String> _consciousnessOptions = ['Alert', 'Drowsy', 'Unconscious'];
  final List<String> _severityOptions = ['Mild', 'Moderate', 'Severe'];

  // --- Care State ---
  final TextEditingController _careController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _pulseController.dispose();
    _respRateController.dispose();
    _tempController.dispose();
    _spo2Controller.dispose();
    _bpController.dispose();
    _otherComplaintController.dispose();
    _symptomsController.dispose();
    _careController.dispose();
    super.dispose();
  }
Future<void> _submitReport() async {
  if (!_formKey.currentState!.validate()) return;

  await Supabase.instance.client.from('paramedic_reports').insert({
    'patient_name': _nameController.text,
    'age': int.parse(_ageController.text),
    'gender': _selectedGender!.toLowerCase(),
    'blood_group': _selectedBloodGroup!,
    'pulse': int.parse(_pulseController.text),
    'respiratory_rate': int.parse(_respRateController.text),
    'temperature': double.parse(_tempController.text),
    'spo2': int.parse(_spo2Controller.text),
    'bp': _bpController.text,
    'consciousness': _consciousnessLevel.toLowerCase(),
    'severity': _severityLevel.toLowerCase(),
    'chief_complaint':
        _selectedComplaint ?? _otherComplaintController.text,
    'symptoms': _symptomsController.text,
    'emergency_care_given': _careController.text,
    'ambulance_id': widget.ambulanceId,

  });

  // 🔴 THIS IS THE IMPORTANT NEW PART
  await Supabase.instance.client
      .from('ambulance_assignments')
      .update({'status': 'PARAMEDIC_DONE'})
      .eq('id', widget.ambulanceAssignmentId);

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Report Submitted'),
      content: const Text('Patient data saved successfully'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (_) => const LoginScreen()),
  (route) => false,
);

          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Soft gray background
      appBar: AppBar(
        title: Text(
          'Unified Patient Assessment',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Section 1: Patient Details ---
              _buildSectionHeader('Patient Details', 'Basic Information',
                  Icons.person_outline_rounded),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildLabel('Patient Name'),
                      _buildTextField(
                          controller: _nameController, hint: 'Full name'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Age'),
                                _buildTextField(
                                    controller: _ageController,
                                    hint: 'Years',
                                    isNumber: true),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Gender'),
                                _buildDropdown(
                                  value: _selectedGender,
                                  hint: 'Select',
                                  items: ['Male', 'Female', 'Other'],
                                  onChanged: (val) =>
                                      setState(() => _selectedGender = val),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Blood Group'),
                      _buildDropdown(
                        value: _selectedBloodGroup,
                        hint: 'Select',
                        items: [
                          'A+',
                          'A-',
                          'B+',
                          'B-',
                          'O+',
                          'O-',
                          'AB+',
                          'AB-'
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedBloodGroup = val),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- Section 1.1: Vital Signs ---
              _buildSectionHeader('Vital Signs', 'Current Health Status',
                  Icons.favorite_outline_rounded,
                  color: Colors.pink),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: _buildVitalField(
                                  'Pulse', 'bpm', _pulseController)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildVitalField('Resp. Rate', 'per min',
                                  _respRateController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: _buildVitalField(
                                  'Temperature', 'Celsius', _tempController)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildVitalField(
                                  'SpO2', 'Percent', _spo2Controller)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildVitalField('Blood Pressure', 'mmHg', _bpController),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              const Divider(thickness: 1, height: 1),
              const SizedBox(height: 32),

              // --- Section 2: Chief Complaint ---
              _buildSectionHeader('Chief Complaint',
                  'Reason for Emergency Call', Icons.assignment_late_outlined,
                  color: const Color(0xFF4C51BF)),
              const SizedBox(height: 16),
              ..._complaints
                  .map((complaint) => _buildComplaintOption(complaint)),
              const SizedBox(height: 16),
              _buildLabel('Other (Specify)'),
              _buildTextField(
                controller: _otherComplaintController,
                hint: 'Describe if not listed...',
                maxLines: 3,
              ),

              const SizedBox(height: 32),
              const Divider(thickness: 1, height: 1),
              const SizedBox(height: 32),

              // --- Section 3: Assessment ---
              _buildSectionHeader('Assessment', 'Consciousness & Symptoms',
                  Icons.analytics_outlined,
                  color: Colors.orange),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Consciousness Level'),
                      const SizedBox(height: 8),
                      // Using a Wrap or Column for options
                      Column(
                        children: _consciousnessOptions
                            .map((option) => _buildSelectionCard(
                                  option,
                                  _consciousnessLevel,
                                  (val) =>
                                      setState(() => _consciousnessLevel = val),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Symptoms Description'),
                      _buildTextField(
                          controller: _symptomsController,
                          hint: 'Describe observed symptoms...',
                          maxLines: 3),
                      const SizedBox(height: 16),
                      _buildLabel('Severity Level'),
                      const SizedBox(height: 8),
                      Row(
                        children: _severityOptions.map((option) {
                          final isSelected = _severityLevel == option;
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _severityLevel = option),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF4C51BF)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF4C51BF)
                                          : const Color(0xFFD1D5DB),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    option,
                                    style: GoogleFonts.inter(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF374151),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              const Divider(thickness: 1, height: 1),
              const SizedBox(height: 32),

              // --- Section 4: Emergency Care ---
              _buildSectionHeader('Emergency Care', 'Treatment Provided',
                  Icons.medical_services_outlined,
                  color: Colors.green),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Emergency Care Given'),
                      _buildTextField(
                          controller: _careController,
                          hint: 'Document interventions...',
                          maxLines: 5),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // --- Submit Button ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitReport,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: const Color(0xFF4C51BF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    'Submit Full Report',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionHeader(String title, String subtitle, IconData icon,
      {Color color = const Color(0xFF4C51BF)}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    required String hint,
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4C51BF), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        // Simple validation for example
        return null;
      },
    );
  }

  Widget _buildVitalField(
      String label, String unitHint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        _buildTextField(controller: controller, hint: unitHint, isNumber: true),
      ],
    );
  }

  Widget _buildDropdown(
      {required String? value,
      required String hint,
      required List<String> items,
      required Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      isExpanded: true, // 🔴 FIXES OVERFLOW
      value: value,

      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4C51BF), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      hint: Text(hint, style: const TextStyle(color: Color(0xFF9CA3AF))),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildComplaintOption(String text) {
    final bool isSelected = _selectedComplaint == text;
    final bool isTrauma = text == 'Trauma & Injury';
    final bool showTraumaSubOptions = isTrauma && isSelected;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              setState(() {
                if (isSelected && !isTrauma) {
                  _selectedComplaint = null;
                } else {
                  _selectedComplaint = text;
                  if (!isTrauma) {
                    _selectedSubComplaint = null;
                  }
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF4C51BF)
                      : const Color(0xFFE5E7EB),
                  width: isSelected ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF4C51BF)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        color: Color(0xFF4C51BF), size: 20),
                ],
              ),
            ),
          ),
        ),
        if (showTraumaSubOptions)
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 12),
            child: Column(
              children: [
                _buildSubOption('Accident'),
                _buildSubOption('Burns'),
                _buildSubOption('Head Injury'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSubOption(String text) {
    final bool isSelected = _selectedSubComplaint == text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSubComplaint = text;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE0E7FF) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4C51BF)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF4C51BF)
                        : const Color(0xFF374151),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, color: Color(0xFF4C51BF), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard(
    String text,
    String currentSelection,
    Function(String) onSelect,
  ) {
    final bool isSelected = currentSelection == text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onSelect(text),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4C51BF)
                  : const Color(0xFFE5E7EB),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF4C51BF)
                        : const Color(0xFF1F2937),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle,
                    color: Color(0xFF4C51BF), size: 20)
              else
                const Icon(Icons.radio_button_unchecked,
                    color: Color(0xFF9CA3AF), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
