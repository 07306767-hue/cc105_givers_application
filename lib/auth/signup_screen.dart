import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_shell.dart';
import 'auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _contactNumber = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  GiventsRole _role = GiventsRole.attendee;
  bool _agreed = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _fullName.dispose();
    _contactNumber.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool _validPassword(String value) {
    return value.length >= 12 &&
        RegExp(r'[A-Za-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agree to the Terms and Privacy Policy.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await GiventsAuthService().signUp(
        email: _email.text,
        fullName: _fullName.text,
        contactNumber: _contactNumber.text,
        password: _password.text,
        role: _role,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => RoleBasedAppShell(role: _role)),
        (_) => false,
      );
    } on FirebaseAuthException catch (error) {
      final message = switch (error.code) {
        'email-already-in-use' => 'That email is already registered.',
        'weak-password' => 'Use a stronger password.',
        _ => error.message ?? 'Account creation failed.',
      };
      _showError(message);
    } catch (_) {
      _showError('Account creation failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create an account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('signup_email'),
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Enter a valid email.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('signup_full_name'),
                  controller: _fullName,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your full name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('signup_contact'),
                  controller: _contactNumber,
                  decoration: const InputDecoration(
                    labelText: 'Contact number',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a contact number.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('signup_password'),
                  controller: _password,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText: '12+ characters, letters, numbers and symbols',
                  ),
                  obscureText: true,
                  validator: (value) => value == null || !_validPassword(value)
                      ? 'Use 12+ characters with letters, numbers and symbols.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('signup_confirm_password'),
                  controller: _confirmPassword,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                  obscureText: true,
                  validator: (value) => value != _password.text
                      ? 'Passwords do not match.'
                      : null,
                ),
                const SizedBox(height: 16),
                const Text('Roles'),
                RadioGroup<GiventsRole>(
                  groupValue: _role,
                  onChanged: (value) => setState(() => _role = value!),
                  child: Column(
                    children: [
                      for (final role in GiventsRole.values)
                        RadioListTile<GiventsRole>(
                          title: Text(
                            role.name[0].toUpperCase() + role.name.substring(1),
                          ),
                          value: role,
                        ),
                    ],
                  ),
                ),
                CheckboxListTile(
                  key: const Key('signup_terms'),
                  value: _agreed,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'I agree to the Terms and Conditions and Privacy Policy.',
                  ),
                  onChanged: (value) =>
                      setState(() => _agreed = value ?? false),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('signup_submit'),
                  onPressed: _loading ? null : _signUp,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(),
                        )
                      : const Text('Sign up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
