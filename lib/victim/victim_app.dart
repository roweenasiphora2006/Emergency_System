import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VictimApp extends StatelessWidget {
  const VictimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const VictimHomePage();
  }
}


// ============================================================================
// APP STATE ENUM
// ============================================================================
enum AppState {
  idle,       // Initial state - ready to request
  searching,  // Waiting for driver to accept
  tracking,   // Ambulance assigned, tracking live
}

// ============================================================================
// MAIN VICTIM HOME PAGE
// ============================================================================
class VictimHomePage extends StatefulWidget {
  const VictimHomePage({Key? key}) : super(key: key);

  @override
  State<VictimHomePage> createState() => _VictimHomePageState();
}

class _VictimHomePageState extends State<VictimHomePage> {
  final MapController _mapController = MapController();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _cameraFittedOnce = false;
  bool _followAmbulance = true; // 👈 ADD THIS
  String _selectedEmergencyType = 'UNKNOWN';
String _selectedPatientStatus = 'UNKNOWN';
bool _hasAmbulanceArrived = false;


final List<String> _emergencyTypes = [
  'Cardiac',
  'Accident',
  'Breathing Issue',
  'Stroke',
  'Pregnancy',
  'Other',
];

final List<String> _patientStatuses = [
  'Critical',
  'Unconscious',
  'Bleeding',
  'Stable',
  'Unknown',
];


  // App state
  AppState _appState = AppState.idle;
  
  // GPS coordinates
  LatLng? _victimRealLocation;      // Actual GPS position
  LatLng? _pickupOffsetLocation;    // Demo offset position for routing
  LatLng? _ambulanceLocation;       // Live ambulance position
  
  // Emergency tracking
  String? _currentEmergencyId;
  String? _assignedDriverId;
  
  // Map polyline (route from ambulance to pickup)
  List<LatLng> _routePoints = [];
  
  // Realtime subscriptions
  RealtimeChannel? _assignmentChannel;
  RealtimeChannel? _ambulanceLocationChannel;
  Timer? _assignmentPoller;

  // Route fetch throttling
  DateTime? _lastRouteFetch;
  
  @override
  void initState() {
    Supabase.instance.client.realtime.onOpen(() {
  print('🟢 REALTIME SOCKET CONNECTED');
});

    super.initState();
    _initializeLocation();
  }
  
 @override
void dispose() {
  _assignmentPoller?.cancel();
  _assignmentChannel?.unsubscribe();
  _ambulanceLocationChannel?.unsubscribe();
  super.dispose();
}

  bool _hasReachedPickup(LatLng ambulance, LatLng pickup) {
  final distance = Geolocator.distanceBetween(
    ambulance.latitude,
    ambulance.longitude,
    pickup.latitude,
    pickup.longitude,
  );

  // meters threshold
  return distance < 30;
}

  // ==========================================================================
  // LOCATION INITIALIZATION
  // ==========================================================================
  Future<void> _initializeLocation() async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are required');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showError('Location permissions permanently denied');
        return;
      }
      
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _victimRealLocation = LatLng(position.latitude, position.longitude);
      });
      
      // Center map on victim location
      _mapController.move(_victimRealLocation!, 15.0);
      
    } catch (e) {
      _showError('Failed to get location: $e');
    }
  }
  
  // ==========================================================================
  // REQUEST AMBULANCE
  // ==========================================================================
  bool _requestInProgress = false;
 Future<void> _requestAmbulance() async {
  if (_selectedEmergencyType == 'UNKNOWN' ||
    _selectedPatientStatus == 'UNKNOWN') {
  _showError('Please select emergency type and patient status');
  _requestInProgress = false;
  return;
}

  if (_requestInProgress) return;

  if (_victimRealLocation == null) {
    _showError('Location not available');
    return;
  }

  _requestInProgress = true;

    _cameraFittedOnce = false;

    setState(() {
      _appState = AppState.searching;
    });
    
    try {
      // CRITICAL: Apply GPS offset for demo purposes
      // This simulates the victim being in a different location than the driver
      // In production, you would NOT use offset - just real GPS
      final double offsetLat = _victimRealLocation!.latitude + 0.001;
      final double offsetLng = _victimRealLocation!.longitude + 0.001;
      
      setState(() {
        _pickupOffsetLocation = LatLng(offsetLat, offsetLng);
      });
      
      // Insert emergency into Supabase
      // IMPORTANT: This app ONLY writes to emergencies table
      // Driver app handles ambulance_assignments and ambulance_locations
      final response = await _supabase
  .from('emergencies')
  .insert({
    'latitude': _victimRealLocation!.latitude,
    'longitude': _victimRealLocation!.longitude,
    'pickup_latitude': offsetLat,
    'pickup_longitude': offsetLng,
    'status': 'SEARCHING',
    'emergency_type': _selectedEmergencyType,
    'patient_status': _selectedPatientStatus,
  })

          .select()
          .single();
      
      _currentEmergencyId = response['id'];
      
      // Start listening for driver assignment
      _listenForAssignment();
    // 🔁 Fallback polling (in case realtime misses)
_assignmentPoller = Timer.periodic(
  const Duration(seconds: 2),
  (_) => _checkAssignmentFallback(),
);

      
      
    } catch (e) {
      _requestInProgress = false; // 👈 ADD THIS
      setState(() {
        _appState = AppState.idle;
      });
      _showError('Failed to request ambulance: $e');
    }
  }
  
  // ==========================================================================
  // LISTEN FOR DRIVER ASSIGNMENT
  // ==========================================================================
  Future<void> _checkAssignmentFallback() async {
  if (_currentEmergencyId == null ||
      _appState != AppState.searching) return;

  final result = await _supabase
      .from('ambulance_assignments')
      .select()
      .eq('emergency_id', _currentEmergencyId!)
      .eq('status', 'ACCEPTED')
      .limit(1);

  if (result.isNotEmpty) {
    print('🟢 FALLBACK ASSIGNMENT FOUND');
    _assignmentPoller?.cancel();
    _onDriverAssigned(result.first['driver_id']);
  }
}

  
  
  
  
  Future<void> _listenForAssignment() async {
    print('🧪 LISTENING FOR emergency_id = $_currentEmergencyId');

  // 1️⃣ First check if assignment already exists
final existingList = await _supabase
    .from('ambulance_assignments')
    .select()
    .eq('emergency_id', _currentEmergencyId!)
    .eq('status', 'ACCEPTED')
    .limit(1);

print('🧾 EXISTING ASSIGNMENTS: $existingList');

if (existingList.isNotEmpty) {
  _onDriverAssigned(existingList.first['driver_id']);
  return;
}



  // 2️⃣ Then subscribe for future inserts
  _assignmentChannel = _supabase
      .channel('assignment_${_currentEmergencyId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,

        schema: 'public',
        table: 'ambulance_assignments',

         filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'emergency_id',
      value: _currentEmergencyId,
    ),

        callback: (payload) {
          print('📦 ASSIGNMENT EVENT: ${payload.newRecord}');
        final data = payload.newRecord;
        if (data == null) return;

        if (data['emergency_id'] == _currentEmergencyId &&
            data['status'] == 'ACCEPTED') {
          _onDriverAssigned(data['driver_id']);
        }
      },
      )
      .subscribe();
}

  // ==========================================================================
  // DRIVER ASSIGNED CALLBACK
  // ==========================================================================
  
void _onDriverAssigned(String driverId) {
  _requestInProgress = false;

  // 🛑 STOP all assignment listeners
  _assignmentPoller?.cancel();
  _assignmentChannel?.unsubscribe();

  setState(() {
    _appState = AppState.tracking;
    _assignedDriverId = driverId;
    _routePoints.clear();
  });

  // Start listening to ambulance location
  _listenToAmbulanceLocation();
  _fetchAmbulanceLocation();
}


  // ==========================================================================
  // LISTEN TO AMBULANCE LOCATION (REALTIME)
  // ==========================================================================
  void _listenToAmbulanceLocation() {
    // Subscribe to ambulance_locations table
    // This is READ-ONLY - driver app continuously updates this table
    _ambulanceLocationChannel = _supabase
        .channel('ambulance_loc_${_assignedDriverId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update, // 👈 IMPORTANT
          schema: 'public',
          table: 'ambulance_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: _assignedDriverId,
          ),
         callback: (payload) {
           print('🚑 LOCATION EVENT PAYLOAD: ${payload.newRecord}');
  final data = payload.newRecord;
  if (data == null) return;

  _updateAmbulanceLocation(
    (data['latitude'] as num).toDouble(),
    (data['longitude'] as num).toDouble(),
  );
},

        )
        .subscribe();
  }
  
  // ==========================================================================
  // FETCH INITIAL AMBULANCE LOCATION
  // ==========================================================================
  Future<void> _fetchAmbulanceLocation() async {
    try {
      final response = await _supabase
    .from('ambulance_locations')
    .select()
    .eq('driver_id', _assignedDriverId!)
    .maybeSingle();

if (response == null) return;

      
     _updateAmbulanceLocation(
  (response['latitude'] as num).toDouble(),
  (response['longitude'] as num).toDouble(),
);

    } catch (e) {
      print('Error fetching ambulance location: $e');
    }
  }
   void _fitAmbulanceAndPickup() {
  if (_ambulanceLocation == null || _pickupOffsetLocation == null) return;

  final lat1 = _ambulanceLocation!.latitude;
  final lng1 = _ambulanceLocation!.longitude;
  final lat2 = _pickupOffsetLocation!.latitude;
  final lng2 = _pickupOffsetLocation!.longitude;

  final centerLat = (lat1 + lat2) / 2;
  final centerLng = (lng1 + lng2) / 2;

  _mapController.move(
    LatLng(centerLat, centerLng),
     _mapController.camera.zoom, // 👈 KEEP USER ZOOM
  );
}
  // ==========================================================================
  // UPDATE AMBULANCE LOCATION & ROUTE
  // ==========================================================================
  void _updateAmbulanceLocation(double lat, double lng) {
  // ❌ If already arrived, IGNORE further movement
  if (_hasAmbulanceArrived) return;

  final newLocation = LatLng(lat, lng);

  // ✅ Check arrival at victim pickup
  if (_pickupOffsetLocation != null &&
      _hasReachedPickup(newLocation, _pickupOffsetLocation!)) {
    setState(() {
      _ambulanceLocation = _pickupOffsetLocation; // snap to pickup
      _hasAmbulanceArrived = true;
      _followAmbulance = false;
      _routePoints.clear();
    });
 _ambulanceLocationChannel?.unsubscribe(); // 👈 optional cleanup
    return; // 🚨 STOP processing further updates
  }

  // Normal tracking
  setState(() {
    _ambulanceLocation = newLocation;
  });

  if (!_cameraFittedOnce && _pickupOffsetLocation != null) {
    _fitAmbulanceAndPickup();
    _cameraFittedOnce = true;
  }

  if (_pickupOffsetLocation != null && _routePoints.isEmpty) {
    _fetchRoute(newLocation, _pickupOffsetLocation!);
  }

  if (_followAmbulance) {
    _mapController.move(
      newLocation,
      _mapController.camera.zoom,
    );
  }
}


  // ==========================================================================
  // FETCH ROUTE FROM OSRM API
  // ==========================================================================
  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    // Throttle route fetching to avoid overloading OSRM public API
    if (_lastRouteFetch != null &&
        DateTime.now().difference(_lastRouteFetch!) <
            const Duration(seconds: 3)) {
      return;
    }
    
    _lastRouteFetch = DateTime.now();
    
    try {
      // Use OSRM public routing API
      // Format: /route/v1/driving/{lng1},{lat1};{lng2},{lat2}
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
        
        setState(() {
          _routePoints = coordinates
              .map((coord) => LatLng(coord[1] as double, coord[0] as double))
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching route: $e');
    }
  }
  
  // ==========================================================================
  // UI BUILDER
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Ambulance'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Map view
          _buildMap(),
          // Re-center on victim button
if (_victimRealLocation != null)
  Positioned(
    bottom: 120,
    right: 16,
    child: FloatingActionButton(
      heroTag: 'recenter_victim',
      backgroundColor: Colors.white,
      onPressed: () {
        _mapController.move(
          _victimRealLocation!,
          16.0,
        );
      },
      child: const Icon(
        Icons.my_location,
        color: Colors.red,
      ),
    ),
  ),
// Follow ambulance button
if (_ambulanceLocation != null)
  Positioned(
    bottom: 180, // above recenter button
    right: 16,
    child: FloatingActionButton(
      heroTag: 'follow_ambulance',
      backgroundColor: Colors.green,
      onPressed: () {
        _followAmbulance = true;
        _mapController.move(
          _ambulanceLocation!,
          _mapController.camera.zoom,
        );
      },
      child: const Icon(
        Icons.local_shipping,
        color: Colors.white,
      ),
    ),
  ),

          
          // Status overlay
          if (_appState != AppState.idle)
            _buildStatusOverlay(),
          
          // Request button (only in idle state)
          if (_appState == AppState.idle)
            _buildRequestPanel(),
        ],
      ),
      
    );
  }
  
  // ==========================================================================
  // MAP WIDGET
  // ==========================================================================
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
  initialCenter: _victimRealLocation ?? LatLng(28.7041, 77.1025),
  initialZoom: 15.0,
  maxZoom: 18.0,
  minZoom: 10.0,
  onPositionChanged: (_, hasGesture) {
    if (hasGesture) {
      _followAmbulance = false; // 👈 user touched map
    }
  },
),


      children: [
        // OpenStreetMap tiles
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.victim_app',
        ),
        
        // Route polyline (ambulance to pickup)
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 4.0,
                color: Colors.blue,
              ),
            ],
          ),
        
        // Markers
      MarkerLayer(
  markers: [
    // Victim's real location (blue)
    if (_victimRealLocation != null)
      Marker(
        point: _victimRealLocation!,
        width: 40,
        height: 40,
        child: const Icon(
          Icons.person_pin_circle,
          color: Colors.blue,
          size: 40,
        ),
      ),

    // Pickup offset location (red)
    if (_pickupOffsetLocation != null && _appState != AppState.idle)
      Marker(
        point: _pickupOffsetLocation!,
        width: 40,
        height: 40,
        child: const Icon(
          Icons.location_on,
          color: Colors.red,
          size: 40,
        ),
      ),

    // Ambulance live location (green)
    if (_ambulanceLocation != null)
      Marker(
  point: _ambulanceLocation!,
  width: 50,
  height: 50,
  child: TweenAnimationBuilder(
    tween: Tween<double>(begin: 0, end: 1),
    duration: const Duration(seconds: 1),
    builder: (_, value, child) {
      return Transform.translate(
        offset: Offset(0, (1 - value) * 10),
        child: child,
      );
    },
    child: const Icon(
      Icons.local_shipping,
      color: Colors.green,
      size: 50,
    ),
  ),
),

  
  ],
),

      
      ],
    );
  }
  
  // ==========================================================================
  // STATUS OVERLAY
  // ==========================================================================
  Widget _buildStatusOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.white,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_appState == AppState.searching) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                const Text(
                  'Searching for nearby ambulance...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              if (_appState == AppState.tracking && !_hasAmbulanceArrived) ...[
                const Icon(
                  Icons.local_shipping,
                  color: Colors.green,
                  size: 40,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ambulance is on the way',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Driver ID: $_assignedDriverId',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),

Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text(
      'Emergency:',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    Text(_selectedEmergencyType),
  ],
),

const SizedBox(height: 6),

Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text(
      'Patient Status:',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    Text(_selectedPatientStatus),
  ],
),

              ],
if (_hasAmbulanceArrived) ...[
  const Icon(
    Icons.check_circle,
    color: Colors.blue,
    size: 40,
  ),
  const SizedBox(height: 12),
  const Text(
    'Ambulance has arrived',
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.blue,
    ),
    textAlign: TextAlign.center,
  ),
],

              
            ],
          ),
        ),
      ),
    );
  }
  
  // ==========================================================================
  // REQUEST AMBULANCE BUTTON
  // ==========================================================================
  Widget _buildRequestButton() {
    return Positioned(
      bottom: 32,
      left: 32,
      right: 32,
      child: ElevatedButton(
        onPressed: _victimRealLocation == null ? null : _requestAmbulance,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'REQUEST AMBULANCE',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  Widget _buildRequestPanel() {
  return Positioned(
    bottom: 20,
    left: 16,
    right: 16,
    child: Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emergency type
            DropdownButtonFormField<String>(
              value: _selectedEmergencyType == 'UNKNOWN'
                  ? null
                  : _selectedEmergencyType,
              hint: const Text('Select Emergency Type'),
              items: _emergencyTypes
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedEmergencyType = value ?? 'UNKNOWN';
                });
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.emergency),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // Patient status
            DropdownButtonFormField<String>(
              value: _selectedPatientStatus == 'UNKNOWN'
                  ? null
                  : _selectedPatientStatus,
              hint: const Text('Select Patient Status'),
              items: _patientStatuses
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPatientStatus = value ?? 'UNKNOWN';
                });
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.monitor_heart),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Request button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _requestAmbulance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'REQUEST AMBULANCE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // ==========================================================================
  // ERROR DIALOG
  // ==========================================================================
  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}