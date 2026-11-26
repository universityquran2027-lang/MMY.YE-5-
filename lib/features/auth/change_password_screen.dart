import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../shell/home_shell.dart';
import 'auth_service.dart';
import 'biometric_service.dart';

/// شاشة إجبارية بعد أول دخول بحساب admin الافتراضي.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.app, required this.auth, required this.user, required this.bio, this.forced = false});
  final AppDatabase app;
  final AuthService auth;
  final BiometricService bio;
  final Map<String, Object?> user;
  final bool forced;
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _cur = TextEditingController(), _new = TextEditingController(), _conf = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    if (_new.text != _conf.text) {
      setState(() => _error = 'تأكيد كلمة المرور غير مطابق');
      return;
    }
    setState(() { _busy = true; _error = null; });
    final err = await widget.auth.changePassword(widget.user['id'] as String, _cur.text, _new.text);
    if (!mounted) return;
    if (err != null) {
      setState(() { _busy = false; _error = err; });
      return;
    }
    final fresh = (await widget.app.db.query('users', where: 'id = ?', whereArgs: [widget.user['id']])).first;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => HomeShell(app: widget.app, auth: widget.auth, bio: widget.bio, user: fresh)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forced, // لا خروج قبل تغيير كلمة المرور الافتراضية
      child: Scaffold(
        appBar: AppBar(title: const Text('تغيير كلمة المرور'), automaticallyImplyLeading: !widget.forced),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (widget.forced)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('هذه أول مرة تدخل فيها بكلمة المرور الافتراضية. اختر كلمة مرور قوية (8 خانات على الأقل، حروف وأرقام) للمتابعة.'),
                  ),
                TextField(controller: _cur, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الحالية')),
                const SizedBox(height: 12),
                TextField(controller: _new, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
                const SizedBox(height: 12),
                TextField(controller: _conf, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور الجديدة')),
                if (_error != null) Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _busy ? null : _save, child: const Text('حفظ ومتابعة')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
