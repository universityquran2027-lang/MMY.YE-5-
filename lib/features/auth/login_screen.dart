import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/db/app_database.dart';
import '../shell/home_shell.dart';
import 'auth_service.dart';
import 'biometric_service.dart';
import 'change_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.app, required this.auth, required this.bio});
  final AppDatabase app;
  final AuthService auth;
  final BiometricService bio;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true, _busy = false;
  String? _error;
  bool _bioReady = false;
  Map<String, Object?>? _lastBioUser;

  @override
  void initState() {
    super.initState();
    _checkBio();
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  /// يظهر زر البصمة فقط إذا دعمه الجهاز وكان مفعّلاً لحساب نشط.
  Future<void> _checkBio() async {
    if (!await widget.bio.isSupported()) return;
    final users = await widget.app.db.query('users', where: "status = 'active'");
    for (final u in users) {
      if (await widget.bio.isEnabledFor(u['id'] as String)) {
        if (mounted) setState(() { _bioReady = true; _lastBioUser = u; });
        return;
      }
    }
  }

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    final r = await widget.auth.login(_user.text, _pass.text);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r.status) {
      case LoginStatus.ok:
        _enter(r.user!);
      case LoginStatus.locked:
        setState(() => _error = 'تم إيقاف الدخول مؤقتاً حتى ${TimeOfDay.fromDateTime(r.lockedUntil!).format(context)}');
      case LoginStatus.suspended:
        setState(() => _error = 'هذا الحساب موقوف');
      case LoginStatus.badCredentials:
        setState(() => _error = r.remainingAttempts == null
            ? 'اسم المستخدم أو كلمة المرور غير صحيحة'
            : 'بيانات غير صحيحة. المحاولات المتبقية: ${r.remainingAttempts}');
    }
  }

  Future<void> _bioLogin() async {
    if (_lastBioUser == null) return;
    if (await widget.bio.authenticate()) {
      _enter(_lastBioUser!);
    } else if (mounted) {
      setState(() => _error = 'تعذّر التحقق بالبصمة، استخدم كلمة المرور');
    }
  }

  void _enter(Map<String, Object?> user) {
    final next = user['must_change_password'] == 1
        ? ChangePasswordScreen(app: widget.app, auth: widget.auth, user: user, forced: true, bio: widget.bio)
        : HomeShell(app: widget.app, auth: widget.auth, bio: widget.bio, user: user);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [cs.primary.withValues(alpha: .08), Theme.of(context).scaffoldBackgroundColor, cs.surface],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width >= 900 ? 460 : 420),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: width >= 600 ? 32 : 22, vertical: 30),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Center(child: Container(
                        width: 116, height: 116,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                        child: SvgPicture.asset('assets/brand/logo.svg', fit: BoxFit.contain),
                      )),
                      const SizedBox(height: 22),
                      Text('مرحباً بك', textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('سجّل الدخول للمتابعة إلى النظام الإداري الإعلامي', textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: .62))),
                      const SizedBox(height: 26),
                      TextField(
                        controller: _user,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم',
                          prefixIcon: Icon(Symbols.person),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _pass,
                        obscureText: _hide,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Symbols.lock),
                          suffixIcon: IconButton(
                            tooltip: _hide ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                            icon: Icon(_hide ? Symbols.visibility : Symbols.visibility_off),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: cs.error.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Symbols.error, color: cs.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: TextStyle(color: cs.error))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('تسجيل الدخول'),
                      ),
                      if (_bioReady) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _bioLogin,
                          icon: const Icon(Symbols.fingerprint),
                          label: const Text('الدخول بالبصمة'),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
