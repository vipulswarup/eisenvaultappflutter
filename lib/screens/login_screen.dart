import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/services/auth/classic_auth_service.dart';
import 'package:eisenvaultappflutter/services/auth/angora_auth_service.dart';
import 'package:eisenvaultappflutter/screens/browse_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  String _selectedVersion = 'Classic';
  
  // Development mode flag - set to false before production
  final bool _devMode = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill the login form in development mode based on initially selected instance type
    if (_devMode) {
      _updateDevCredentials(_selectedVersion);
    }
  }
  
  // Update credentials based on selected instance type
  void _updateDevCredentials(String instanceType) {
    if (instanceType == 'Classic') {
      _urlController.text = 'systest.eisenvault.net';
      _usernameController.text = 'vipul';
      _passwordController.text = 'Vipul@123';
    } else if (instanceType == 'Angora') {
      _urlController.text = 'binod.angorastage.in';
      _usernameController.text = 'vipul@binod.in';
      _passwordController.text = 'Vipul@123';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EVColors.screenBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/eisenvault_logo.png',
                    height: 360,
                  ),                  
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    value: _selectedVersion,
                    decoration: InputDecoration(
                      labelText: 'Instance Type',
                      prefixIcon: Icon(Icons.dns, color: EVColors.textFieldPrefixIcon),
                      filled: true,
                      fillColor: EVColors.textFieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      labelStyle: TextStyle(color: EVColors.textFieldLabel),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Classic', child: Text('Classic')),
                      DropdownMenuItem(value: 'Angora', child: Text('Angora')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedVersion = value!;
                        // Auto-update credentials when instance type changes in dev mode
                        if (_devMode) {
                          _updateDevCredentials(_selectedVersion);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _urlController,
                    label: 'Server URL',
                    hint: 'https://your-instance.eisenvault.com',
                    icon: Icons.link,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _usernameController,
                    label: 'Username',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 32),
                  _buildLoginButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
  }) {

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
   return TextFormField(
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: EVColors.textFieldPrefixIcon) : null,
        filled: true,
        fillColor: EVColors.textFieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelStyle: TextStyle(color: EVColors.textFieldLabel),
        hintStyle: TextStyle(color: EVColors.textFieldHint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) {
        if (value?.isEmpty ?? true) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_showPassword,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(Icons.lock, color: EVColors.textFieldPrefixIcon),
        suffixIcon: IconButton(
          icon: Icon(
            _showPassword ? Icons.visibility_off : Icons.visibility,
            color: EVColors.textFieldPrefixIcon,
          ),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
        filled: true,
        fillColor: EVColors.textFieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelStyle: TextStyle(color: EVColors.textFieldLabel),
        hintStyle: TextStyle(color: EVColors.textFieldHint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) {
        if (value?.isEmpty ?? true) {
          return 'Please enter password';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: EVColors.buttonBackground,
          foregroundColor: EVColors.buttonForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Sign In',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  void _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        var baseUrl = _urlController.text.trim();
        final username = _usernameController.text.trim();
        final password = _passwordController.text;

        // Add https:// if no protocol specified
        if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
          baseUrl = 'https://$baseUrl';
        }

        // For Classic instances, append /alfresco if not present
        if (_selectedVersion == 'Classic' && !baseUrl.endsWith('/alfresco')) {
          baseUrl = '$baseUrl/alfresco';
        }

        Map<String, dynamic> loginResult;
        
        if (_selectedVersion == 'Classic') {
          final authService = ClassicAuthService(baseUrl);
          loginResult = await authService.login(username, password);
        } else {
          final authService = AngoraAuthService(baseUrl);
          loginResult = await authService.login(username, password);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Login Successful!'),
              backgroundColor: EVColors.alertSuccess,
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          // Navigate to the BrowseScreen after successful login
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BrowseScreen(
                baseUrl: baseUrl,
                authToken: loginResult['token'],
                firstName: loginResult['firstName'] ?? 'User',
                instanceType: _selectedVersion,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login Failed: ${e.toString()}'),
              backgroundColor: EVColors.alertFailure,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
