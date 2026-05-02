import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/job_service.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedSkill;
  String _selectedUrgency = 'normal';
  bool _isLoading = false;
  double? _lat;
  double? _lng;
  String _locationLabel = 'Fetching your location...';

  final List<String> _skills = [
    'Plumber', 'Electrician', 'Cleaner', 'Carpenter',
    'Painter', 'Mason', 'Welder', 'Driver', 'Security', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _locationLabel =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (e) {
      setState(() => _locationLabel = 'Could not get location');
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
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location bar
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _locationLabel,
                      style: const TextStyle(color: Color(0xFF888888), fontSize: 14),
                    ),
                  ),
                  GestureDetector(
                    onTap: _fetchLocation,
                    child: const Text(
                      'Refresh',
                      style: TextStyle(
                          color: Color(0xFFFF6B00),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildLabel('Job Title'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleController,
              hint: 'e.g. Fix leaking bathroom pipe',
              prefixIcon: Icons.title,
            ),

            const SizedBox(height: 20),

            _buildLabel('Skill Needed'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedSkill,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.build_outlined,
                    color: Color(0xFF888888), size: 20),
                hintText: 'Select a skill',
                hintStyle: const TextStyle(color: Color(0xFF555555)),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
                ),
              ),
              items: _skills
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedSkill = val),
            ),

            const SizedBox(height: 20),

            _buildLabel('Description'),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText:
                    'Describe the job in detail so workers know what to expect...',
                hintStyle: const TextStyle(
                    color: Color(0xFF555555), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 20),

            _buildLabel('Urgency'),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildUrgencyChip('normal', 'Normal', Icons.schedule),
                const SizedBox(width: 10),
                _buildUrgencyChip('urgent', 'Urgent', Icons.flash_on),
                const SizedBox(width: 10),
                _buildUrgencyChip(
                    'emergency', 'Emergency', Icons.warning_amber),
              ],
            ),

            const SizedBox(height: 32),

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
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Post Job & Notify Workers',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgencyChip(String value, String label, IconData icon) {
    final isSelected = _selectedUrgency == value;
    Color color = const Color(0xFF4CAF50);
    if (value == 'urgent') color = const Color(0xFFFF9800);
    if (value == 'emergency') color = const Color(0xFFF44336);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedUrgency = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : const Color(0xFF2A2A2A),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? color : const Color(0xFF666666),
                  size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : const Color(0xFF666666),
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
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF555555)),
        prefixIcon:
            Icon(prefixIcon, color: const Color(0xFF888888), size: 20),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Future<void> _handlePost() async {
    if (_titleController.text.isEmpty || _selectedSkill == null) {
      _showError('Please fill in the title and skill');
      return;
    }
    if (_lat == null || _lng == null) {
      _showError('Location not available. Tap Refresh to try again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await JobService.postJob(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        skillNeeded: _selectedSkill!,
        urgency: _selectedUrgency,
        lat: _lat!,
        lng: _lng!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Job posted! Nearby workers have been notified.'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      _showError('Failed to post job. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
