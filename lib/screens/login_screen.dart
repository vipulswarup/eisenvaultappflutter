import 'package:eisenvaultappflutter/config/dev_credentials.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/services/auth/classic_auth_service.dart';
import 'package:eisenvaultappflutter/services/auth/angora_auth_service.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen.dart';
import 'package:eisenvaultappflutter/services/api/base_service.dart';
import 'package:eisenvaultappflutter/widgets/error_display.dart';

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
    try {
      // Try to load credentials from the config file
      final credentialsMap = DevCredentials.credentials[instanceType];
      if (credentialsMap != null) {
        _urlController.text = credentialsMap['url'] ?? '';
        _usernameController.text = credentialsMap['username'] ?? '';
        _passwordController.text = credentialsMap['password'] ?? '';
      }
    } catch (e) {
      // If the config file is missing or has an error, use empty credentials
      _urlController.text = '';
      _usernameController.text = '';
      _passwordController.text = '';
      print('Dev credentials not loaded: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;
    
    // Calculate adaptive logo height
    final logoHeight = isSmallScreen 
      ? size.height * 0.40 // 20% of screen height on small screens
      : size.height * 0.50; // 30% of screen height on larger screens
      
    // Calculate padding for the entire form
    final screenPadding = isSmallScreen 
      ? const EdgeInsets.all(16.0)  
      : const EdgeInsets.all(24.0);
    
    // Calculate spacing between form elements
    final elementSpacing = isSmallScreen ? 12.0 : 16.0;

    return Scaffold(
      backgroundColor: EVColors.screenBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: screenPadding,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/eisenvault_logo.png',
                    height: logoHeight,
                  ),                  
                  SizedBox(height: elementSpacing),
                 
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
                  SizedBox(height: elementSpacing),
                  _buildTextField(
                    controller: _urlController,
                    label: 'Server URL',
                    hint: 'https://your-instance.eisenvault.com',
                    icon: Icons.link,
                  ),
                  SizedBox(height: elementSpacing),
                  _buildTextField(
                    controller: _usernameController,
                    label: 'Username',
                    icon: Icons.person,
                  ),
                  SizedBox(height: elementSpacing),
                  _buildPasswordField(),
                  SizedBox(height: elementSpacing * 1.5),
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
          loginResult = await authService.makeRequest(
            'login',
            requestFunction: () => authService.login(username, password)
          );
        } else {
          final authService = AngoraAuthService(baseUrl);
          loginResult = await authService.makeRequest(
            'login',
            requestFunction: () => authService.login(username, password)
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Login Successful!'),
              backgroundColor: EVColors.alertSuccess,
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          // For Angora login, extract the hostname from the URL or response
          String customerHostname = '';

          if (_selectedVersion == 'Angora') {
            // Option 1: Extract from the URL
            customerHostname = _urlController.text.trim().split('/')[0]; 
            
            // Option 2: Or if the hostname is returned in the login response:
            // customerHostname = loginResult['customerHostname'] ?? '';
          } else {
            // For Classic, this won't be used but set to avoid null issues
            customerHostname = 'classic-repository';
          }

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BrowseScreen(
                baseUrl: baseUrl,
                authToken: loginResult['token'],
                firstName: loginResult['firstName'] ?? 'User',
                instanceType: _selectedVersion,
                customerHostname: customerHostname,  // Now properly defined
              ),
            ),
          );
        }
      } on ServiceException catch (error) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: EVColors.screenBackground,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  minWidth: 300,
                  maxHeight: 250,
                ),
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 20.0
                      ),
                      child: ErrorDisplay(
                        error: error,
                        onRetry: () {
                          Navigator.of(context).pop();
                          _handleLogin();
                        },
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        icon: Icon(Icons.close, color: EVColors.textFieldLabel),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
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