import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const JVApp());
}

final FirebaseAuth auth = FirebaseAuth.instance;
final FirebaseFirestore db = FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: 'mora2',
);

class JVApp extends StatelessWidget {
  const JVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JV Líderes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A3EC5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE8EAF1)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD8DDEA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD8DDEA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6A3EC5), width: 1.5),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

String safeString(Map<String, dynamic> data, String key,
    [String fallback = '']) {
  final value = data[key];
  if (value == null) return fallback;
  return value.toString();
}

bool safeBool(Map<String, dynamic> data, String key, [bool fallback = false]) {
  final value = data[key];
  if (value is bool) return value;
  return fallback;
}

bool isAdmin(String role) => role == 'admin';

String _formatAnyDate(dynamic value) {
  if (value == null) return '';
  if (value is Timestamp) {
    return DateFormat('yyyy-MM-dd').format(value.toDate());
  }
  final raw = value.toString().trim();
  if (raw.isEmpty) return '';
  try {
    final dt = DateTime.parse(raw);
    return DateFormat('yyyy-MM-dd').format(dt);
  } catch (_) {
    return raw;
  }
}

DateTime? _extractDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  return _tryParseDateInput(value.toString());
}

DateTime? _tryParseDateInput(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
}

bool _isValidDateInput(String value) => _tryParseDateInput(value) != null;

List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortActivitiesByProximity(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final now = DateTime.now();
  final normalizedToday = DateTime(now.year, now.month, now.day);
  final sorted = docs.toList();

  sorted.sort((a, b) {
    final aDate = _extractDate(a.data()['fecha']);
    final bDate = _extractDate(b.data()['fecha']);

    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;

    final aDay = DateTime(aDate.year, aDate.month, aDate.day);
    final bDay = DateTime(bDate.year, bDate.month, bDate.day);
    final aPast = aDay.isBefore(normalizedToday);
    final bPast = bDay.isBefore(normalizedToday);

    if (aPast != bPast) return aPast ? 1 : -1;
    return aDay.compareTo(bDay);
  });

  return sorted;
}

String _formatRelativeActivityDate(dynamic value) {
  final date = _extractDate(value);
  if (date == null) return 'Fecha sin validar';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final difference = target.difference(today).inDays;

  if (difference == 0) return 'Hoy';
  if (difference == 1) return 'Mañana';
  if (difference > 1) return 'En $difference días';
  if (difference == -1) return 'Ayer';
  return 'Hace ${difference.abs()} días';
}

Future<void> _pickDateIntoController(
  BuildContext context,
  TextEditingController controller,
) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: _tryParseDateInput(controller.text) ?? DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (picked == null) return;
  controller.text = DateFormat('yyyy-MM-dd').format(picked);
}

String _activityStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'activa':
      return 'Activa';
    case 'cerrada':
      return 'Cerrada';
    case 'programada':
    default:
      return 'Programada';
  }
}

Color _activityStatusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'activa':
      return const Color(0xFF0F9D58);
    case 'cerrada':
      return const Color(0xFF6B7280);
    case 'programada':
    default:
      return const Color(0xFF6A3EC5);
  }
}

String _truncateText(String value, {int maxLength = 110}) {
  final clean = value.trim();
  if (clean.length <= maxLength) return clean;
  return '${clean.substring(0, maxLength).trimRight()}...';
}

List<List<T>> _chunkList<T>(List<T> items, int size) {
  final chunks = <List<T>>[];
  for (var i = 0; i < items.length; i += size) {
    final end = (i + size < items.length) ? i + size : items.length;
    chunks.add(items.sublist(i, end));
  }
  return chunks;
}

String _boolToSiNo(dynamic value) => value == true ? 'SI' : 'NO';

void _downloadBytes(Uint8List bytes, String filename) {
  if (!kIsWeb) return;
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}

class LeaderProfile {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String zone;
  final String status;

  const LeaderProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.zone,
    required this.status,
  });

  factory LeaderProfile.fromDoc(String uid, Map<String, dynamic> data) {
    return LeaderProfile(
      uid: uid,
      name: safeString(data, 'name', 'Usuario'),
      email: safeString(data, 'email'),
      role: safeString(data, 'role', 'leader'),
      zone: safeString(data, 'zone'),
      status: safeString(data, 'status', 'activo'),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<LeaderProfile?> _loadLeader(User user) async {
    final doc = await db.collection('leaders').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return null;
    return LeaderProfile.fromDoc(user.uid, data);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const SplashLoading();
        }

        final user = authSnap.data;
        if (user == null) return const LoginPage();

        return FutureBuilder<LeaderProfile?>(
          future: _loadLeader(user),
          builder: (context, leaderSnap) {
            if (leaderSnap.connectionState == ConnectionState.waiting) {
              return const SplashLoading();
            }

            final leader = leaderSnap.data;
            if (leader == null) {
              return const AccessDeniedPage(
                message:
                    'Tu usuario existe en Authentication, pero no tiene perfil de líder en Firestore.',
              );
            }

            if (leader.status.toLowerCase() != 'activo') {
              return const AccessDeniedPage(
                message:
                    'Tu cuenta está inactiva. Contacta al administrador para habilitar el acceso.',
              );
            }

            return HomeShell(currentUser: user, leader: leader);
          },
        );
      },
    );
  }
}

class SplashLoading extends StatelessWidget {
  const SplashLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class AccessDeniedPage extends StatelessWidget {
  final String message;
  const AccessDeniedPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 34,
                    child: Icon(Icons.lock_outline, size: 34),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Acceso restringido',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => auth.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  bool obscure = true;
  String? error;

  Future<void> _login() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await auth.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'No se pudo iniciar sesión.');
    } catch (_) {
      setState(() => error = 'Ocurrió un error inesperado.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        error =
            'Escribe primero un correo válido para enviarte el restablecimiento.';
      });
      return;
    }

    try {
      await auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Te enviamos un correo para restablecer tu contraseña.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message ?? 'No se pudo enviar el correo de recuperación.';
      });
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F1FF), Color(0xFFF7FAFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: mobile
                    ? _loginCard(context, mobile: true)
                    : Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: _BrandPanel(),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(child: _loginCard(context)),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginCard(BuildContext context, {bool mobile = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mobile) ...[
                const Center(
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF6A3EC5),
                    child: Icon(Icons.groups_rounded,
                        color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Bienvenido',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa para gestionar líderes, jóvenes, actividades y asistencias.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Ingresa tu correo.';
                  if (!value.contains('@')) return 'Ingresa un correo válido.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return 'Ingresa tu contraseña.';
                  if ((v ?? '').length < 6) {
                    return 'Debe tener al menos 6 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _resetPassword,
                  child: const Text('Olvidé mi contraseña'),
                ),
              ),
              if (error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loading ? null : _login,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(loading ? 'Ingresando...' : 'Entrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            CircleAvatar(
              radius: 34,
              backgroundColor: Color(0xFF6A3EC5),
              child: Icon(Icons.groups_rounded, color: Colors.white, size: 34),
            ),
            SizedBox(height: 24),
            Text(
              'JV Líderes',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 12),
            Text(
              'Una plataforma moderna para administrar líderes, jóvenes, actividades y asistencias desde cualquier dispositivo.',
              style: TextStyle(fontSize: 17, height: 1.5),
            ),
            SizedBox(height: 26),
            _FeatureRow(
              icon: Icons.phone_iphone,
              text: 'Experiencia optimizada para móvil',
            ),
            SizedBox(height: 12),
            _FeatureRow(
              icon: Icons.security,
              text: 'Permisos por rol: admin y líder',
            ),
            SizedBox(height: 12),
            _FeatureRow(
              icon: Icons.analytics_outlined,
              text: 'Dashboard y seguimiento en tiempo real',
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFEDE6FF),
          child: Icon(icon, size: 18, color: Color(0xFF6A3EC5)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class HomeShell extends StatefulWidget {
  final User currentUser;
  final LeaderProfile leader;

  const HomeShell({
    super.key,
    required this.currentUser,
    required this.leader,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selectedIndex = 0;

  List<_MenuItem> get _items {
    final all = [
      const _MenuItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
      const _MenuItem(
          'Líderes', Icons.manage_accounts_outlined, Icons.manage_accounts),
      const _MenuItem('Registros', Icons.list_alt_outlined, Icons.list_alt),
      const _MenuItem('Reportes', Icons.bar_chart_outlined, Icons.bar_chart),
      const _MenuItem('Jóvenes', Icons.groups_outlined, Icons.groups),
      const _MenuItem(
          'Actividades', Icons.event_note_outlined, Icons.event_note),
      const _MenuItem('Configuración', Icons.settings_outlined, Icons.settings),
    ];

    if (isAdmin(widget.leader.role)) return all;

    return [
      all[0],
      all[2],
      all[3],
      all[4],
      all[5],
      all[6],
    ];
  }

  List<Widget> _pages() {
    final all = [
      DashboardPage(currentUser: widget.currentUser, leader: widget.leader),
      LeadersPage(currentUser: widget.currentUser, leader: widget.leader),
      RegistrosPage(currentUser: widget.currentUser, leader: widget.leader),
      ReportesPage(currentUser: widget.currentUser, leader: widget.leader),
      JovenesPage(currentUser: widget.currentUser, leader: widget.leader),
      ActividadesPage(currentUser: widget.currentUser, leader: widget.leader),
      ConfiguracionPage(currentUser: widget.currentUser, leader: widget.leader),
    ];

    if (isAdmin(widget.leader.role)) return all;

    return [
      all[0],
      all[2],
      all[3],
      all[4],
      all[5],
      all[6],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final mobile = width < 760;
    final tablet = width >= 760 && width < 1100;
    final useRail = !mobile;
    final railExtended = width >= 1320;
    final pages = _pages();

    return Scaffold(
      appBar: AppBar(
        title: Text(_items[selectedIndex].title),
        actions: [
          if (!mobile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Chip(
                  avatar: const Icon(Icons.verified_user, size: 18),
                  label: Text(
                    isAdmin(widget.leader.role) ? 'Administrador' : 'Líder',
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: useRail
          ? null
          : Drawer(
              child: _MobileDrawer(
                items: _items,
                currentIndex: selectedIndex,
                leader: widget.leader,
                onSelect: (i) {
                  Navigator.pop(context);
                  setState(() => selectedIndex = i);
                },
              ),
            ),
      bottomNavigationBar: null,
      body: Row(
        children: [
          if (useRail)
            Container(
              width: railExtended ? 280 : (tablet ? 88 : 96),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Color(0xFFE8EAF1)),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _SidebarBrand(
                        extended: railExtended,
                        leader: widget.leader,
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: NavigationRail(
                          selectedIndex: selectedIndex,
                          onDestinationSelected: (i) {
                            setState(() => selectedIndex = i);
                          },
                          extended: railExtended,
                          labelType: railExtended
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
                          leading: const SizedBox.shrink(),
                          destinations: _items
                              .map(
                                (e) => NavigationRailDestination(
                                  icon: Icon(e.icon),
                                  selectedIcon: Icon(e.selectedIcon),
                                  label: Text(e.title),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(mobile ? 12 : 18),
                child: pages[selectedIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  final List<_MenuItem> items;
  final int currentIndex;
  final LeaderProfile leader;
  final void Function(int index) onSelect;

  const _MobileDrawer({
    required this.items,
    required this.currentIndex,
    required this.leader,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFF6A3EC5),
                    child: Icon(Icons.groups, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'JV Líderes',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          leader.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < items.length; i++)
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              selected: currentIndex == i,
              leading: Icon(
                currentIndex == i ? items[i].selectedIcon : items[i].icon,
              ),
              title: Text(items[i].title),
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  final bool extended;
  final LeaderProfile leader;

  const _SidebarBrand({
    required this.extended,
    required this.leader,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(extended ? 18 : 12),
        child: extended
            ? Column(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFF6A3EC5),
                    child: Icon(Icons.groups, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'JV Líderes',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    leader.name,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Chip(
                    label: Text(
                      isAdmin(leader.role) ? 'Administrador' : 'Líder',
                    ),
                  ),
                ],
              )
            : const Center(
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFF6A3EC5),
                  child: Icon(Icons.groups, color: Colors.white),
                ),
              ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final IconData selectedIcon;

  const _MenuItem(this.title, this.icon, this.selectedIcon);
}

class DashboardPage extends StatelessWidget {
  final User currentUser;
  final LeaderProfile leader;

  const DashboardPage({
    super.key,
    required this.currentUser,
    required this.leader,
  });

  Query<Map<String, dynamic>> _queryFor(String collection) {
    if (isAdmin(leader.role)) return db.collection(collection);
    return db
        .collection(collection)
        .where('leaderId', isEqualTo: currentUser.uid);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _leadersMetricStream() {
    if (isAdmin(leader.role)) {
      return db.collection('leaders').snapshots();
    }
    return db
        .collection('leaders')
        .where(FieldPath.documentId, isEqualTo: currentUser.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final mobile = width < 900;

    return SingleChildScrollView(
      child: Column(
        children: [
          _WelcomeHeader(leader: leader),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _MetricCard(
                width: mobile ? double.infinity : 250,
                title: 'Líderes',
                icon: Icons.manage_accounts,
                stream: _leadersMetricStream(),
              ),
              _MetricCard(
                width: mobile ? double.infinity : 250,
                title: 'Reportes',
                icon: Icons.assessment,
                stream: _queryFor('reportes').snapshots(),
              ),
              _MetricCard(
                width: mobile ? double.infinity : 250,
                title: 'Jóvenes',
                icon: Icons.groups,
                stream: _queryFor('jovenes').snapshots(),
              ),
              _MetricCard(
                width: mobile ? double.infinity : 250,
                title: 'Actividades',
                icon: Icons.event_note,
                stream: db.collection('actividades').snapshots(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (mobile) ...[
            _Panel(
              title: 'Jóvenes por líder',
              child: _YoungPeopleByLeaderChart(
                currentUser: currentUser,
                leader: leader,
              ),
            ),
            const SizedBox(height: 16),
            const _Panel(
              title: 'Estado de actividades',
              child: _ActivityStatusPanel(),
            ),
            const SizedBox(height: 16),
            _Panel(
              title: isAdmin(leader.role) ? 'Líderes recientes' : 'Mi perfil',
              child: isAdmin(leader.role)
                  ? const _RecentLeadersPanel()
                  : _LeaderSummaryPanel(leader: leader),
            ),
            if (isAdmin(leader.role)) ...[
              const SizedBox(height: 16),
              const _Panel(
                title: 'Actividades recientes',
                child: _RecentActivitiesPanel(),
              ),
            ],
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _Panel(
                    title: 'Jóvenes por líder',
                    child: _YoungPeopleByLeaderChart(
                      currentUser: currentUser,
                      leader: leader,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _Panel(
                    title: 'Estado de actividades',
                    child: const _ActivityStatusPanel(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Panel(
                    title: isAdmin(leader.role)
                        ? 'Líderes recientes'
                        : 'Mi perfil',
                    child: isAdmin(leader.role)
                        ? const _RecentLeadersPanel()
                        : _LeaderSummaryPanel(leader: leader),
                  ),
                ),
                if (isAdmin(leader.role)) ...[
                  const SizedBox(width: 16),
                  const Expanded(
                    flex: 2,
                    child: _Panel(
                      title: 'Actividades recientes',
                      child: _RecentActivitiesPanel(),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 16),
          _Panel(
            title: isAdmin(leader.role)
                ? 'Asistencia por actividad'
                : 'Asistencia',
            child: isAdmin(leader.role)
                ? const _AttendanceByActivityPanel()
                : const _LeaderAttendanceHint(),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  final LeaderProfile leader;

  const _WelcomeHeader({required this.leader});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFEDE6FF),
              child: Icon(Icons.waving_hand_rounded, color: Color(0xFF6A3EC5)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, ${leader.name}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAdmin(leader.role)
                        ? 'Tienes acceso completo al sistema.'
                        : 'Aquí puedes gestionar tus jóvenes, reportes y asistencias.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.verified_user, size: 18),
                        label: Text(
                          isAdmin(leader.role) ? 'Administrador' : 'Líder',
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.place_outlined, size: 18),
                        label: Text(
                          leader.zone.isEmpty ? 'Sin zona' : leader.zone,
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.shield_outlined, size: 18),
                        label: Text(
                          leader.status.isEmpty ? 'Sin estado' : leader.status,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String title;
  final IconData icon;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  const _MetricCard({
    required this.width,
    required this.title,
    required this.icon,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width == double.infinity ? null : width,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: width == double.infinity ? 0 : width,
          maxWidth: width == double.infinity ? double.infinity : width,
        ),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFFFF1F1),
                        child: Icon(icon, color: Colors.red.shade400),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'No disponible',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  );
                }
                final count = snap.data?.docs.length ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFEDE6FF),
                      child: Icon(icon, color: const Color(0xFF6A3EC5)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _YoungPeopleByLeaderChart extends StatelessWidget {
  final User currentUser;
  final LeaderProfile leader;

  const _YoungPeopleByLeaderChart({
    required this.currentUser,
    required this.leader,
  });

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream =
        isAdmin(leader.role)
            ? db.collection('jovenes').snapshots()
            : db
                .collection('jovenes')
                .where('leaderId', isEqualTo: currentUser.uid)
                .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const _EmptyData('No se pudieron cargar los jóvenes.');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _EmptyData('No hay jóvenes registrados.');
        }

        final Map<String, int> counts = {};
        for (final d in docs) {
          final leaderId = safeString(d.data(), 'leaderId', currentUser.uid);
          counts[leaderId] = (counts[leaderId] ?? 0) + 1;
        }

        if (!isAdmin(leader.role)) {
          counts
            ..clear()
            ..[currentUser.uid] = docs.length;
        }

        if (!isAdmin(leader.role)) {
          final total = counts[currentUser.uid] ?? docs.length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 120,
                      child: Text(
                        'Tus jóvenes',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : 1,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$total',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return FutureBuilder<Map<String, String>>(
          future: fetchLeaderNames(),
          builder: (context, namesSnap) {
            if (namesSnap.hasError) {
              return const _EmptyData('No se pudieron cargar los líderes.');
            }
            if (!namesSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final names = namesSnap.data!;
            final entries = counts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final maxValue = entries.first.value == 0 ? 1 : entries.first.value;

            return Column(
              children: entries.map((e) {
                final label = isAdmin(leader.role)
                    ? (names[e.key] ?? 'Sin líder')
                    : 'Tus jóvenes';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: e.value / maxValue,
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${e.value}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _RecentLeadersPanel extends StatelessWidget {
  const _RecentLeadersPanel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('leaders').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _EmptyData('No se pudieron cargar los líderes.');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = [...snap.data!.docs];
        docs.sort((a, b) {
          final aTs = a.data()['createdAt'];
          final bTs = b.data()['createdAt'];
          if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
          return 0;
        });

        final recent = docs.take(6).toList();
        if (recent.isEmpty) {
          return const _EmptyData('No hay líderes registrados.');
        }

        return Column(
          children: recent.map((d) {
            final data = d.data();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(safeString(data, 'name', 'Sin nombre')),
              subtitle: Text(
                '${safeString(data, "zone", "Sin zona")} · ${safeString(data, "role", "leader")}',
              ),
              trailing: Chip(label: Text(safeString(data, 'status', 'activo'))),
            );
          }).toList(),
        );
      },
    );
  }
}

class _LeaderSummaryPanel extends StatelessWidget {
  final LeaderProfile leader;

  const _LeaderSummaryPanel({required this.leader});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(leader.name),
          subtitle: Text(
            '${leader.email.isEmpty ? 'Sin correo' : leader.email} · ${leader.zone.isEmpty ? 'Sin zona' : leader.zone}',
          ),
          trailing: Chip(label: Text(leader.status)),
        ),
      ],
    );
  }
}

class _ActivityStatusPanel extends StatelessWidget {
  const _ActivityStatusPanel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('actividades').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _EmptyData('No se pudieron cargar las actividades.');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        final total = docs.length;
        final activas = docs
            .where((e) => safeString(e.data(), 'estado') == 'activa')
            .length;
        final programadas = docs
            .where((e) => safeString(e.data(), 'estado') == 'programada')
            .length;
        final cerradas = docs
            .where((e) => safeString(e.data(), 'estado') == 'cerrada')
            .length;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MiniStatCard(
              label: 'Total',
              value: '$total',
              color: const Color(0xFF6A3EC5),
            ),
            _MiniStatCard(
              label: 'Activas',
              value: '$activas',
              color: const Color(0xFF0F9D58),
            ),
            _MiniStatCard(
              label: 'Programadas',
              value: '$programadas',
              color: const Color(0xFF2563EB),
            ),
            _MiniStatCard(
              label: 'Cerradas',
              value: '$cerradas',
              color: const Color(0xFF6B7280),
            ),
          ],
        );
      },
    );
  }
}

class _RecentActivitiesPanel extends StatelessWidget {
  const _RecentActivitiesPanel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('actividades').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _EmptyData('No se pudieron cargar las actividades.');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs =
            _sortActivitiesByProximity(snap.data!.docs).take(5).toList();
        if (docs.isEmpty) {
          return const _EmptyData('No hay actividades registradas.');
        }

        return Column(
          children: docs.map((d) {
            final data = d.data();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEDE6FF),
                child: Icon(
                  Icons.event_note,
                  color: _activityStatusColor(safeString(data, 'estado')),
                ),
              ),
              title: Text(
                safeString(data, 'nombre', 'Actividad'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${_formatAnyDate(data["fecha"])} · ${_truncateText(safeString(data, "descripcion", "Sin descripción"), maxLength: 60)}',
              ),
              trailing: _ActivityStatusChip(
                status: safeString(data, 'estado', 'programada'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _AttendanceByActivityPanel extends StatelessWidget {
  const _AttendanceByActivityPanel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('actividades').snapshots(),
      builder: (context, actSnap) {
        if (actSnap.hasError) {
          return const _EmptyData('No se pudieron cargar las actividades.');
        }
        if (!actSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final acts = actSnap.data!.docs;
        if (acts.isEmpty) {
          return const _EmptyData('No hay actividades registradas.');
        }

        return FutureBuilder<List<_ActivityAttendanceSummary>>(
          future: _loadActivityAttendanceSummaries(acts),
          builder: (context, sumSnap) {
            if (sumSnap.hasError) {
              return const _EmptyData('No se pudo cargar la asistencia.');
            }
            if (!sumSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = sumSnap.data!;
            if (list.isEmpty) {
              return const _EmptyData('Aún no hay asistencias registradas.');
            }

            return Column(
              children: list.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.activityName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(
                          value: e.total == 0 ? 0 : e.attended / e.total,
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('${e.attended}/${e.total}'),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _LeaderAttendanceHint extends StatelessWidget {
  const _LeaderAttendanceHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(18),
      child: Text(
        'Para revisar y marcar asistencia, entra a Actividades y abre la actividad correspondiente.',
        style: TextStyle(color: Colors.black54),
      ),
    );
  }
}

Future<Map<String, String>> fetchLeaderNames() async {
  final snapshot = await db.collection('leaders').get();
  return {
    for (final d in snapshot.docs)
      d.id: safeString(d.data(), 'name', 'Sin nombre'),
  };
}

class _ActivityAttendanceSummary {
  final String activityName;
  final int attended;
  final int total;

  _ActivityAttendanceSummary({
    required this.activityName,
    required this.attended,
    required this.total,
  });
}

Future<List<_ActivityAttendanceSummary>> _loadActivityAttendanceSummaries(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> acts,
) async {
  final asistenciaSnap = await db.collection('asistencias').get();
  final totalsByActivity = <String, int>{};
  final attendedByActivity = <String, int>{};

  for (final doc in asistenciaSnap.docs) {
    final data = doc.data();
    final activityId = safeString(data, 'activityId');
    if (activityId.isEmpty) continue;
    totalsByActivity[activityId] = (totalsByActivity[activityId] ?? 0) + 1;
    if (data['attended'] == true) {
      attendedByActivity[activityId] =
          (attendedByActivity[activityId] ?? 0) + 1;
    }
  }

  final out = <_ActivityAttendanceSummary>[];
  for (final act in acts) {
    out.add(
      _ActivityAttendanceSummary(
        activityName: safeString(act.data(), 'nombre', 'Actividad'),
        attended: attendedByActivity[act.id] ?? 0,
        total: totalsByActivity[act.id] ?? 0,
      ),
    );
  }
  out.sort((a, b) => b.attended.compareTo(a.attended));
  return out;
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStatusChip extends StatelessWidget {
  final String status;

  const _ActivityStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _activityStatusColor(status);
    return Chip(
      side: BorderSide(color: color.withOpacity(.18)),
      backgroundColor: color.withOpacity(.08),
      label: Text(
        _activityStatusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActivityHeroCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>>? nextActivity;
  final int upcomingCount;

  const _ActivityHeroCard({
    required this.nextActivity,
    required this.upcomingCount,
  });

  @override
  Widget build(BuildContext context) {
    final data = nextActivity?.data() ?? const <String, dynamic>{};
    final status = safeString(data, 'estado', 'programada');
    final title = safeString(data, 'nombre', 'Sin actividades cercanas');
    final description = safeString(
      data,
      'descripcion',
      upcomingCount == 0
          ? 'Todavía no hay actividades próximas registradas.'
          : 'Revisa la programación para confirmar detalles.',
    );
    final relativeDate = nextActivity == null
        ? 'Agenda pendiente'
        : _formatRelativeActivityDate(data['fecha']);
    final exactDate = nextActivity == null ? '' : _formatAnyDate(data['fecha']);
    final color = _activityStatusColor(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFFFFF),
            color.withOpacity(.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(.16)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.event_available, color: color, size: 34),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Próxima actividad destacada',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _truncateText(description, maxLength: 180),
                  style: const TextStyle(
                    color: Colors.black87,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActivityInfoPill(
                icon: Icons.schedule,
                label: relativeDate,
                tone: color,
              ),
              if (exactDate.isNotEmpty)
                _ActivityInfoPill(
                  icon: Icons.calendar_today_outlined,
                  label: exactDate,
                  tone: const Color(0xFF2563EB),
                ),
              _ActivityInfoPill(
                icon: Icons.upcoming_outlined,
                label: '$upcomingCount próximas',
                tone: const Color(0xFF0F9D58),
              ),
              if (nextActivity != null) _ActivityStatusChip(status: status),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tone;

  const _ActivityInfoPill({
    required this.icon,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withOpacity(.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyData extends StatelessWidget {
  final String message;

  const _EmptyData(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Text(
        message,
        style: const TextStyle(color: Colors.black54),
      ),
    );
  }
}

class _RoleLockedCard extends StatelessWidget {
  final String message;

  const _RoleLockedCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class LeadersPage extends StatelessWidget {
  final User currentUser;
  final LeaderProfile leader;

  const LeadersPage({
    super.key,
    required this.currentUser,
    required this.leader,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAdmin(leader.role)) {
      return const _RoleLockedCard(
        message: 'Solo el administrador puede gestionar líderes.',
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _showLeaderDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo líder'),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Card(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.collection('leaders').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = [...snap.data!.docs];
                docs.sort((a, b) {
                  final aTs = a.data()['createdAt'];
                  final bTs = b.data()['createdAt'];
                  if (aTs is Timestamp && bTs is Timestamp) {
                    return bTs.compareTo(aTs);
                  }
                  return 0;
                });

                if (docs.isEmpty) {
                  return const Center(child: Text('No hay líderes.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(safeString(data, 'name', 'Sin nombre')),
                      subtitle: Text(
                        '${safeString(data, "email")} · Zona: ${safeString(data, "zone", "Sin zona")}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text(safeString(data, 'role', 'leader'))),
                          IconButton(
                            onPressed: () => _showLeaderDialog(
                              context,
                              docId: d.id,
                              initial: data,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () =>
                                _deleteDoc('leaders', d.id, context),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showLeaderDialog(
  BuildContext context, {
  String? docId,
  Map<String, dynamic>? initial,
}) async {
  final formKey = GlobalKey<FormState>();
  final data = initial ?? {};
  final uidCtrl = TextEditingController(text: docId ?? '');
  final nameCtrl = TextEditingController(text: safeString(data, 'name'));
  final emailCtrl = TextEditingController(text: safeString(data, 'email'));
  final zoneCtrl = TextEditingController(text: safeString(data, 'zone'));
  final reportsCtrl = TextEditingController(
    text: safeString(data, 'reports', '0'),
  );
  String status = safeString(data, 'status', 'activo');
  String role = safeString(data, 'role', 'leader');

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(docId == null ? 'Nuevo líder' : 'Editar líder'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (docId == null) ...[
                  TextFormField(
                    controller: uidCtrl,
                    decoration: const InputDecoration(
                      labelText: 'UID del usuario en Authentication',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Requerido.' : null,
                  ),
                  const SizedBox(height: 10),
                ],
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Requerido.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Correo'),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Requerido.';
                    if (!value.contains('@')) return 'Correo inválido.';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: zoneCtrl,
                  decoration: const InputDecoration(labelText: 'Zona'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Requerido.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: reportsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reports'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'activo', child: Text('activo')),
                    DropdownMenuItem(
                        value: 'inactivo', child: Text('inactivo')),
                  ],
                  onChanged: (v) => status = v ?? 'activo',
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                    DropdownMenuItem(value: 'leader', child: Text('leader')),
                  ],
                  onChanged: (v) => role = v ?? 'leader',
                  decoration: const InputDecoration(labelText: 'Rol'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;

            final targetDocId = docId ?? uidCtrl.text.trim();

            final payload = {
              'name': nameCtrl.text.trim(),
              'email': emailCtrl.text.trim(),
              'zone': zoneCtrl.text.trim(),
              'status': status,
              'reports': int.tryParse(reportsCtrl.text.trim()) ?? 0,
              'role': role,
              'createdAt':
                  initial?['createdAt'] ?? FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            };

            await db.collection('leaders').doc(targetDocId).set(
                  payload,
                  SetOptions(merge: true),
                );

            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

class RegistrosPage extends StatelessWidget {
  final User currentUser;
  final LeaderProfile leader;

  const RegistrosPage({
    super.key,
    required this.currentUser,
    required this.leader,
  });

  Query<Map<String, dynamic>> _query() {
    final base = db.collection('registros');
    if (isAdmin(leader.role)) {
      return base.orderBy('createdAt', descending: true);
    }
    // Puede requerir indice compuesto en Firestore.
    return base
        .where('leaderId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return CrudCollectionPage(
      title: 'Registros',
      collection: 'registros',
      stream: _query().snapshots(),
      fields: const [
        CrudField('titulo', 'Título'),
        CrudField('descripcion', 'Descripción', maxLines: 3),
      ],
      currentUser: currentUser,
    );
  }
}

class ReportesPage extends StatelessWidget {
  final User currentUser;
  final LeaderProfile leader;

  const ReportesPage({
    super.key,
    required this.currentUser,
    required this.leader,
  });

  Query<Map<String, dynamic>> _query() {
    final base = db.collection('reportes');
    if (isAdmin(leader.role)) {
      return base.orderBy('fecha', descending: true);
    }
    // Puede requerir indice compuesto en Firestore.
    return base
        .where('leaderId', isEqualTo: currentUser.uid)
        .orderBy('fecha', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return CrudCollectionPage(
      title: 'Reportes',
      collection: 'reportes',
      stream: _query().snapshots(),
      fields: const [
        CrudField('semana', 'Semana'),
        CrudField('asistencia', 'Asistencia',
            keyboardType: TextInputType.number),
        CrudField('observaciones', 'Observaciones', maxLines: 3),
      ],
      currentUser: currentUser,
    );
  }
}

class CrudField {
  final String key;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  const CrudField(
    this.key,
    this.label, {
    this.maxLines = 1,
    this.keyboardType,
  });
}

class CrudCollectionPage extends StatelessWidget {
  final String title;
  final String collection;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final List<CrudField> fields;
  final User currentUser;

  const CrudCollectionPage({
    super.key,
    required this.title,
    required this.collection,
    required this.stream,
    required this.fields,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _showCrudDialog(
              context,
              collection: collection,
              fields: fields,
              currentUser: currentUser,
            ),
            icon: const Icon(Icons.add),
            label: Text('Nuevo $title'),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Card(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(child: Text('No hay $title.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();
                    return ListTile(
                      title: Text(
                        safeString(data, fields.first.key, 'Sin título'),
                      ),
                      subtitle: Text(
                        fields
                            .skip(1)
                            .map(
                                (f) => '${f.label}: ${safeString(data, f.key)}')
                            .join(' · '),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            onPressed: () => _showCrudDialog(
                              context,
                              collection: collection,
                              fields: fields,
                              currentUser: currentUser,
                              docId: d.id,
                              initial: data,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () =>
                                _deleteDoc(collection, d.id, context),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showCrudDialog(
  BuildContext context, {
  required String collection,
  required List<CrudField> fields,
  required User currentUser,
  String? docId,
  Map<String, dynamic>? initial,
}) async {
  final formKey = GlobalKey<FormState>();
  final ctrls = {
    for (final f in fields)
      f.key: TextEditingController(
        text: safeString(initial ?? {}, f.key),
      ),
  };

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(docId == null ? 'Nuevo registro' : 'Editar registro'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              children: fields.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: ctrls[f.key],
                    maxLines: f.maxLines,
                    keyboardType: f.keyboardType,
                    decoration: InputDecoration(labelText: f.label),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Requerido.' : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final payload = <String, dynamic>{};
            for (final f in fields) {
              final raw = ctrls[f.key]!.text.trim();
              payload[f.key] = f.keyboardType == TextInputType.number
                  ? (int.tryParse(raw) ?? 0)
                  : raw;
            }
            payload['leaderId'] = initial?['leaderId'] ?? currentUser.uid;
            payload['createdAt'] =
                initial?['createdAt'] ?? FieldValue.serverTimestamp();
            payload['updatedAt'] = FieldValue.serverTimestamp();

            if (docId == null) {
              await db.collection(collection).add(payload);
            } else {
              await db.collection(collection).doc(docId).set(
                    payload,
                    SetOptions(merge: true),
                  );
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

class JovenesPage extends StatefulWidget {
  final User currentUser;
  final LeaderProfile leader;

  const JovenesPage({
    super.key,
    required this.currentUser,
    required this.leader,
  });

  @override
  State<JovenesPage> createState() => _JovenesPageState();
}

class _JovenesPageState extends State<JovenesPage> {
  String search = '';

  Query<Map<String, dynamic>> _query() {
    final base = db.collection('jovenes');
    if (isAdmin(widget.leader.role)) {
      return base.orderBy('createdAt', descending: true);
    }
    // Puede requerir indice compuesto en Firestore.
    return base
        .where('leaderId', isEqualTo: widget.currentUser.uid)
        .orderBy('createdAt', descending: true);
  }

  Future<void> _exportJovenesXlsx({String? leaderId}) async {
    Query<Map<String, dynamic>> query = db.collection('jovenes');

    if (leaderId != null) {
      query = query.where('leaderId', isEqualTo: leaderId);
    } else if (!isAdmin(widget.leader.role)) {
      query = query.where('leaderId', isEqualTo: widget.currentUser.uid);
    }

    final snap = await query.get();

    final excel = Excel.createExcel();
    final sheet = excel['Jovenes'];

    final headers = [
      'Nombre y apellido',
      'Edad',
      'Fecha de nacimiento',
      'Telefono',
      'Clase Nuevo',
      'Clase Doctrina',
      'Clase Maestro',
      'Clase Liderazgo',
      'Bautismo',
      'LeaderId',
    ];

    for (int c = 0; c < headers.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(headers[c]);
    }

    for (int i = 0; i < snap.docs.length; i++) {
      final d = snap.docs[i].data();
      final row = i + 1;
      final values = [
        safeString(d, 'nombre'),
        safeString(d, 'edad'),
        _formatAnyDate(d['fechaNacimiento']),
        safeString(d, 'telefono'),
        _boolToSiNo(d['claseNuevo']),
        _boolToSiNo(d['claseDoctrina']),
        _boolToSiNo(d['claseMaestro']),
        _boolToSiNo(d['claseLiderazgo']),
        _boolToSiNo(d['bautismo']),
        safeString(d, 'leaderId'),
      ];

      for (int c = 0; c < values.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
            .value = TextCellValue(values[c]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final fileName = leaderId == null
        ? (isAdmin(widget.leader.role)
            ? 'jovenes_todos.xlsx'
            : 'jovenes_mis_registros.xlsx')
        : 'jovenes_${leaderId}_export.xlsx';

    _downloadBytes(Uint8List.fromList(bytes), fileName);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exportación generada: $fileName')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 900;

    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          children: [
            SizedBox(
              width: mobile ? double.infinity : 320,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar joven...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) =>
                    setState(() => search = v.toLowerCase().trim()),
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _exportJovenesXlsx(),
                  icon: const Icon(Icons.download),
                  label: Text(
                    isAdmin(widget.leader.role)
                        ? 'Exportar .xlsx'
                        : 'Exportar mis jóvenes',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showJovenDialog(
                    context,
                    currentUser: widget.currentUser,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo joven'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Card(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snap.data!.docs;
                if (search.isNotEmpty) {
                  docs = docs.where((d) {
                    final name = safeString(d.data(), 'nombre').toLowerCase();
                    return name.contains(search);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(child: Text('No hay jóvenes.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 22),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();

                    if (mobile) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                safeString(data, 'nombre'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Edad: ${safeString(data, "edad")} · Tel: ${safeString(data, "telefono")}',
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  _ActionIcon(
                                    icon: Icons.history,
                                    tooltip: 'Historial',
                                    onTap: () =>
                                        _openHistory(context, d.id, data),
                                  ),
                                  if (isAdmin(widget.leader.role))
                                    _ActionIcon(
                                      icon: Icons.file_download_outlined,
                                      tooltip: 'Exportar por líder',
                                      onTap: () => _exportJovenesXlsx(
                                        leaderId: safeString(data, 'leaderId'),
                                      ),
                                    ),
                                  _ActionIcon(
                                    icon: Icons.edit_outlined,
                                    tooltip: 'Editar',
                                    onTap: () => _showJovenDialog(
                                      context,
                                      currentUser: widget.currentUser,
                                      docId: d.id,
                                      initial: data,
                                    ),
                                  ),
                                  _ActionIcon(
                                    icon: Icons.delete_outline,
                                    tooltip: 'Eliminar',
                                    onTap: () =>
                                        _deleteDoc('jovenes', d.id, context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListTile(
                      title: Text(
                        safeString(data, 'nombre'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        'Edad: ${safeString(data, "edad")} · Tel: ${safeString(data, "telefono")}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Historial',
                            onPressed: () => _openHistory(context, d.id, data),
                            icon: const Icon(Icons.history),
                          ),
                          if (isAdmin(widget.leader.role))
                            IconButton(
                              tooltip: 'Exportar por líder',
                              onPressed: () => _exportJovenesXlsx(
                                leaderId: safeString(data, 'leaderId'),
                              ),
                              icon: const Icon(Icons.file_download_outlined),
                            ),
                          IconButton(
                            onPressed: () => _showJovenDialog(
                              context,
                              currentUser: widget.currentUser,
                              docId: d.id,
                              initial: data,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () =>
                                _deleteDoc('jovenes', d.id, context),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _openHistory(
      BuildContext context, String jovenId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistorialJovenPage(
          jovenId: jovenId,
          jovenNombre: safeString(data, 'nombre', 'Joven'),
          currentUser: widget.currentUser,
          leader: widget.leader,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon),
    );
  }
}

Future<void> _showJovenDialog(
  BuildContext context, {
  required User currentUser,
  String? docId,
  Map<String, dynamic>? initial,
}) async {
  final formKey = GlobalKey<FormState>();
  final data = initial ?? {};
  final nombreCtrl = TextEditingController(text: safeString(data, 'nombre'));
  final edadCtrl = TextEditingController(text: safeString(data, 'edad'));
  final fechaCtrl = TextEditingController(
    text: _formatAnyDate(data['fechaNacimiento']),
  );
  final telCtrl = TextEditingController(text: safeString(data, 'telefono'));
  bool claseNuevo = safeBool(data, 'claseNuevo');
  bool claseDoctrina = safeBool(data, 'claseDoctrina');
  bool claseMaestro = safeBool(data, 'claseMaestro');
  bool claseLiderazgo = safeBool(data, 'claseLiderazgo');
  bool bautismo = safeBool(data, 'bautismo');

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) {
        return AlertDialog(
          title: Text(docId == null ? 'Nuevo joven' : 'Editar joven'),
          content: SizedBox(
            width: 600,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre y apellido',
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Requerido.' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: edadCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Edad'),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null) return 'Ingresa una edad válida.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: fechaCtrl,
                      readOnly: true,
                      onTap: () => _pickDateIntoController(context, fechaCtrl),
                      decoration: const InputDecoration(
                        labelText: 'Fecha de nacimiento (yyyy-MM-dd)',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return 'Requerido.';
                        if (!_isValidDateInput(value)) {
                          return 'Usa una fecha válida.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: telCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Número de teléfono',
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Requerido.' : null,
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: claseNuevo,
                      onChanged: (v) => setLocal(() => claseNuevo = v),
                      title: const Text('Clase de Nuevo'),
                    ),
                    SwitchListTile(
                      value: claseDoctrina,
                      onChanged: (v) => setLocal(() => claseDoctrina = v),
                      title: const Text('Clase de Doctrina'),
                    ),
                    SwitchListTile(
                      value: claseMaestro,
                      onChanged: (v) => setLocal(() => claseMaestro = v),
                      title: const Text('Clase de Maestro'),
                    ),
                    SwitchListTile(
                      value: claseLiderazgo,
                      onChanged: (v) => setLocal(() => claseLiderazgo = v),
                      title: const Text('Clase de Liderazgo'),
                    ),
                    SwitchListTile(
                      value: bautismo,
                      onChanged: (v) => setLocal(() => bautismo = v),
                      title: const Text('Bautismo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;

                final payload = {
                  'nombre': nombreCtrl.text.trim(),
                  'edad': int.tryParse(edadCtrl.text.trim()) ?? 0,
                  'fechaNacimiento': fechaCtrl.text.trim(),
                  'telefono': telCtrl.text.trim(),
                  'claseNuevo': claseNuevo,
                  'claseDoctrina': claseDoctrina,
                  'claseMaestro': claseMaestro,
                  'claseLiderazgo': claseLiderazgo,
                  'bautismo': bautismo,
                  'leaderId': initial?['leaderId'] ?? currentUser.uid,
                  'createdAt':
                      initial?['createdAt'] ?? FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (docId == null) {
                  await db.collection('jovenes').add(payload);
                } else {
                  await db.collection('jovenes').doc(docId).set(
                        payload,
                        SetOptions(merge: true),
                      );
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    ),
  );
}

class HistorialJovenPage extends StatelessWidget {
  final String jovenId;
  final String jovenNombre;
  final User currentUser;
  final LeaderProfile leader;

  const HistorialJovenPage({
    super.key,
    required this.jovenId,
    required this.jovenNombre,
    required this.currentUser,
    required this.leader,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar: AppBar(title: Text('Historial de $jovenNombre')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: db.collection('jovenes').doc(jovenId).get(),
          builder: (context, jovenSnap) {
            if (!jovenSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final jovenData = jovenSnap.data!.data();
            if (jovenData == null) {
              return const Center(child: Text('Joven no encontrado.'));
            }

            if (!isAdmin(leader.role) &&
                safeString(jovenData, 'leaderId') != currentUser.uid) {
              return const Center(
                child: Text('No tienes permiso para ver este historial.'),
              );
            }

            final infoCard = Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jovenNombre,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Edad: ${safeString(jovenData, "edad")}'),
                    Text(
                      'Fecha de nacimiento: ${_formatAnyDate(jovenData["fechaNacimiento"])}',
                    ),
                    Text('Teléfono: ${safeString(jovenData, "telefono")}'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _boolChip('Nuevo', jovenData['claseNuevo']),
                        _boolChip('Doctrina', jovenData['claseDoctrina']),
                        _boolChip('Maestro', jovenData['claseMaestro']),
                        _boolChip('Liderazgo', jovenData['claseLiderazgo']),
                        _boolChip('Bautismo', jovenData['bautismo']),
                      ],
                    ),
                  ],
                ),
              ),
            );

            final historyCard = Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: db
                      .collection('asistencias')
                      .where('jovenId', isEqualTo: jovenId)
                      .snapshots(),
                  builder: (context, asSnap) {
                    if (!asSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final asistencias = asSnap.data!.docs;
                    if (asistencias.isEmpty) {
                      return const Center(
                        child: Text('No hay historial de asistencia.'),
                      );
                    }

                    return FutureBuilder<List<_HistorialItem>>(
                      future: _buildHistorial(asistencias),
                      builder: (context, histSnap) {
                        if (!histSnap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final items = histSnap.data!;
                        final attended = items.where((e) => e.attended).length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asistencia: $attended/${items.length}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 20),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: item.attended
                                        ? Colors.green.withOpacity(.12)
                                        : Colors.red.withOpacity(.12),
                                    child: Icon(
                                      item.attended ? Icons.check : Icons.close,
                                      color: item.attended
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  title: Text(item.activityName),
                                  subtitle: Text('Fecha: ${item.activityDate}'),
                                  trailing: Text(
                                    item.attended ? 'Asistió' : 'Faltó',
                                    style: TextStyle(
                                      color: item.attended
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            );

            if (mobile) {
              return ListView(
                children: [
                  infoCard,
                  const SizedBox(height: 16),
                  historyCard,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: infoCard),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: historyCard),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HistorialItem {
  final String activityName;
  final String activityDate;
  final bool attended;

  _HistorialItem({
    required this.activityName,
    required this.activityDate,
    required this.attended,
  });
}

Future<List<_HistorialItem>> _buildHistorial(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> asistencias,
) async {
  final activityIds = asistencias
      .map((e) => safeString(e.data(), 'activityId'))
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  final activitiesById = <String, Map<String, dynamic>>{};
  for (final chunk in _chunkList(activityIds, 10)) {
    if (chunk.isEmpty) continue;
    final snap = await db
        .collection('actividades')
        .where(FieldPath.documentId, whereIn: chunk)
        .get();
    for (final doc in snap.docs) {
      activitiesById[doc.id] = doc.data();
    }
  }

  final out = <_HistorialItem>[];
  for (final a in asistencias) {
    final data = a.data();
    final activityId = safeString(data, 'activityId');
    final actData = activitiesById[activityId] ?? const <String, dynamic>{};
    out.add(
      _HistorialItem(
        activityName: safeString(actData, 'nombre', 'Actividad'),
        activityDate: _formatAnyDate(actData['fecha']),
        attended: (data['attended'] ?? false) == true,
      ),
    );
  }
  out.sort((a, b) => b.activityDate.compareTo(a.activityDate));
  return out;
}

Widget _boolChip(String text, dynamic value) {
  final ok = value == true;
  return Chip(
    label: Text('$text: ${ok ? "Sí" : "No"}'),
    backgroundColor: ok ? Colors.green.withOpacity(.12) : Colors.grey.shade200,
  );
}

class ActividadesPage extends StatefulWidget {
  final User currentUser;
  final LeaderProfile leader;

  const ActividadesPage({
    super.key,
    required this.currentUser,
    required this.leader,
  });

  @override
  State<ActividadesPage> createState() => _ActividadesPageState();
}

class _ActividadesPageState extends State<ActividadesPage> {
  String? selectedLeaderId;
  String? selectedZone;
  String search = '';
  String selectedStatus = 'todos';

  Query<Map<String, dynamic>> _activitiesQuery() {
    return db.collection('actividades');
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 900;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _activitiesQuery().snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Text('No se pudieron cargar las actividades.'),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = _sortActivitiesByProximity(snap.data!.docs);
        final filteredDocs = docs.where((doc) {
          final data = doc.data();
          final matchesSearch = search.isEmpty ||
              safeString(data, 'nombre').toLowerCase().contains(search) ||
              safeString(data, 'descripcion').toLowerCase().contains(search);
          final status = safeString(data, 'estado', 'programada');
          final matchesStatus =
              selectedStatus == 'todos' || status == selectedStatus;
          return matchesSearch && matchesStatus;
        }).toList();

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final upcomingDocs = docs.where((doc) {
          final date = _extractDate(doc.data()['fecha']);
          if (date == null) return false;
          final normalized = DateTime(date.year, date.month, date.day);
          return !normalized.isBefore(today);
        }).toList();
        final nextActivity = upcomingDocs.isEmpty ? null : upcomingDocs.first;

        final total = docs.length;
        final activas = docs
            .where((e) => safeString(e.data(), 'estado') == 'activa')
            .length;
        final programadas = docs
            .where((e) => safeString(e.data(), 'estado') == 'programada')
            .length;
        final cerradas = docs
            .where((e) => safeString(e.data(), 'estado') == 'cerrada')
            .length;

        return ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Actividades',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Consulta el calendario, revisa el estado de cada actividad y abre la asistencia con el contexto correcto.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    _ActivityHeroCard(
                      nextActivity: nextActivity,
                      upcomingCount: upcomingDocs.length,
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MiniStatCard(
                          label: 'Total',
                          value: '$total',
                          color: const Color(0xFF6A3EC5),
                        ),
                        _MiniStatCard(
                          label: 'Activas',
                          value: '$activas',
                          color: const Color(0xFF0F9D58),
                        ),
                        _MiniStatCard(
                          label: 'Programadas',
                          value: '$programadas',
                          color: const Color(0xFF2563EB),
                        ),
                        _MiniStatCard(
                          label: 'Cerradas',
                          value: '$cerradas',
                          color: const Color(0xFF6B7280),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: mobile ? double.infinity : 320,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar próxima actividad o descripción...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        setState(() => search = value.toLowerCase().trim()),
                  ),
                ),
                SizedBox(
                  width: mobile ? double.infinity : 220,
                  child: DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar lista por estado',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                      DropdownMenuItem(
                        value: 'programada',
                        child: Text('Programada'),
                      ),
                      DropdownMenuItem(value: 'activa', child: Text('Activa')),
                      DropdownMenuItem(
                        value: 'cerrada',
                        child: Text('Cerrada'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => selectedStatus = value ?? 'todos'),
                  ),
                ),
                if (isAdmin(widget.leader.role))
                  FilledButton.icon(
                    onPressed: () => _showActividadDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva actividad'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.view_list_outlined, size: 18),
                    label: Text('${filteredDocs.length} visibles'),
                  ),
                  const Chip(
                    avatar: Icon(Icons.trending_up, size: 18),
                    label: Text('Ordenadas por cercanía'),
                  ),
                  if (selectedStatus != 'todos')
                    Chip(
                      avatar: const Icon(Icons.filter_alt_outlined, size: 18),
                      label: Text(
                        'Estado: ${_activityStatusLabel(selectedStatus)}',
                      ),
                    ),
                  if (search.isNotEmpty)
                    const Chip(
                      avatar: Icon(Icons.search, size: 18),
                      label: Text('Búsqueda aplicada'),
                    ),
                ],
              ),
            ),
            if (isAdmin(widget.leader.role)) ...[
              const SizedBox(height: 14),
              FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: db.collection('leaders').get(),
                builder: (context, leaderSnap) {
                  final leaders = leaderSnap.data?.docs ?? [];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.tune_outlined,
                                color: Color(0xFF6A3EC5),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Filtros que se aplican al abrir asistencia',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Estos filtros no cambian la lista de actividades. Solo se usan cuando presionas "Abrir asistencia" en una actividad.',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: mobile ? double.infinity : 240,
                                child: DropdownButtonFormField<String?>(
                                  value: selectedLeaderId,
                                  decoration: const InputDecoration(
                                    labelText: 'Líder para asistencia',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Todos'),
                                    ),
                                    ...leaders.map(
                                      (e) => DropdownMenuItem<String?>(
                                        value: e.id,
                                        child: Text(
                                          safeString(
                                            e.data(),
                                            'name',
                                            'Sin nombre',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => selectedLeaderId = value),
                                ),
                              ),
                              SizedBox(
                                width: mobile ? double.infinity : 240,
                                child: DropdownButtonFormField<String?>(
                                  value: selectedZone,
                                  decoration: const InputDecoration(
                                    labelText: 'Zona para asistencia',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Todas'),
                                    ),
                                    ...leaders
                                        .map(
                                            (e) => safeString(e.data(), 'zone'))
                                        .where((zone) => zone.isNotEmpty)
                                        .toSet()
                                        .map(
                                          (zone) => DropdownMenuItem<String?>(
                                            value: zone,
                                            child: Text(zone),
                                          ),
                                        ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => selectedZone = value),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 14),
            Card(
              child: filteredDocs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          docs.isEmpty
                              ? 'No hay actividades.'
                              : 'No hay actividades que coincidan con la búsqueda o el estado seleccionado.',
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          for (var index = 0;
                              index < filteredDocs.length;
                              index++) ...[
                            _buildActivityItem(
                              context,
                              filteredDocs[index],
                              nextActivity?.id == filteredDocs[index].id,
                              mobile,
                            ),
                            if (index != filteredDocs.length - 1)
                              const Divider(height: 24),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> d,
    bool isNextActivity,
    bool mobile,
  ) {
    final data = d.data();
    final status = safeString(data, 'estado', 'programada');
    final relativeDate = _formatRelativeActivityDate(data['fecha']);

    if (mobile) {
      return Card(
        elevation: 0,
        color: isNextActivity ? const Color(0xFFFCFBFF) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isNextActivity
                ? const Color(0xFFBBA7F7)
                : const Color(0xFFE8EAF1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNextActivity) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Más cercana',
                    style: TextStyle(
                      color: Color(0xFF6A3EC5),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.event_note,
                      color: _activityStatusColor(status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      safeString(data, 'nombre', 'Actividad'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActivityStatusChip(status: status),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActivityInfoPill(
                    icon: Icons.schedule,
                    label: relativeDate,
                    tone: _activityStatusColor(status),
                  ),
                  if (_formatAnyDate(data['fecha']).isNotEmpty)
                    _ActivityInfoPill(
                      icon: Icons.calendar_today_outlined,
                      label: _formatAnyDate(data['fecha']),
                      tone: const Color(0xFF2563EB),
                    ),
                ],
              ),
              if (safeString(data, 'descripcion').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _truncateText(safeString(data, 'descripcion')),
                    style: const TextStyle(
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _openAttendance(context, d.id, data),
                    icon: const Icon(Icons.how_to_reg),
                    label: const Text('Abrir asistencia'),
                  ),
                  if (isAdmin(widget.leader.role))
                    IconButton.filledTonal(
                      onPressed: () => _showActividadDialog(
                        context,
                        docId: d.id,
                        initial: data,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (isAdmin(widget.leader.role))
                    IconButton.filledTonal(
                      onPressed: () => _deleteDoc('actividades', d.id, context),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEDE6FF),
        child: Icon(
          Icons.event_note,
          color: _activityStatusColor(status),
        ),
      ),
      title: Text(
        safeString(data, 'nombre', 'Actividad'),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isNextActivity)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Más cercana',
                      style: TextStyle(
                        color: Color(0xFF6A3EC5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                Text(
                  '${_formatAnyDate(data["fecha"])} · $relativeDate',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _truncateText(
                safeString(data, 'descripcion', 'Sin descripción'),
                maxLength: 90,
              ),
            ),
          ],
        ),
      ),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ActivityStatusChip(status: status),
          FilledButton.tonalIcon(
            onPressed: () => _openAttendance(context, d.id, data),
            icon: const Icon(Icons.how_to_reg),
            label: const Text('Abrir asistencia'),
          ),
          if (isAdmin(widget.leader.role))
            IconButton(
              tooltip: 'Editar actividad',
              onPressed: () => _showActividadDialog(
                context,
                docId: d.id,
                initial: data,
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (isAdmin(widget.leader.role))
            IconButton(
              tooltip: 'Eliminar actividad',
              onPressed: () => _deleteDoc('actividades', d.id, context),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }

  void _openAttendance(
    BuildContext context,
    String activityId,
    Map<String, dynamic> activityData,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AsistenciaPage(
          activityId: activityId,
          activityData: activityData,
          currentUser: widget.currentUser,
          leader: widget.leader,
          selectedLeaderId: selectedLeaderId,
          selectedZone: selectedZone,
        ),
      ),
    );
  }
}

Future<void> _showActividadDialog(
  BuildContext context, {
  String? docId,
  Map<String, dynamic>? initial,
}) async {
  final formKey = GlobalKey<FormState>();
  final data = initial ?? {};
  final nombreCtrl = TextEditingController(text: safeString(data, 'nombre'));
  final fechaCtrl = TextEditingController(text: _formatAnyDate(data['fecha']));
  final descCtrl = TextEditingController(text: safeString(data, 'descripcion'));
  String estado = safeString(data, 'estado', 'programada');

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(docId == null ? 'Nueva actividad' : 'Editar actividad'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Requerido.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: fechaCtrl,
                  readOnly: true,
                  onTap: () => _pickDateIntoController(context, fechaCtrl),
                  decoration: const InputDecoration(
                    labelText: 'Fecha (yyyy-MM-dd)',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Requerido.';
                    if (!_isValidDateInput(value)) {
                      return 'Usa una fecha válida.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Requerido.' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: estado,
                  items: const [
                    DropdownMenuItem(
                      value: 'programada',
                      child: Text('programada'),
                    ),
                    DropdownMenuItem(value: 'activa', child: Text('activa')),
                    DropdownMenuItem(value: 'cerrada', child: Text('cerrada')),
                  ],
                  onChanged: (v) => estado = v ?? 'programada',
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final payload = {
              'nombre': nombreCtrl.text.trim(),
              'fecha': fechaCtrl.text.trim(),
              'descripcion': descCtrl.text.trim(),
              'estado': estado,
              'createdAt':
                  initial?['createdAt'] ?? FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            };

            if (docId == null) {
              await db.collection('actividades').add(payload);
            } else {
              await db.collection('actividades').doc(docId).set(
                    payload,
                    SetOptions(merge: true),
                  );
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

class AsistenciaPage extends StatefulWidget {
  final String activityId;
  final Map<String, dynamic> activityData;
  final User currentUser;
  final LeaderProfile leader;
  final String? selectedLeaderId;
  final String? selectedZone;

  const AsistenciaPage({
    super.key,
    required this.activityId,
    required this.activityData,
    required this.currentUser,
    required this.leader,
    this.selectedLeaderId,
    this.selectedZone,
  });

  @override
  State<AsistenciaPage> createState() => _AsistenciaPageState();
}

class _AttendancePageData {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> jovenes;
  final Map<String, bool> attendedByJovenId;
  final Map<String, String> docIdByJovenId;

  const _AttendancePageData({
    required this.jovenes,
    required this.attendedByJovenId,
    required this.docIdByJovenId,
  });
}

class _AsistenciaPageState extends State<AsistenciaPage> {
  late Future<_AttendancePageData> _pageDataFuture;
  final Map<String, bool> _localAttendance = {};
  final Map<String, String> _attendanceDocIds = {};

  @override
  void initState() {
    super.initState();
    _pageDataFuture = _loadPageData();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadJovenes() async {
    Query<Map<String, dynamic>> query = db.collection('jovenes');

    if (!isAdmin(widget.leader.role)) {
      query = query.where('leaderId', isEqualTo: widget.currentUser.uid);
    } else if (widget.selectedLeaderId != null) {
      query = query.where('leaderId', isEqualTo: widget.selectedLeaderId);
    }

    final snap = await query.get();
    var docs = snap.docs;

    if (widget.selectedZone != null && widget.selectedZone!.isNotEmpty) {
      final leadersSnap = await db
          .collection('leaders')
          .where('zone', isEqualTo: widget.selectedZone)
          .get();
      final allowedIds = leadersSnap.docs.map((e) => e.id).toSet();
      docs =
          docs.where((e) => allowedIds.contains(e.data()['leaderId'])).toList();
    }

    return docs;
  }

  Future<_AttendancePageData> _loadPageData() async {
    final jovenes = await _loadJovenes();
    final attendanceSnap = await db
        .collection('asistencias')
        .where('activityId', isEqualTo: widget.activityId)
        .get();

    final attendedByJovenId = <String, bool>{};
    final docIdByJovenId = <String, String>{};
    for (final doc in attendanceSnap.docs) {
      final data = doc.data();
      final jovenId = safeString(data, 'jovenId');
      if (jovenId.isEmpty) continue;
      attendedByJovenId[jovenId] = data['attended'] == true;
      docIdByJovenId[jovenId] = doc.id;
    }

    return _AttendancePageData(
      jovenes: jovenes,
      attendedByJovenId: attendedByJovenId,
      docIdByJovenId: docIdByJovenId,
    );
  }

  Future<void> _saveAttendance(String jovenId, bool attended) async {
    final payload = <String, dynamic>{
      'activityId': widget.activityId,
      'jovenId': jovenId,
      'attended': attended,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docId = _attendanceDocIds[jovenId];
    if (docId == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      final ref = await db.collection('asistencias').add(payload);
      _attendanceDocIds[jovenId] = ref.id;
    } else {
      await db.collection('asistencias').doc(docId).set(
            payload,
            SetOptions(merge: true),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityName = safeString(widget.activityData, 'nombre', 'Actividad');

    return Scaffold(
      appBar: AppBar(title: Text('Pase de asistencia · $activityName')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: FutureBuilder<_AttendancePageData>(
          future: _pageDataFuture,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(
                child: Text('No se pudo cargar la asistencia.'),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final pageData = snap.data!;
            if (_attendanceDocIds.isEmpty) {
              _attendanceDocIds.addAll(pageData.docIdByJovenId);
            }
            if (_localAttendance.isEmpty) {
              _localAttendance.addAll(pageData.attendedByJovenId);
            }

            final jovenes = pageData.jovenes;
            if (jovenes.isEmpty) {
              return const Center(child: Text('No hay jóvenes para mostrar.'));
            }

            return Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.people_outline, size: 18),
                          label: Text('${jovenes.length} jóvenes visibles'),
                        ),
                        if (widget.selectedLeaderId != null)
                          const Chip(
                            avatar: Icon(
                              Icons.manage_accounts_outlined,
                              size: 18,
                            ),
                            label: Text('Filtro por líder aplicado'),
                          ),
                        if (widget.selectedZone != null &&
                            widget.selectedZone!.isNotEmpty)
                          Chip(
                            avatar: const Icon(Icons.place_outlined, size: 18),
                            label: Text('Zona: ${widget.selectedZone}'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: jovenes.length,
                    separatorBuilder: (_, __) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final joven = jovenes[index];
                      final jovenData = joven.data();
                      return _AttendanceTile(
                        jovenNombre: safeString(jovenData, 'nombre'),
                        telefono: safeString(jovenData, 'telefono'),
                        initialValue: _localAttendance[joven.id] ?? false,
                        onChanged: (value) async {
                          setState(() => _localAttendance[joven.id] = value);
                          await _saveAttendance(joven.id, value);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AttendanceTile extends StatefulWidget {
  final String jovenNombre;
  final String telefono;
  final bool initialValue;
  final Future<void> Function(bool value) onChanged;

  const _AttendanceTile({
    required this.jovenNombre,
    required this.telefono,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_AttendanceTile> createState() => _AttendanceTileState();
}

class _AttendanceTileState extends State<_AttendanceTile> {
  late bool currentValue;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    currentValue = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant _AttendanceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && !saving) {
      currentValue = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        value: currentValue,
        title: Text(
          widget.jovenNombre,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('Tel: ${widget.telefono}'),
        onChanged: (v) async {
          setState(() {
            currentValue = v;
            saving = true;
          });
          await widget.onChanged(v);
          if (mounted) {
            setState(() => saving = false);
          }
        },
      ),
    );
  }
}

class ConfiguracionPage extends StatelessWidget {
  final User currentUser;
  final LeaderProfile leader;

  const ConfiguracionPage({
    super.key,
    required this.currentUser,
    required this.leader,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuración',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(leader.name),
                  subtitle: Text(currentUser.email ?? leader.email),
                  trailing: Chip(label: Text(leader.role)),
                ),
                const Divider(height: 28),
                const Text(
                  'Permisos actuales',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  isAdmin(leader.role)
                      ? 'Como admin, puedes ver y administrar todo.'
                      : 'Como líder, solo puedes gestionar tu información, tus jóvenes, tus reportes y tus asistencias.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _deleteDoc(
  String collection,
  String docId,
  BuildContext context,
) async {
  final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar'),
          content: const Text('¿Deseas eliminar este registro?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ) ??
      false;

  if (!ok) return;

  await db.collection(collection).doc(docId).delete();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro eliminado.')),
    );
  }
}
