import 'package:eisenvaultappflutter/config/dev_credentials.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/login/login_handler.dart';
import 'package:flutter/material.dart';

class LoginForm extends StatefulWidget {
  final Function(dynamic error) onLoginFailed;

  const LoginForm({
    Key? key,
    required this.onLoginFailed,
  }) : super(key: key);

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  String _selectedVersion = 'Classic';
  
  // Development mode flag
  final bool _devMode = true;
  final _loginHandler = LoginHandler();

  @override
  void initState() {
    super.initState();
    if (_devMode) {
      _updateDevCredentials(_selectedVersion);
    }
  }
  
  void _updateDevCredentials(String instanceType) {
    try {
      final credentialsMap = DevCredentials.credentials[instanceType];
      if (credentialsMap != null) {
        _urlController.text = credentialsMap['url'] ?? '';
        _usernameController.text = credentialsMap['username'] ?? '';
        _passwordController.text = credentialsMap['password'] ?? '';
      }
    } catch (e) {
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
    
    final logoHeight = isSmallScreen 
      ? size.height * 0.40
      : size.height * 0.50;
      
    final screenPadding = isSmallScreen 
      ? const EdgeInsets.all(16.0)  
      : const EdgeInsets.all(24.0);
    
    final elementSpacing = isSmallScreen ? 12.0 : 16.0;

    return Center(
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

        await _loginHandler.performLogin(
          context: context,
          baseUrl: baseUrl,
          username: username, 
          password: password,
          instanceType: _selectedVersion,
        );
      } catch (e) {
        widget.onLoginFailed(e);
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
