import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/widgets/dev_api_panel.dart';
import 'package:gains/core/widgets/gains_scaffold.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:gains/core/widgets/legal_footer.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final session = context.read<AuthSession>();

    try {
      await session.login(_email.text, _password.text);
      if (!mounted) return;
      if (session.needsEmailVerification) {
        context.go('/verify-email');
      } else {
        context.go(session.needsOnboarding ? '/onboarding' : '/home');
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GainsScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _loading ? null : () => context.pop(),
        ),
        title: const Text('Log in'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Welcome back',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 24),
            GainsTextField(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            GainsTextField(
              controller: _password,
              label: 'Password',
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your password';
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : () => context.push('/forgot-password'),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() => _obscure = !_obscure);
                      },
                child: Text(_obscure ? 'Show password' : 'Hide password'),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Log in'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading ? null : () => context.push('/register'),
              child: const Text('Need an account? Sign up'),
            ),
            const DevApiPanel(),
            const SizedBox(height: 12),
            const LegalFooter(
              prefix: 'By logging in, you agree to our ',
              center: false,
            ),
            const SizedBox(height: 8),
          ],
        ),
        ),
      ),
    );
  }
}
