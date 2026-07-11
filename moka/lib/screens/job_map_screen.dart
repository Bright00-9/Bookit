import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JobMapScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final bool isWorker; // true = worker viewing customer location

  const JobMapScreen({
    super.key,
    required this.job,
    required this.isWorker,
  });

  @override
  State<JobMapScreen> createState() => _JobMapScreenState();
}

class _JobMapScreenState extends State<JobMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final _supabase = Supabase.instance.client;

  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  LatLng? _myLocation;
  LatLng? _jobLocation;
  bool _isLoading = true;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initMap() async {
    setState(() => _isLoading = true);

    // Get job location
    final lat = (widget.job['lat'] as num?)?.toDouble();
    final lng = (widget.job['lng'] as num?)?.toDouble();

    if (lat != null && lng != null) {
      _jobLocation = LatLng(lat, lng);
    }

    // Get my current location
    await _getMyLocation();

    // Build markers
    _buildMarkers();

    // Start tracking my location every 10 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _getMyLocation();
    });

    setState(() => _isLoading = false);
  }

  Future<void> _getMyLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _myLocation = LatLng(position.latitude, position.longitude);
      });
      _buildMarkers();

      // Update location in Supabase if worker
      if (widget.isWorker) {
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          await _supabase.from('profiles').update({
            'lat': position.latitude,
            'lng': position.longitude,
          }).eq('id', userId);
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _buildMarkers() {
    final markers = <Marker>{};
    final circles = <Circle>{};

    // My location marker
    if (_myLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('my_location'),
        position: _myLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          widget.isWorker
              ? BitmapDescriptor.hueBlue
              : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: widget.isWorker ? 'Your Location' : 'You',
        ),
      ));
    }

    // Job location marker
    if (_jobLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('job_location'),
        position: _jobLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          widget.isWorker
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueGreen,
        ),
        infoWindow: InfoWindow(
          title: widget.isWorker ? 'Job Location' : 'Worker Location',
          snippet: widget.job['title'],
        ),
      ));

      // Add radius circle around job
      circles.add(Circle(
        circleId: const CircleId('job_radius'),
        center: _jobLocation!,
        radius: 100, // 100 meters
        fillColor: const Color(0xFFFF6B00).withOpacity(0.1),
        strokeColor: const Color(0xFFFF6B00).withOpacity(0.4),
        strokeWidth: 2,
      ));
    }

    setState(() {
      _markers = markers;
      _circles = circles;
    });
  }

  Future<void> _centerMap() async {
    final controller = await _mapController.future;
    if (_myLocation != null && _jobLocation != null) {
      // Fit both markers in view
      final bounds = LatLngBounds(
        southwest: LatLng(
          _myLocation!.latitude < _jobLocation!.latitude
              ? _myLocation!.latitude
              : _jobLocation!.latitude,
          _myLocation!.longitude < _jobLocation!.longitude
              ? _myLocation!.longitude
              : _jobLocation!.longitude,
        ),
        northeast: LatLng(
          _myLocation!.latitude > _jobLocation!.latitude
              ? _myLocation!.latitude
              : _jobLocation!.latitude,
          _myLocation!.longitude > _jobLocation!.longitude
              ? _myLocation!.longitude
              : _jobLocation!.longitude,
        ),
      );
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } else if (_myLocation != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_myLocation!, 15),
      );
    }
  }

  double _getDistance() {
    if (_myLocation == null || _jobLocation == null) return 0;
    return Geolocator.distanceBetween(
          _myLocation!.latitude,
          _myLocation!.longitude,
          _jobLocation!.latitude,
          _jobLocation!.longitude,
        ) /
        1000; // convert to km
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // Map
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFFF6B00)))
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _jobLocation ??
                        _myLocation ??
                        const LatLng(5.6037, -0.1870), // Accra default
                    zoom: 14,
                  ),
                  onMapCreated: (controller) {
                    _mapController.complete(controller);
                    _centerMap();
                  },
                  markers: _markers,
                  circles: _circles,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  mapType: MapType.normal,
                  style: _mapStyle, // dark map style
                ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2A2A2A)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFF2A2A2A)),
                        ),
                        child: Text(
                          widget.job['title'] ?? 'Job Location',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom info card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Job info row
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_on,
                            color: Color(0xFFFF6B00), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.job['title'] ?? 'Job',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.job['skill_needed'] ?? '',
                              style: const TextStyle(
                                  color: Color(0xFF888888), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      // Distance
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color:
                                  const Color(0xFFFF6B00).withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${_getDistance().toStringAsFixed(1)} km',
                              style: const TextStyle(
                                color: Color(0xFFFF6B00),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const Text('away',
                                style: TextStyle(
                                    color: Color(0xFF888888),
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegend(
                        color: widget.isWorker
                            ? Colors.blue
                            : const Color(0xFFFF6B00),
                        label: 'You',
                      ),
                      const SizedBox(width: 20),
                      _buildLegend(
                        color: widget.isWorker
                            ? const Color(0xFFFF6B00)
                            : Colors.green,
                        label: widget.isWorker
                            ? 'Job Location'
                            : 'Worker',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Center map button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _centerMap,
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text('Center Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF888888), fontSize: 12)),
      ],
    );
  }

  // Dark map style matching the app theme
  static const String _mapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#1d2c4d"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#8ec3b9"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a3646"}]},
    {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"color": "#4b6878"}]},
    {"featureType": "administrative.province", "elementType": "geometry.stroke", "stylers": [{"color": "#4b6878"}]},
    {"featureType": "landscape.man_made", "elementType": "geometry.stroke", "stylers": [{"color": "#334e87"}]},
    {"featureType": "landscape.natural", "elementType": "geometry", "stylers": [{"color": "#023e58"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#283d6a"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#6f9ba5"}]},
    {"featureType": "poi", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
    {"featureType": "poi.park", "elementType": "geometry.fill", "stylers": [{"color": "#023e58"}]},
    {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#3C7680"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#304a7d"}]},
    {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#98a5be"}]},
    {"featureType": "road", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2c6675"}]},
    {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#255763"}]},
    {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#b0d5ce"}]},
    {"featureType": "road.highway", "elementType": "labels.text.stroke", "stylers": [{"color": "#023747"}]},
    {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#98a5be"}]},
    {"featureType": "transit", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
    {"featureType": "transit.line", "elementType": "geometry.fill", "stylers": [{"color": "#283d6a"}]},
    {"featureType": "transit.station", "elementType": "geometry", "stylers": [{"color": "#3a4762"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0e1626"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4e6d70"}]}
  ]
  ''';
}
