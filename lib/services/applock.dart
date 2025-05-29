import 'package:chatapp/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockManager extends StatefulWidget {
  final Widget child;

  const AppLockManager({super.key, required this.child});

  @override
  State<AppLockManager> createState() => _AppLockManagerState();
}

class _AppLockManagerState extends State<AppLockManager> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('user_pin');

    try {
      // Try biometric first
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();

      if (isDeviceSupported && canAuthenticateWithBiometrics) {
        final didAuthenticate = await _auth.authenticate(
          localizedReason: 'Please authenticate to access the app',
          options: const AuthenticationOptions(
            biometricOnly:
                false, // allow fallback to PIN, pattern, etc. inside native sheet
            stickyAuth: true,
          ),
        );

        if (didAuthenticate) {
          _proceedToApp();
          return;
        }
      }
    } catch (e) {
      debugPrint('Biometric error: $e');
    }

    // Fallback to PIN if biometric not available or failed
    if (savedPin == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SetPinScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EnterPinScreen()),
      );
    }
  }

  void _proceedToApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// ---------- PIN SETUP ----------
class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final TextEditingController _pinController = TextEditingController();

  Future<void> _savePin() async {
    if (_pinController.text.length != 4) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pin', _pinController.text);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set PIN")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Set a 4-digit PIN as backup"),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(labelText: "Enter 4-digit PIN"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _savePin, child: const Text("Save PIN")),
          ],
        ),
      ),
    );
  }
}

// ---------- PIN ENTRY ----------
class EnterPinScreen extends StatefulWidget {
  const EnterPinScreen({super.key});

  @override
  State<EnterPinScreen> createState() => _EnterPinScreenState();
}

class _EnterPinScreenState extends State<EnterPinScreen> {
  final TextEditingController _pinController = TextEditingController();
  String? _error;

  Future<void> _verifyPin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('user_pin');

    if (_pinController.text == savedPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    } else {
      setState(() => _error = "Incorrect PIN");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Security"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 24),
            const Text(
              "Enter your PIN to unlock",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                labelText: "4-digit PIN",
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onSubmitted: (_) => _verifyPin(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _verifyPin,
              icon: const Icon(Icons.check),
              label: const Text("Verify"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
