import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_emailController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    if (_usernameController.text.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.register(
      _emailController.text.trim(),
      _passwordController.text,
      _usernameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isLoading = false;
        _success = 'Registration successful! Please login.';
      });
      _emailController.clear();
      _usernameController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      setState(() {
        _isLoading = false;
        _error = authService.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.cyan),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _buildRegisterForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        const SizedBox(height: 32),
        _buildForm(),
        const SizedBox(height: 24),
        _buildRegisterButton(),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'CREATE ACCOUNT',
          style: GoogleFonts.orbitron(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Join STACK USDT and start earning',
          style: GoogleFonts.rajdhani(
            fontSize: 16,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.neonRed.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.neonRed.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _error!,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.neonRed),
              textAlign: TextAlign.center,
            ),
          ),
        if (_success != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.neonGreen.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.neonGreen.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _success!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.neonGreen,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        _buildTextField(
          controller: _usernameController,
          label: 'Username',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outlined,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textMuted,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_outlined,
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textMuted,
              size: 20,
            ),
            onPressed: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.backgroundTertiary),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: GoogleFonts.inter(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: AppColors.textMuted),
          prefixIcon: Icon(icon, color: AppColors.cyan, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.backgroundPrimary,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.backgroundPrimary,
                  ),
                ),
              )
            : Text(
                'REGISTER',
                style: GoogleFonts.rajdhani(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
      ),
    );
  }
}
