import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'worker_reviews_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _avatarUrl;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await AuthService.getCurrentProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _nameController.text = profile?['name'] ?? '';
          _phoneController.text = profile?['phone'] ?? '';
          _avatarUrl = profile?['avatar_url'];
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await AuthService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      await _loadProfile();
      setState(() => _isEditing = false);
      if (!mounted) return;
      _showSuccess('Profile updated successfully!');
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to update profile. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final file = File(picked.path);
      final fileName = '$userId/avatar.jpg';

      await Supabase.instance.client.storage
          .from('avatars')
          .upload(fileName, file,
              fileOptions: const FileOptions(upsert: true));

      final url = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': url}).eq('id', userId);

      if (mounted) setState(() => _avatarUrl = url);
      if (!mounted) return;
      _showSuccess('Profile picture updated!');
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to upload photo. Try again.');
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: Color(0xFF888888))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.logout();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFFE53935),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF4CAF50),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFFF6B00)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),
                    _buildAvatarSection(),
                    const SizedBox(height: 28),
                    _buildInfoSection(),
                    const SizedBox(height: 24),
                    if (_profile?['role'] == 'worker') ...[
                      _buildWorkerStats(),
                      const SizedBox(height: 24),
                    ],
                    _buildSettingsSection(),
                    const SizedBox(height: 24),
                    _buildLogoutButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('My Profile',
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800)),
        GestureDetector(
          onTap: () {
            if (_isEditing) {
              _saveProfile();
            } else {
              setState(() => _isEditing = true);
            }
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _isEditing
                  ? const Color(0xFFFF6B00)
                  : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isEditing
                    ? const Color(0xFFFF6B00)
                    : const Color(0xFF2A2A2A),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    _isEditing ? 'Save' : 'Edit',
                    style: TextStyle(
                      color: _isEditing
                          ? Colors.white
                          : const Color(0xFF888888),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ─── Avatar ────────────────────────────────────────────────────────────────
  Widget _buildAvatarSection() {
    final name = _profile?['name'] ?? '';
    final role = _profile?['role'] ?? 'customer';
    final skill = _profile?['skill'] ?? '';
    final savedUrl = _avatarUrl ?? _profile?['avatar_url'];

    return Column(
      children: [
        GestureDetector(
          onTap: _pickAndUploadAvatar,
          child: Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFFFF6B00), width: 2.5),
                ),
                child: _isUploadingAvatar
                    ? const Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(
                            color: Color(0xFFFF6B00), strokeWidth: 2))
                    : savedUrl != null
                        ? ClipOval(
                            child: Image.network(
                              savedUrl,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarInitial(name),
                            ),
                          )
                        : _avatarInitial(name),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF0D0D0D), width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                role == 'worker' ? '👷 Worker' : '👤 Customer',
                style: const TextStyle(
                    color: Color(0xFFFF6B00),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            if (role == 'worker' && skill.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Text(skill,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 12)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _avatarInitial(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Color(0xFFFF6B00),
            fontSize: 36,
            fontWeight: FontWeight.w800),
      ),
    );
  }

  // ─── Info Section ──────────────────────────────────────────────────────────
  Widget _buildInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Full Name',
            controller: _nameController,
            isEditable: _isEditing,
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            controller: _phoneController,
            isEditable: _isEditing,
            keyboardType: TextInputType.phone,
          ),
          _buildDivider(),
          _buildStaticRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: AuthService.currentEmail ?? 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool isEditable,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF888888), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 11)),
                const SizedBox(height: 4),
                isEditable
                    ? TextField(
                        controller: controller,
                        keyboardType: keyboardType,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                      )
                    : Text(
                        controller.text.isEmpty
                            ? '—'
                            : controller.text,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15)),
              ],
            ),
          ),
          if (isEditable)
            const Icon(Icons.edit,
                color: Color(0xFFFF6B00), size: 16),
        ],
      ),
    );
  }

  Widget _buildStaticRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF888888), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 11)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15)),
              ],
            ),
          ),
          const Icon(Icons.lock_outline,
              color: Color(0xFF444444), size: 16),
        ],
      ),
    );
  }

  Widget _buildDivider() =>
      const Divider(height: 1, color: Color(0xFF2A2A2A), indent: 50);

  // ─── Worker Stats ──────────────────────────────────────────────────────────
  Widget _buildWorkerStats() {
    final rating = (_profile?['rating'] ?? 0.0).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('My Stats',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard('⭐', 'Rating', rating),
            const SizedBox(width: 12),
            _buildStatCard('✅', 'Jobs Done', '—'),
            const SizedBox(width: 12),
            _buildStatCard(
              '🟢',
              'Status',
              (_profile?['is_online'] == true) ? 'Online' : 'Offline',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String emoji, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF888888), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ─── Settings Section ──────────────────────────────────────────────────────
  Widget _buildSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          if (_profile?['role'] == 'worker') ...[
            _buildSettingsTile(
              icon: Icons.star_outline,
              label: 'My Reviews',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkerReviewsScreen(
                    workerId: _profile!['id'],
                    workerName: _profile!['name'] ?? 'Worker',
                    rating: (_profile!['rating'] ?? 0.0).toDouble(),
                  ),
                ),
              ),
            ),
            _buildDivider(),
          ],
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () {},
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.lock_outline,
            label: 'Change Password',
            onTap: () {},
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.description_outlined,
            label: 'Terms & Conditions',
            onTap: _showTermsDialog,
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: _showPrivacyDialog,
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.help_outline,
            label: 'Help & Support',
            onTap: () {},
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.info_outline,
            label: 'About MoKa',
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF888888), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15)),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Color(0xFF444444), size: 15),
          ],
        ),
      ),
    );
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────
  void _showTermsDialog() {
    _showScrollableDialog(
      icon: Icons.description_outlined,
      title: 'Terms & Conditions',
      buttonText: 'I Understand',
      sections: const [
        _Section('1. Acceptance of Terms',
            'By using MoKa, you agree to these terms. If you do not agree, please do not use the app.'),
        _Section('2. User Accounts',
            'You are responsible for maintaining the confidentiality of your account credentials. You must provide accurate information during registration.'),
        _Section('3. Worker Conduct',
            'Workers must be qualified for the skills they register with. MoKa does not verify qualifications but reserves the right to remove workers who receive poor reviews.'),
        _Section('4. Payments',
            'All payments are processed securely through Paystack. MoKa does not store card details. Disputes must be raised within 48 hours of job completion.'),
        _Section('5. Ratings & Reviews',
            'Reviews must be honest and based on actual job experience. False or malicious reviews may result in account suspension.'),
        _Section('6. Liability',
            'MoKa acts as a platform connecting customers and workers. We are not liable for the quality of work performed or any disputes arising between users.'),
        _Section('7. Termination',
            'MoKa reserves the right to suspend or terminate accounts that violate these terms without prior notice.'),
      ],
    );
  }

  void _showPrivacyDialog() {
    _showScrollableDialog(
      icon: Icons.privacy_tip_outlined,
      title: 'Privacy Policy',
      buttonText: 'Got it',
      sections: const [
        _Section('Data We Collect',
            'We collect your name, phone number, email, and location data to provide our services. Location is only used when you are actively using the app.'),
        _Section('How We Use Your Data',
            'Your data is used to match workers with nearby jobs, process payments, and improve the app experience. We do not sell your data to third parties.'),
        _Section('Data Storage',
            'Your data is stored securely on Supabase servers. We use industry-standard encryption to protect your information.'),
        _Section('Location Data',
            'Worker locations are shared with customers only when a job is active. Location tracking stops when you go offline.'),
        _Section('Your Rights',
            'You can request deletion of your account and data at any time by contacting support. We will process requests within 30 days.'),
      ],
    );
  }

  void _showScrollableDialog({
    required IconData icon,
    required String title,
    required String buttonText,
    required List<_Section> sections,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      color: const Color(0xFFFF6B00), size: 22),
                  const SizedBox(width: 10),
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close,
                        color: Color(0xFF888888), size: 20),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sections
                        .map((s) => _buildSection(s))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(buttonText,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(_Section s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 4),
          Text(s.body,
              style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 12,
                  height: 1.5)),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.handyman_rounded,
                  color: Colors.white, size: 34),
            ),
            const SizedBox(height: 16),
            const Text('MoKa',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Workers On Demand',
                style: TextStyle(
                    color: Color(0xFFFF6B00), fontSize: 13)),
            const SizedBox(height: 12),
            const Text(
              'Connecting customers with skilled workers nearby. Fast, reliable, and secure.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF888888), fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text('Version 1.0.0',
                style: TextStyle(
                    color: Color(0xFF555555), fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: Color(0xFFFF6B00))),
          ),
        ],
      ),
    );
  }

  // ─── Logout ────────────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Log Out',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE53935),
          side: const BorderSide(color: Color(0xFFE53935)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ─── Section helper ────────────────────────────────────────────────────────
class _Section {
  final String title;
  final String body;
  const _Section(this.title, this.body);
}
