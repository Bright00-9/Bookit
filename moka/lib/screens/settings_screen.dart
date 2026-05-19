import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/settings_model.dart';
import '/services/settings_service.dart';
import '/services/tips_service.dart';
import '/app_tip_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = SettingsService();
  final _supabase = Supabase.instance.client;

  AppSettings _settings = AppSettings();
  bool _isLoading = true;
  bool _isSaving = false;

  // Account form
  final _displayNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _service.fetchSettings();
      if (mounted) setState(() => _settings = settings);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadProfile() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _emailCtrl.text = user.email ?? '';
      _displayNameCtrl.text = user.userMetadata?['display_name'] ?? '';
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await _service.saveSettings(_settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Settings saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateProfile() async {
    try {
      await _supabase.auth.updateUser(UserAttributes(
        email: _emailCtrl.text.trim(),
        data: {'display_name': _displayNameCtrl.text.trim()},
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    if (_newPasswordCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    try {
      await _service.changePassword(_newPasswordCtrl.text);
      _oldPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Password changed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all your data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteAccount();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text('Save'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ─── NOTIFICATIONS ───────────────────────────────────────
          _sectionHeader(context, Icons.notifications_outlined, 'Notifications'),
          const SizedBox(height: 8),

          // Job radius (customers only — hide for workers if you have roles)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Job Post Radius',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${_settings.jobRadiusKm.toStringAsFixed(0)} km',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Workers within this distance will be notified when you post a job.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Slider(
                    value: _settings.jobRadiusKm,
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '${_settings.jobRadiusKm.toStringAsFixed(0)} km',
                    onChanged: (val) => setState(
                      () => _settings = _settings.copyWith(jobRadiusKm: val),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('1 km', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text('100 km', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Notification toggles
          Card(
            child: Column(
              children: [
                _switchTile(
                  title: 'New Job Alerts',
                  subtitle: 'Get notified when a job is posted near you',
                  icon: Icons.work_outline,
                  value: _settings.notifyNewJobs,
                  onChanged: (val) => setState(
                    () => _settings = _settings.copyWith(notifyNewJobs: val),
                  ),
                ),
                const Divider(height: 1, indent: 16),
                _switchTile(
                  title: 'Application Updates',
                  subtitle: 'Status changes on your applications',
                  icon: Icons.assignment_turned_in_outlined,
                  value: _settings.notifyApplicationUpdates,
                  onChanged: (val) => setState(
                    () => _settings =
                        _settings.copyWith(notifyApplicationUpdates: val),
                  ),
                ),
                const Divider(height: 1, indent: 16),
                _switchTile(
                  title: 'Messages',
                  subtitle: 'New messages from customers or workers',
                  icon: Icons.chat_bubble_outline,
                  value: _settings.notifyMessages,
                  onChanged: (val) => setState(
                    () => _settings = _settings.copyWith(notifyMessages: val),
                  ),
                ),
                const Divider(height: 1, indent: 16),
                _switchTile(
                  title: 'Promotions & Tips',
                  subtitle: 'App updates, tips, and offers',
                  icon: Icons.local_offer_outlined,
                  value: _settings.notifyPromotions,
                  onChanged: (val) => setState(
                    () =>
                        _settings = _settings.copyWith(notifyPromotions: val),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── ACCOUNT & PROFILE ───────────────────────────────────
          _sectionHeader(context, Icons.person_outline, 'Account & Profile'),
          const SizedBox(height: 8),

          // Edit profile
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit Profile',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _displayNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _updateProfile,
                      child: const Text('Update Profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Change password
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Change Password',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _oldPasswordCtrl,
                    obscureText: _obscureOld,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureOld
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscureOld = !_obscureOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPasswordCtrl,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordCtrl,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _changePassword,
                      child: const Text('Change Password'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ─── DANGER ZONE ─────────────────────────────────────────
          _sectionHeader(context, Icons.warning_amber_outlined, 'Account Actions',
              color: Colors.red),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign Out'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _confirmSignOut,
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete Account',
                      style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Permanently removes all your data'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.red),
                  onTap: _confirmDeleteAccount,
                ),
              ],
            ),
          ),

            // ── TIPS ──────────────────────────────────────────────────────
        _sectionHeader(context, Icons.lightbulb_outline, 'App Tips'),
        const SizedBox(height: 8),

        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.tips_and_updates_outlined),
                title: const Text('Show Tips on Startup'),
                subtitle: const Text(
                  'See a helpful tip each time you open the app',
                  style: TextStyle(fontSize: 12),
                ),
                value: _settings.showTips,
                onChanged: (val) async {
                  setState(
                    () => _settings = _settings.copyWith(showTips: val),
                  );
                  await TipsService().setTipsEnabled(val);
                },
              ),
              const Divider(height: 1, indent: 16),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Show a Tip Now'),
                subtitle: const Text('Preview a random tip'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => AppTipDialog.showIfEnabled(
                  context,
                  forceShow: true,
                ),
              ),
            ],
          ),
        ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title,
      {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}
