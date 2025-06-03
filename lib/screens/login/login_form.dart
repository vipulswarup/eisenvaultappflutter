import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/login/login_handler.dart';
import 'package:flutter/material.dart';

class LoginForm extends StatefulWidget {
  final Function(dynamic error) onLoginFailed;

  const LoginForm({
    super.key,
    required this.onLoginFailed,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  final _loginHandler = LoginHandler();

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    // Calculate logo height based on screen size and keyboard visibility
    final logoHeight = isSmallScreen 
      ? size.height * 0.30  // Reduced from 0.40
      : size.height * 0.35; // Reduced from 0.50
      
    final screenPadding = EdgeInsets.only(
      left: 24.0,
      right: 24.0,
      top: 24.0,
      bottom: 24.0 + bottomPadding, // Add keyboard height to bottom padding
    );
    
    final elementSpacing = isSmallScreen ? 12.0 : 16.0;

    return Center(
      child: SingleChildScrollView(
        padding: screenPadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: size.height - screenPadding.top - screenPadding.bottom,
          ),
          child: IntrinsicHeight(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/eisenvault_logo.png',
                    height: logoHeight,
                  ),                  
                  SizedBox(height: elementSpacing * 2), // Increased spacing after logo
                 
                  _buildTextField(
                    controller: _urlController,
                    label: 'Server URL',
                    hint: 'https://your-instance.eisenvault.net',
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
                  SizedBox(height: elementSpacing * 2), // Increased spacing before button
                  _buildLoginButton(),
                  SizedBox(height: elementSpacing), // Add bottom spacing
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

        // Strip known suffixes (e.g., /share/page, /share, /page, /alfresco, /s, trailing slashes)
        baseUrl = _stripUrlSuffixes(baseUrl);

        await _loginHandler.performLogin(
          context: context,
          baseUrl: baseUrl,
          username: username, 
          password: password,
          instanceType: 'Classic',
        );
      } catch (e) {
        widget.onLoginFailed(e);
      }
    }
  }

  String _stripUrlSuffixes(String url) {
    // Ensure the URL has a scheme for parsing
    String workingUrl = url;
    if (!workingUrl.startsWith('http://') && !workingUrl.startsWith('https://')) {
      workingUrl = 'https://$workingUrl';
    }
    try {
      final uri = Uri.parse(workingUrl);
      // Rebuild the base URL with scheme, host, and port (if present)
      String base = uri.scheme + '://' + uri.host;
      if (uri.hasPort && uri.port != 80 && uri.port != 443) {
        base += ':${uri.port}';
      }
      return base;
    } catch (e) {
      // If parsing fails, return the original input
      return url;
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
