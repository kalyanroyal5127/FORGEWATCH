import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../services/api_client.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onAuthenticated});
  final void Function(ApiClient api, AuthUser user) onAuthenticated;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _api = ApiClient();
  bool _registering = false,
      _busy = false,
      _showPassword = false,
      _manualSubmit = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final user = await _api.restoreSession();
      if (user != null && mounted && !_manualSubmit) {
        widget.onAuthenticated(_api, user);
      }
    } on ApiException catch (e) {
      if (mounted && e.statusCode != 401) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not restore the saved session. Sign in to continue.');
      }
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    _manualSubmit = true;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        await _api.register(_username.text, _password.text);
        if (!mounted) return;
        setState(() {
          _registering = false;
          _password.clear();
          _error = 'Account created. Sign in with your new credentials.';
        });
        return;
      }
      final user = await _api.signIn(_username.text, _password.text);
      TextInput.finishAutofillContext(shouldSave: true);
      if (mounted) widget.onAuthenticated(_api, user);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: _LoginBackdrop()),
        SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Card(
                          child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: width < 380 ? 20 : 28,
                                  vertical: 30),
                              child: AutofillGroup(
                                child: Form(
                                    key: _form,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const Icon(Icons.diamond_outlined,
                                              size: 48,
                                              color: ForgeColors.cyan),
                                          const SizedBox(height: 12),
                                          const Text(
                                              'MACHINE LEARNING-BASED\nFAULT DETECTION AND\nPREDICTION SYSTEM',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.05,
                                                  height: 1.35,
                                                  fontSize: 14,
                                                  color: ForgeColors.text)),
                                          const SizedBox(height: 8),
                                          const Text(
                                              'FORGEWATCH  /  INTELLIGENT MACHINE MONITORING',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: ForgeColors.cyan,
                                                  fontSize: 10,
                                                  letterSpacing: 1.1,
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 26),
                                          Text(
                                              _registering
                                                  ? 'Create your account'
                                                  : 'Welcome back',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800)),
                                          const SizedBox(height: 5),
                                          Text(
                                              _registering
                                                  ? 'Register an operator account.'
                                                  : 'Sign in to your machine monitoring workspace.',
                                              style: const TextStyle(
                                                  color: ForgeColors.muted)),
                                          const SizedBox(height: 22),
                                          TextFormField(
                                              controller: _username,
                                              autofillHints: const [
                                                AutofillHints.username
                                              ],
                                              autocorrect: false,
                                              textInputAction:
                                                  TextInputAction.next,
                                              decoration: const InputDecoration(
                                                  labelText: 'Email / Username',
                                                  prefixIcon: Icon(
                                                      Icons.person_outline)),
                                              validator: (value) => (value ==
                                                          null ||
                                                      value.trim().length < 3)
                                                  ? 'Enter your username.'
                                                  : null),
                                          const SizedBox(height: 14),
                                          TextFormField(
                                              controller: _password,
                                              autofillHints: [
                                                _registering
                                                    ? AutofillHints.newPassword
                                                    : AutofillHints.password
                                              ],
                                              obscureText: !_showPassword,
                                              onFieldSubmitted: (_) =>
                                                  _submit(),
                                              decoration: InputDecoration(
                                                  labelText: _registering
                                                      ? 'Password (minimum 4 characters)'
                                                      : 'Password',
                                                  prefixIcon: const Icon(
                                                      Icons.lock_outline),
                                                  suffixIcon: IconButton(
                                                      tooltip: _showPassword
                                                          ? 'Hide password'
                                                          : 'Show password',
                                                      onPressed: () => setState(
                                                          () => _showPassword =
                                                              !_showPassword),
                                                      icon: Icon(_showPassword
                                                          ? Icons.visibility_off
                                                          : Icons.visibility))),
                                              validator: (value) => value ==
                                                          null ||
                                                      value.isEmpty
                                                  ? 'Enter your password.'
                                                  : (_registering &&
                                                          value.length < 4
                                                      ? 'Password must contain at least 4 characters.'
                                                      : null)),
                                          if (_error != null) ...[
                                            const SizedBox(height: 14),
                                            Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                    color: _error!.startsWith('Account created')
                                                        ? ForgeColors.green
                                                            .withValues(
                                                                alpha: .1)
                                                        : ForgeColors.danger
                                                            .withValues(
                                                                alpha: .12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                child: Text(_error!,
                                                    style: TextStyle(
                                                        color: _error!.startsWith(
                                                                'Account created')
                                                            ? ForgeColors.green
                                                            : ForgeColors.danger))),
                                          ],
                                          const SizedBox(height: 20),
                                          FilledButton.icon(
                                              onPressed: _busy ? null : _submit,
                                              icon: _busy
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2))
                                                  : Icon(_registering
                                                      ? Icons.person_add_alt_1
                                                      : Icons.login),
                                              label: Text(_busy
                                                  ? 'Connecting…'
                                                  : _registering
                                                      ? 'Create account'
                                                      : 'Sign in'),
                                              style: FilledButton.styleFrom(
                                                  minimumSize:
                                                      const Size.fromHeight(
                                                          52))),
                                          TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => setState(() {
                                                        _registering =
                                                            !_registering;
                                                        _error = null;
                                                      }),
                                              child: Text(_registering
                                                  ? 'Already registered? Sign in'
                                                  : 'New operator? Create an account')),
                                          const SizedBox(height: 8),
                                          const Text('API: $apiBaseUrl',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: ForgeColors.muted,
                                                  fontSize: 10)),
                                          const SizedBox(height: 8),
                                          const Text(
                                              'Software demonstration • all readings are simulated',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: ForgeColors.muted,
                                                  fontSize: 10)),
                                        ])),
                              )),
                        ))))),
      ]),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GridPainter());
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = ForgeColors.cyan.withValues(alpha: .035)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        ForgeColors.blue.withValues(alpha: .18),
        Colors.transparent
      ]).createShader(Rect.fromCircle(
          center: Offset(size.width * .5, size.height * .12),
          radius: size.width * .8));
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
