import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _navy = Color(0xFF091329);
const _panel = Color(0xFF111D37);
const _gold = Color(0xFFE2B968);
const _redirectUrl = 'com.kawn.library://login-callback/';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(const KawnLibraryApp());
}

bool get hasSupabase => const String.fromEnvironment('SUPABASE_URL').isNotEmpty &&
    const String.fromEnvironment('SUPABASE_ANON_KEY').isNotEmpty;

class KawnLibraryApp extends StatelessWidget {
  const KawnLibraryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'مكتبة الكون',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _navy,
          colorScheme: ColorScheme.fromSeed(seedColor: _gold, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: !hasSupabase
            ? const SetupRequiredPage()
            : const AuthGate(),
      );
}

class SetupRequiredPage extends StatelessWidget {
  const SetupRequiredPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/app_icon.png', width: 150, height: 150),
              const SizedBox(height: 20),
              const Text('مكتبة الكون', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _gold)),
              const SizedBox(height: 12),
              const Text('أضف SUPABASE_URL و SUPABASE_ANON_KEY لتفعيل التسجيل والدخول. لا تضع مفتاح service_role داخل التطبيق.', textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) return const UpdatePasswordPage();
          final session = Supabase.instance.client.auth.currentSession;
          if (session == null) return const AuthPage();
          if (session.user.emailConfirmedAt == null) return const VerifyEmailPage();
          return const ProfileGate();
        },
      );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  bool _obscure = true;
  String _role = 'reader';

  @override
  void dispose() { _email.dispose(); _password.dispose(); _name.dispose(); super.dispose(); }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await action(); }
    on AuthException catch (e) { _message(e.message); }
    catch (e) { _message('حدث خطأ غير متوقع: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.length < 8) {
      _message('أدخل بريداً صحيحاً وكلمة مرور من 8 أحرف على الأقل.'); return;
    }
    await _run(() async {
      final auth = Supabase.instance.client.auth;
      if (_signup) {
        await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          emailRedirectTo: _redirectUrl,
          data: {'display_name': _name.text.trim(), 'requested_role': _role},
        );
        _message('أرسلنا رسالة تحقق إلى بريدك الإلكتروني. افتحها لتفعيل الحساب.');
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
      }
    });
  }

  Future<void> _google() => _run(() async {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: _redirectUrl,
        );
      });

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) { _message('أدخل بريدك الإلكتروني أولاً.'); return; }
    await _run(() async {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _email.text.trim(), redirectTo: _redirectUrl,
      );
      _message('إذا كان البريد مسجلاً، ستصلك رسالة استعادة كلمة المرور.');
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(children: [
            Image.asset('assets/app_icon.png', width: 142, height: 142),
            const SizedBox(height: 8),
            const Text('مكتبة الكون', style: TextStyle(fontSize: 30, color: _gold, fontWeight: FontWeight.bold)),
            const Text('اقرأ • اكتب • ناقش • انشر', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 26),
            Card(color: _panel, child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
              Text(_signup ? 'إنشاء حساب جديد' : 'تسجيل الدخول', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              if (_signup) ...[
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم الظاهر', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: _role, decoration: const InputDecoration(labelText: 'نوع الحساب', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'reader', child: Text('قارئ')), DropdownMenuItem(value: 'writer', child: Text('كاتب'))], onChanged: (v) => setState(() => _role = v ?? 'reader')),
                const SizedBox(height: 8),
                const Align(alignment: Alignment.centerRight, child: Text('عضوية اللجنة تتطلب دعوة وموافقة الإدارة ولا يمكن اختيارها ذاتياً.', style: TextStyle(fontSize: 12, color: Colors.white60))),
                const SizedBox(height: 12),
              ],
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _password, obscureText: _obscure, autofillHints: [_signup ? AutofillHints.newPassword : AutofillHints.password], decoration: InputDecoration(labelText: 'كلمة المرور (8 أحرف على الأقل)', prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off)))),
              if (!_signup) Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: _busy ? null : _reset, child: const Text('نسيت كلمة المرور؟'))),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_signup ? 'إنشاء الحساب' : 'دخول'))),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _busy ? null : _google, icon: const Icon(Icons.g_mobiledata, size: 28), label: const Text('المتابعة باستخدام Google'))),
              TextButton(onPressed: _busy ? null : () => setState(() => _signup = !_signup), child: Text(_signup ? 'لديك حساب؟ تسجيل الدخول' : 'ليس لديك حساب؟ أنشئ حساباً')),
            ]))),
          ])),
        ))),
      );
}

class UpdatePasswordPage extends StatefulWidget {
  const UpdatePasswordPage({super.key});
  @override
  State<UpdatePasswordPage> createState() => _UpdatePasswordPageState();
}

class _UpdatePasswordPageState extends State<UpdatePasswordPage> {
  final _password = TextEditingController();
  bool _busy = false;
  @override
  void dispose() { _password.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_password.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور يجب أن تكون 8 أحرف على الأقل.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _password.text));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث كلمة المرور.')));
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.lock_reset, size: 58, color: _gold),
    const Text('تعيين كلمة مرور جديدة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    const SizedBox(height: 16),
    TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', border: OutlineInputBorder())),
    const SizedBox(height: 16),
    FilledButton(onPressed: _busy ? null : _save, child: _busy ? const CircularProgressIndicator() : const Text('حفظ كلمة المرور')),
  ]))));
}

class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({super.key});
  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.mark_email_read_outlined, size: 64, color: _gold),
      const SizedBox(height: 16),
      const Text('تحقق من بريدك الإلكتروني', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('أرسلنا رابط التفعيل إلى $email', textAlign: TextAlign.center),
      const SizedBox(height: 18),
      FilledButton(onPressed: () async { await Supabase.instance.client.auth.resend(type: OtpType.signup, email: email); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم طلب إعادة إرسال رسالة التحقق.'))); }, child: const Text('إعادة إرسال رسالة التحقق')),
      TextButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('تسجيل الخروج')),
    ]))));
  }
}

class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key});
  Future<Map<String, dynamic>?> _profile() async {
    final user = Supabase.instance.client.auth.currentUser!;
    final row = await Supabase.instance.client.from('profiles').select('display_name,role,preferred_language').eq('id', user.id).maybeSingle();
    return row;
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(future: _profile(), builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (snapshot.hasError) return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر تحميل الملف الشخصي. تأكد من تطبيق ملف SQL في Supabase.\n${snapshot.error}'))));
    final profile = snapshot.data;
    if (profile == null) return const Scaffold(body: Center(child: Text('لم يتم إنشاء الملف الشخصي. راجع إعداد قاعدة البيانات.')));
    return LibraryHomePage(name: profile['display_name'] as String? ?? '', role: profile['role'] as String? ?? 'reader');
  });
}

class LibraryHomePage extends StatelessWidget {
  const LibraryHomePage({super.key, required this.name, required this.role});
  final String name;
  final String role;
  @override
  Widget build(BuildContext context) {
    final isWriter = role == 'writer';
    final isCommittee = ['proofreader', 'critic', 'editor', 'committee_chair', 'admin'].contains(role);
    return Scaffold(
      appBar: AppBar(title: const Text('مكتبة الكون'), actions: [IconButton(tooltip: 'تسجيل الخروج', onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout))]),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF26375D), _panel]), border: Border.all(color: const Color(0x66E2B968))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.auto_stories, color: _gold, size: 42), const SizedBox(height: 12), Text('مرحباً ${name.isEmpty ? 'بك' : name}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 6), const Text('حيث تلتقي العقول بالمعرفة') ])),
        const SizedBox(height: 24),
        const Text('اكتشف عوالم جديدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const _BookTile(title: 'رحلة إلى المجهول', category: 'خيال ومغامرة', icon: Icons.travel_explore),
        const _BookTile(title: 'رسائل لم تصل', category: 'دراما ورومانسية', icon: Icons.mail_outline),
        const _BookTile(title: 'ما وراء النجوم', category: 'خيال علمي', icon: Icons.nights_stay),
        if (!isCommittee) const CommitteeRequestButton(),
        if (isWriter || isCommittee) ...[
          const SizedBox(height: 20),
          const Text('مساحة العمل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (isWriter) const ListTile(leading: Icon(Icons.edit_note, color: _gold), title: Text('استوديو الكاتب'), subtitle: Text('مساحة الكتابة ستُفعّل عند استكمال وحدة المخطوطات.')),
          if (isCommittee) const ListTile(leading: Icon(Icons.fact_check_outlined, color: _gold), title: Text('لجنة النشر'), subtitle: Text('لوحة المراجعة تتطلب تعييناً وصلاحية لجنة من الإدارة.')),
        ],
      ]),
    );
  }
}

class CommitteeRequestButton extends StatefulWidget {
  const CommitteeRequestButton({super.key});
  @override
  State<CommitteeRequestButton> createState() => _CommitteeRequestButtonState();
}

class _CommitteeRequestButtonState extends State<CommitteeRequestButton> {
  bool _busy = false;
  Future<void> _openRequest() async {
    String requestedRole = 'proofreader';
    final message = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('طلب الانضمام إلى لجنة النشر'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: requestedRole, decoration: const InputDecoration(labelText: 'التخصص'), items: const [
          DropdownMenuItem(value: 'proofreader', child: Text('مدقق لغوي')),
          DropdownMenuItem(value: 'critic', child: Text('ناقد أدبي')),
          DropdownMenuItem(value: 'editor', child: Text('محرر أدبي')),
        ], onChanged: (value) => setDialogState(() => requestedRole = value ?? 'proofreader')),
        const SizedBox(height: 12),
        TextField(controller: message, maxLines: 3, decoration: const InputDecoration(labelText: 'خبرتك أو سبب طلب الانضمام', border: OutlineInputBorder())),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إرسال الطلب'))],
    )));
    if (accepted != true || !mounted) { message.dispose(); return; }
    setState(() => _busy = true);
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      await Supabase.instance.client.from('role_requests').insert({
        'user_id': user.id,
        'requested_role': requestedRole,
        'message': message.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلبك. ستراجعه الإدارة قبل منح أي صلاحية.')));
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الطلب: ${e.message}')));
    } finally {
      message.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: OutlinedButton.icon(
      onPressed: _busy ? null : _openRequest,
      icon: const Icon(Icons.groups_outlined),
      label: Text(_busy ? 'جارٍ الإرسال...' : 'طلب الانضمام إلى لجنة النشر'),
    ),
  );
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.title, required this.category, required this.icon});
  final String title; final String category; final IconData icon;
  @override
  Widget build(BuildContext context) => Card(color: _panel, child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFF26375D), child: Icon(icon, color: _gold)), title: Text(title), subtitle: Text(category), trailing: const Icon(Icons.chevron_left)));
}
