import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/login/login_handler.dart';
import 'package:flutter/material.dart';

class LoginForm extends StatefulWidget {
  final Function(dynamic error) onLoginFailed;

  const LoginForm({super.key, required this.onLoginFailed});

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final form = Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Image.asset(
                          'assets/images/eisenvault_logo.png',
                          height: 64,
                          width: 200,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to your document workspace.',
                        style: TextStyle(color: EVColors.textSecondary),
                      ),
                      const SizedBox(height: 32),
                      _buildTextField(
                        controller: _urlController,
                        label: 'Server URL',
                        hint: 'https://your-instance.eisenvault.net',
                        icon: Icons.dns_outlined,
                        autofillHints: const [AutofillHints.url],
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.person_outline,
                        autofillHints: const [AutofillHints.username],
                      ),
                      const SizedBox(height: 20),
                      _buildPasswordField(),
                      const SizedBox(height: 28),
                      _buildLoginButton(),
                      const SizedBox(height: 24),
                      const Text(
                        'Use the server address provided by your organisation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: EVColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return Row(
          children: [
            if (wide)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: EVColors.sidebarBackground,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_copy_outlined,
                            size: 64,
                            color: Color(0xFF73D9CF),
                          ),
                          SizedBox(height: 40),
                          Text(
                            'Your documents.\nOne organised space.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Find, share and manage your team’s knowledge. Wherever work takes you.',
                            style: TextStyle(
                              color: Color(0xFFC1D1DD),
                              fontSize: 18,
                              height: 1.6,
                            ),
                          ),
                          SizedBox(height: 40),
                          Text(
                            'DOCUMENTS  /  WORKFLOWS  /  COLLABORATION',
                            style: TextStyle(
                              color: Color(0xFF73D9CF),
                              fontSize: 12,
                              height: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(child: form),
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    List<String>? autofillHints,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      autofillHints: autofillHints,
      keyboardType:
          autofillHints?.contains(AutofillHints.url) == true
              ? TextInputType.url
              : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon:
            icon != null
                ? Icon(icon, color: EVColors.textFieldPrefixIcon)
                : null,
        filled: true,
        fillColor: EVColors.textFieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelStyle: TextStyle(color: EVColors.textFieldLabel),
        hintStyle: TextStyle(color: EVColors.textFieldHint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(),
      obscureText: !_showPassword,
      autofillHints: const [AutofillHints.password],
      keyboardType: TextInputType.visiblePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(Icons.lock, color: EVColors.textFieldPrefixIcon),
        suffixIcon: IconButton(
          tooltip: _showPassword ? 'Hide password' : 'Show password',
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          instanceType: '', // Auto-detect from URL
        );
      } catch (e) {
        widget.onLoginFailed(e);
      }
    }
  }

  String _stripUrlSuffixes(String url) {
    // Ensure the URL has a scheme for parsing
    String workingUrl = url;
    if (!workingUrl.startsWith('http://') &&
        !workingUrl.startsWith('https://')) {
      workingUrl = 'https://$workingUrl';
    }
    try {
      final uri = Uri.parse(workingUrl);
      // Rebuild the base URL with scheme, host, and port (if present)
      String base = '${uri.scheme}://${uri.host}';
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
