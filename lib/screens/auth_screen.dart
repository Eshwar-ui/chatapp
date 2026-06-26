import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/presence_service.dart';
import '../core/design/brutalist_colors.dart';
import '../core/design/brutalist_theme.dart';
import '../core/widgets/brutalist_box.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isLogin = true;
  var _isLoading = false;
  var _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createUserProfile(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'email': user.email ?? '',
      'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
      'profilePictureUrl': null,
      'profilePictureBase64': null,
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  void _submit() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await _createUserProfile(userCredential.user!);
      }
      await PresenceService().setOnline();
      // Navigation is handled by the auth-state listener in `home`
      // (main.dart). On success this screen is replaced by the main shell
      // automatically, so we must not push routes here.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim(),
            ),
            backgroundColor: BrutalistColors.dangerAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BrutalistTheme.radiusMD),
              side: BorderSide(
                color: BrutalistColors.lightBorder,
                width: BrutalistTheme.borderWidth,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalistColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BrutalistTheme.spacingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start, // Asymmetrical
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.06),
              // App logo
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: BrutalistColors.primaryAccent,
                  borderRadius: BorderRadius.circular(BrutalistTheme.radiusLG),
                  boxShadow: [
                    BoxShadow(
                      color: BrutalistColors.primaryAccent.withValues(
                        alpha: 0.3,
                      ),
                      offset: const Offset(0, 6),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: BrutalistColors.pureWhite,
                  size: 32,
                ),
              ),
              const SizedBox(height: BrutalistTheme.spacingLG),
              // App Name
              Text(
                'Chatapp',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: BrutalistTheme.spacingXS),
              Text(
                'Stay connected with the people who matter.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: BrutalistColors.lightTextSecondary,
                ),
              ),
              SizedBox(height: BrutalistTheme.spacingXXL),
              // Welcome Text
              Text(
                _isLogin ? 'Welcome back' : 'Create account',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: BrutalistTheme.spacingXS),
              Text(
                _isLogin
                    ? 'Sign in to continue your conversations.'
                    : 'Sign up to start chatting.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(height: BrutalistTheme.spacingXL),
              // Form in Brutalist Box
              BrutalistBox(
                padding: const EdgeInsets.all(BrutalistTheme.spacingLG),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: BrutalistTheme.spacingMD),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 7) {
                            return 'Use at least 7 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: BrutalistTheme.spacingXL),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        BrutalistButton(
                          text: _isLogin ? 'Sign in' : 'Sign up',
                          onPressed: _submit,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: BrutalistTheme.spacingLG),
              // Toggle Login/Signup
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: Text(
                    _isLogin
                        ? "Don't have an account? Sign up"
                        : 'Already have an account? Sign in',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
