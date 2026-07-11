import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _selectedRole = 'customer'; // 'customer' or 'worker'
  String? _selectedSkill;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
              ),

              const SizedBox(height: 24),

              const Text(
                'Create\nAccount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                'Join Moka today',
                style: TextStyle(color: Color(0xFF888888), fontSize: 16),
              ),

              const SizedBox(height: 32),

              // Role selector
              const Text(
                'I am a...',
                style: TextStyle(
                  color: Color(0xFFCCCCCC),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildRoleCard(
                    role: 'customer',
                    label: 'Customer',
                    icon: Icons.person_outline,
                    subtitle: 'Post jobs',
                  ),
                  const SizedBox(width: 12),
                  _buildRoleCard(
                    role: 'worker',
                    label: 'Worker',
                    icon: Icons.handyman_outlined,
                    subtitle: 'Find jobs',
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildLabel('Full Name'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                hint: 'John Doe',
                prefixIcon: Icons.person_outline,
              ),

              const SizedBox(height: 16),

              _buildLabel('Email'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
              ),

              const SizedBox(height: 16),

              _buildLabel('Phone Number'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _phoneController,
                hint: '+233 XX XXX XXXX',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
              ),

              if (_selectedRole == 'worker') ...[
                const SizedBox(height: 16),
                _buildLabel('Your Skill'),
                const SizedBox(height: 8),
                _buildSkillDropdown(),
              ],

              const SizedBox(height: 16),

              _buildLabel('Password'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _passwordController,
                hint: '••••••••',
                obscure: _obscurePassword,
                prefixIcon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF888888),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
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
                          'Create Account',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?',
                      style:
                          TextStyle(color: Color(0xFF888888), fontSize: 15)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: Color(0xFFFF6B00),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String label,
    required IconData icon,
    required String subtitle,
  }) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFF6B00).withOpacity(0.15)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFF6B00)
                  : const Color(0xFF2A2A2A),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? const Color(0xFFFF6B00)
                      : const Color(0xFF888888),
                  size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF888888),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                    color: Color(0xFF666666), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillDropdown() {
    final skills = [
      'Plumber', 'Electrician', 'Cleaner', 'Carpenter',
      'Painter', 'Mason', 'Welder', 'Driver', 'Security', 'Other'
    ];
    return DropdownButtonFormField<String>(
      dropdownColor: const Color(0xFF1A1A1A),
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.build_outlined,
            color: Color(0xFF888888), size: 20),
        hintText: 'Select your skill',
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
      items: skills
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (val) => setState(() => _selectedSkill = val),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFCCCCCC),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF555555)),
        prefixIcon:
            Icon(prefixIcon, color: const Color(0xFF888888), size: 20),
        suffixIcon: suffixIcon,
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

  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (_selectedRole == 'worker' && _selectedSkill == null) {
      _showError('Please select your skill');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await AuthService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: _selectedRole,
        skill: _selectedSkill,
      );

      if (response.user != null) {
        if (!mounted) return;
        _showSuccess('Account created! Please check your email to verify.');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      _showError('Sign up failed: ${e.toString()}');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
