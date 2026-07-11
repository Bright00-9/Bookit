import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/job_service.dart';
import '../services/job_post_service.dart';
import '../services/identity_guard.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  late MapController _mapController;

  String? _selectedSkill;
  JobCategory? _selectedCategory;
  String _selectedUrgency = 'normal';
  bool _isLoading = false;
  bool _isLoadingLocation = true;
  bool _isLoadingCategories = true;
  double? _lat;
  double? _lng;
  String _locationLabel = 'Fetching your location...';
  double _radiusKm = 10;
  List<JobCategory> _categories = [];
  List<_PhotoItem> _photos = [];

  final _picker = ImagePicker();

  final List<String> _skills = [
    'Plumber', 'Electrician', 'Cleaner', 'Carpenter',
    'Painter', 'Mason', 'Welder', 'Driver', 'Security', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _fetchLocation();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ─── Load categories + radius ─────────────────────────────
  Future<void> _loadCategories() async {
    try {
      final cats = await JobPostService().fetchCategories();
      final radius = await JobService.getCustomerRadius();
      if (mounted) {
        setState(() {
          _categories = cats;
          _radiusKm = radius;
          _isLoadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  // ─── GPS + reverse geocode ────────────────────────────────
  Future<void> _fetchLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      LocationPermission permission =
          await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final address = await JobPostService().reverseGeocode(
        position.latitude,
        position.longitude,
      );

      final latLng =
          LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
          _locationLabel = address;
          _isLoadingLocation = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(latLng, 15);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationLabel = 'Could not get location';
          _isLoadingLocation = false;
        });
      }
    }
  }

  // ─── Pick photos ──────────────────────────────────────────
  Future<void> _pickPhotos() async {
    if (_photos.length >= 5) {
      _showError('Maximum 5 photos allowed');
      return;
    }

    final picked = await _picker.pickMultiImage(
        imageQuality: 80);
    if (picked.isEmpty) return;

    final remaining = 5 - _photos.length;
    final toAdd = picked.take(remaining).toList();

    for (final xfile in toAdd) {
      final bytes = await xfile.readAsBytes();
      if (mounted) {
        setState(() {
          _photos.add(_PhotoItem(
            file: File(xfile.path),
            bytes: bytes,
            name: xfile.name,
          ));
        });
      }
    }
  }

  // ─── Post job ─────────────────────────────────────────────
  Future<void> _handlePost() async {
      final ok = await IdentityGuard.check(
        context,
        action: 'post a job',
      );
      if (!ok) return;
    if (_titleController.text.isEmpty ||
        _selectedSkill == null) {
      _showError('Please fill in the title and skill');
      return;
    }
    if (_lat == null || _lng == null) {
      _showError(
          'Location not available. Tap Refresh to try again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload photos first
      final photoUrls = <String>[];
      for (final photo in _photos) {
        final url = await JobPostService().uploadJobPhoto(
          photo.bytes,
          photo.name,
        );
        photoUrls.add(url);
      }

      // Post job with all new fields
      await JobService.postJob(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        skillNeeded: _selectedSkill!,
        urgency: _selectedUrgency,
        lat: _lat!,
        lng: _lng!,
        categoryId: _selectedCategory?.id,
        address: _locationLabel,
        radiusKm: _radiusKm,
        photoUrls: photoUrls,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              '✅ Job posted! Nearby workers have been notified.'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      _showError('Failed to post job. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
        ),
        title: const Text(
          'Post a Job',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Color(0xFFFF6B00), strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _handlePost,
              child: const Text(
                'Post',
                style: TextStyle(
                    color: Color(0xFFFF6B00),
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── LIVE MAP ──────────────────────────────────
            _buildLabel('Job Location'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _lat != null
                            ? LatLng(_lat!, _lng!)
                            : const LatLng(
                                5.6037, -0.1870), // Accra default
                        initialZoom: 15,
                        onTap: (_, latLng) async {
                          setState(() {
                            _lat = latLng.latitude;
                            _lng = latLng.longitude;
                          });
                          final address =
                              await JobPostService()
                                  .reverseGeocode(
                            latLng.latitude,
                            latLng.longitude,
                          );
                          if (mounted) {
                            setState(
                                () => _locationLabel = address);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.yourapp.app',
                        ),
                        // Radius circle
                        if (_lat != null && _lng != null)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(_lat!, _lng!),
                                radius: _radiusKm * 1000,
                                useRadiusInMeter: true,
                                color: const Color(0xFFFF6B00)
                                    .withOpacity(0.1),
                                borderColor: const Color(
                                        0xFFFF6B00)
                                    .withOpacity(0.5),
                                borderStrokeWidth: 1.5,
                              ),
                            ],
                          ),
                        // Pin marker
                        if (_lat != null && _lng != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_lat!, _lng!),
                                width: 48,
                                height: 48,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Color(0xFFFF6B00),
                                  size: 48,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    // Loading overlay
                    if (_isLoadingLocation)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFFF6B00)),
                        ),
                      ),

                    // GPS button
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: _fetchLocation,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF2A2A2A)),
                          ),
                          child: const Icon(Icons.my_location,
                              color: Color(0xFFFF6B00), size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Address label
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: Color(0xFFFF6B00), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationLabel,
                      style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _fetchLocation,
                    child: const Text(
                      'Refresh',
                      style: TextStyle(
                          color: Color(0xFFFF6B00),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Radius info
            Row(
              children: [
                const Icon(Icons.radar,
                    size: 14, color: Color(0xFF888888)),
                const SizedBox(width: 4),
                Text(
                  'Notifying workers within ${_radiusKm.toStringAsFixed(0)} km',
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12),
                ),
                const SizedBox(width: 4),
                const Text('·',
                    style: TextStyle(
                        color: Color(0xFF888888), fontSize: 12)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Change your radius in Settings → Notifications'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  ),
                  child: const Text(
                    'Change in Settings',
                    style: TextStyle(
                        color: Color(0xFFFF6B00),
                        fontSize: 12,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── JOB TITLE ─────────────────────────────────
            _buildLabel('Job Title'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleController,
              hint: 'e.g. Fix leaking bathroom pipe',
              prefixIcon: Icons.title,
            ),

            const SizedBox(height: 20),

            // ── SKILL ─────────────────────────────────────
            _buildLabel('Skill Needed'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedSkill,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(
                  color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.build_outlined,
                    color: Color(0xFF888888), size: 20),
                hintText: 'Select a skill',
                hintStyle:
                    const TextStyle(color: Color(0xFF555555)),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFF2A2A2A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFFFF6B00), width: 1.5),
                ),
              ),
              items: _skills
                  .map((s) => DropdownMenuItem(
                      value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) =>
                  setState(() => _selectedSkill = val),
            ),

            const SizedBox(height: 20),

            // ── CATEGORY ──────────────────────────────────
            _buildLabel('Category'),
            const SizedBox(height: 8),
            _isLoadingCategories
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF6B00)))
                : _categories.isEmpty
                    ? const Text('No categories found',
                        style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 13))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _categories.map((cat) {
                          final selected =
                              _selectedCategory?.id == cat.id;
                          return GestureDetector(
                            onTap: () => setState(
                                () => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(
                                  milliseconds: 200),
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFFF6B00)
                                    : const Color(0xFF1A1A1A),
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFFFF6B00)
                                      : const Color(0xFF2A2A2A),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (cat.icon != null)
                                    Text(cat.icon!,
                                        style: const TextStyle(
                                            fontSize: 14)),
                                  if (cat.icon != null)
                                    const SizedBox(width: 5),
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(
                                              0xFF888888),
                                      fontSize: 12,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

            const SizedBox(height: 20),

            // ── DESCRIPTION ───────────────────────────────
            _buildLabel('Description'),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText:
                    'Describe the job in detail so workers know what to expect...',
                hintStyle: const TextStyle(
                    color: Color(0xFF555555), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFF2A2A2A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFFFF6B00), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 20),

            // ── URGENCY ───────────────────────────────────
            _buildLabel('Urgency'),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildUrgencyChip(
                    'normal', 'Normal', Icons.schedule),
                const SizedBox(width: 10),
                _buildUrgencyChip(
                    'urgent', 'Urgent', Icons.flash_on),
                const SizedBox(width: 10),
                _buildUrgencyChip('emergency', 'Emergency',
                    Icons.warning_amber),
              ],
            ),

            const SizedBox(height: 20),

            // ── PHOTOS ────────────────────────────────────
            _buildLabel('Photos (optional, max 5)'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Add button
                  if (_photos.length < 5)
                    GestureDetector(
                      onTap: _pickPhotos,
                      child: Container(
                        width: 80,
                        height: 80,
                        margin:
                            const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF2A2A2A),
                              width: 1.5),
                        ),
                        child: const Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                                Icons.add_a_photo_outlined,
                                color: Color(0xFF888888),
                                size: 22),
                            SizedBox(height: 4),
                            Text('Add',
                                style: TextStyle(
                                    color: Color(0xFF888888),
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                    ),

                  // Thumbnails
                  ..._photos.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final photo = entry.value;
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(
                              right: 8),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(12),
                            image: DecorationImage(
                              image: FileImage(photo.file),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _photos.removeAt(idx)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white,
                                  size: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── POST BUTTON ───────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handlePost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5),
                      )
                    : const Text(
                        'Post Job & Notify Workers',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── Urgency chip ─────────────────────────────────────────
  Widget _buildUrgencyChip(
      String value, String label, IconData icon) {
    final isSelected = _selectedUrgency == value;
    Color color = const Color(0xFF4CAF50);
    if (value == 'urgent') color = const Color(0xFFFF9800);
    if (value == 'emergency')
      color = const Color(0xFFF44336);

    return Expanded(
      child: GestureDetector(
        onTap: () =>
            setState(() => _selectedUrgency = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.15)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color
                  : const Color(0xFF2A2A2A),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? color
                      : const Color(0xFF666666),
                  size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? color
                      : const Color(0xFF666666),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            color: Color(0xFFCCCCCC),
            fontSize: 14,
            fontWeight: FontWeight.w600));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFF555555)),
        prefixIcon: Icon(prefixIcon,
            color: const Color(0xFF888888), size: 20),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: Color(0xFFFF6B00), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─── Internal photo model ─────────────────────────────────────
class _PhotoItem {
  final File file;
  final Uint8List bytes;
  final String name;

  _PhotoItem({
    required this.file,
    required this.bytes,
    required this.name,
  });
}