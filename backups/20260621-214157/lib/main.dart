import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

import 'app_theme.dart';
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
      theme: JVTheme.light,
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
      zone: _normalizeLeaderZone(safeString(data, 'zone')),
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
  static const String _backgroundAsset = 'assets/images/login_background.jpeg';

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
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 820;
          final horizontalPadding = mobile ? 20.0 : 36.0;
          final verticalPadding = mobile ? 20.0 : 30.0;

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  _backgroundAsset,
                  fit: BoxFit.cover,
                  alignment: mobile ? Alignment.center : Alignment.center,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(mobile ? .64 : .58),
                        const Color(0xFF2B175F).withOpacity(mobile ? .52 : .42),
                        Colors.black.withOpacity(mobile ? .70 : .50),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: mobile ? 520 : 1120,
                        minHeight: constraints.maxHeight - verticalPadding * 2,
                      ),
                      child: mobile
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const _LoginHero(compact: true),
                                const SizedBox(height: 22),
                                _loginCard(context, mobile: true),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Expanded(child: _LoginHero()),
                                const SizedBox(width: 44),
                                SizedBox(
                                  width: 430,
                                  child: _loginCard(context),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _loginCard(BuildContext context, {bool mobile = false}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
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
                    backgroundColor: Color(0xFF4F46E5),
                    child: Icon(Icons.groups_rounded,
                        color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Bienvenido de vuelta',
                style: TextStyle(
                  color: JVTheme.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa para gestionar líderes, jóvenes, actividades y asistencias.',
                style: TextStyle(color: JVTheme.muted, height: 1.45),
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
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(.16)),
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

class _LoginHero extends StatelessWidget {
  final bool compact;

  const _LoginHero({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final alignment =
        compact ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = compact ? TextAlign.center : TextAlign.start;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Container(
          width: compact ? 58 : 68,
          height: compact ? 58 : 68,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(.32)),
          ),
          child: const Icon(
            Icons.groups_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'JV Líderes',
          textAlign: textAlign,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 34 : 52,
            fontWeight: FontWeight.w900,
            height: 1.02,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(.32),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 420 : 580),
          child: Text(
            'Una plataforma para cuidar mejor cada registro, actividad y asistencia del grupo juvenil.',
            textAlign: textAlign,
            style: TextStyle(
              color: Colors.white.withOpacity(.88),
              fontSize: compact ? 16 : 19,
              height: 1.45,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 28),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FeaturePill(icon: Icons.phone_iphone, text: 'Móvil y PC'),
              _FeaturePill(icon: Icons.security, text: 'Roles seguros'),
              _FeaturePill(
                icon: Icons.analytics_outlined,
                text: 'Seguimiento en vivo',
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeaturePill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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

  void _selectSection(String title) {
    final index = _items.indexWhere((item) => item.title == title);
    if (index == -1) return;
    setState(() => selectedIndex = index);
  }

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
      DashboardPage(
        currentUser: widget.currentUser,
        leader: widget.leader,
        onSelectSection: _selectSection,
      ),
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
    final currentItem = _items[selectedIndex];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: mobile ? 16 : 24,
        title: Text(
          currentItem.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (!mobile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
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
              width: railExtended ? 260 : (tablet ? 88 : 96),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Color(0xFFE5E7EB)),
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
                      const SizedBox(height: 14),
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
                child: _PageFrame(child: pages[selectedIndex]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  final Widget child;

  const _PageFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth > 1440 ? 1440.0 : constraints.maxWidth;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: maxWidth,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
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
    if (!extended) {
      return const Center(
        child: CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFF4F46E5),
          child: Icon(Icons.groups, color: Colors.white),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF4F46E5),
            child: Icon(Icons.groups, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JV Líderes',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                Text(
                  leader.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
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
  final ValueChanged<String> onSelectSection;

  const DashboardPage({
    super.key,
    required this.currentUser,
    required this.leader,
    required this.onSelectSection,
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
    final metrics = [
      _MetricCard(
        width: mobile ? double.infinity : 0,
        title: 'Líderes',
        icon: Icons.manage_accounts,
        stream: _leadersMetricStream(),
      ),
      _MetricCard(
        width: mobile ? double.infinity : 0,
        title: 'Reportes',
        icon: Icons.assessment,
        stream: _queryFor('reportes').snapshots(),
      ),
      _MetricCard(
        width: mobile ? double.infinity : 0,
        title: 'Jóvenes',
        icon: Icons.groups,
        stream: _queryFor('jovenes').snapshots(),
      ),
      _MetricCard(
        width: mobile ? double.infinity : 0,
        title: 'Actividades',
        icon: Icons.event_note,
        stream: db.collection('actividades').snapshots(),
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeHeader(leader: leader),
          const SizedBox(height: 16),
          _QuickActionsPanel(
            isAdminUser: isAdmin(leader.role),
            onSelectSection: onSelectSection,
          ),
          const SizedBox(height: 16),
          if (mobile)
            Column(
              children: metrics
                  .map(
                    (metric) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: metric,
                    ),
                  )
                  .toList(),
            )
          else
            Row(
              children: metrics.asMap().entries.map((entry) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: entry.key == metrics.length - 1 ? 0 : 14,
                    ),
                    child: entry.value,
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          if (mobile) ...[
            _Panel(
              title: 'Asistencia por fecha',
              child: isAdmin(leader.role)
                  ? _AttendanceByDateChartPanel(
                      currentUser: currentUser,
                      leader: leader,
                    )
                  : const _LeaderAttendanceHint(),
            ),
            const SizedBox(height: 16),
            const _Panel(
              title: 'Estado de actividades',
              child: _ActivityStatusPanel(),
            ),
            const SizedBox(height: 16),
            _Panel(
              title: isAdmin(leader.role)
                  ? 'Asistencia por actividad'
                  : 'Asistencia',
              child: isAdmin(leader.role)
                  ? const _AttendanceByActivityPanel()
                  : const _LeaderAttendanceHint(),
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
                    title: 'Asistencia por fecha',
                    child: isAdmin(leader.role)
                        ? _AttendanceByDateChartPanel(
                            currentUser: currentUser,
                            leader: leader,
                          )
                        : const _LeaderAttendanceHint(),
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
                const Expanded(
                  flex: 2,
                  child: _Panel(
                    title: 'Actividades recientes',
                    child: _RecentActivitiesPanel(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _Panel(
                    title: isAdmin(leader.role)
                        ? 'Asistencia por actividad'
                        : 'Asistencia',
                    child: isAdmin(leader.role)
                        ? const _AttendanceByActivityPanel()
                        : const _LeaderAttendanceHint(),
                  ),
                ),
              ],
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        child: Wrap(
          spacing: 18,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEDEBFF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.dashboard_customize_outlined,
                color: Color(0xFF4F46E5),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 260, maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, ${leader.name}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAdmin(leader.role)
                        ? 'Resumen operativo del grupo juvenil y sus actividades.'
                        : 'Tus jóvenes, reportes y asistencias en un solo lugar.',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.verified_user, size: 18),
                  label: Text(isAdmin(leader.role) ? 'Administrador' : 'Líder'),
                ),
                Chip(
                  avatar: const Icon(Icons.place_outlined, size: 18),
                  label: Text(leader.zone.isEmpty ? 'Sin zona' : leader.zone),
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
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  final bool isAdminUser;
  final ValueChanged<String> onSelectSection;

  const _QuickActionsPanel({
    required this.isAdminUser,
    required this.onSelectSection,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        title: 'Jóvenes',
        subtitle: 'Registrar y consultar perfiles',
        icon: Icons.groups_outlined,
        section: 'Jóvenes',
      ),
      _QuickAction(
        title: 'Actividades',
        subtitle: 'Agenda y pase de asistencia',
        icon: Icons.event_note_outlined,
        section: 'Actividades',
      ),
      _QuickAction(
        title: 'Reportes',
        subtitle: 'Revisar seguimiento semanal',
        icon: Icons.bar_chart_outlined,
        section: 'Reportes',
      ),
      if (isAdminUser)
        _QuickAction(
          title: 'Líderes',
          subtitle: 'Administrar equipo y zonas',
          icon: Icons.manage_accounts_outlined,
          section: 'Líderes',
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Accesos rápidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                if (compact) {
                  return Column(
                    children: actions
                        .map(
                          (action) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _QuickActionButton(
                              action: action,
                              onTap: () => onSelectSection(action.section),
                            ),
                          ),
                        )
                        .toList(),
                  );
                }

                return Row(
                  children: actions.asMap().entries.map((entry) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: entry.key == actions.length - 1 ? 0 : 12,
                        ),
                        child: _QuickActionButton(
                          action: entry.value,
                          onTap: () => onSelectSection(entry.value.section),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final String section;

  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.section,
  });
}

class _QuickActionButton extends StatelessWidget {
  final _QuickAction action;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEDEBFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(action.icon, color: const Color(0xFF4F46E5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20),
        ],
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
    final fixedWidth = width > 0 && width != double.infinity;

    return SizedBox(
      width: fixedWidth ? width : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: fixedWidth ? width : 0,
          maxWidth: fixedWidth ? width : double.infinity,
        ),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
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
                      radius: 22,
                      backgroundColor: const Color(0xFFEDEBFF),
                      child: Icon(icon, color: const Color(0xFF4F46E5)),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1,
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

class _AttendanceByDateChartPanel extends StatefulWidget {
  final User currentUser;
  final LeaderProfile leader;

  const _AttendanceByDateChartPanel({
    required this.currentUser,
    required this.leader,
  });

  @override
  State<_AttendanceByDateChartPanel> createState() =>
      _AttendanceByDateChartPanelState();
}

class _AttendanceByDateChartPanelState
    extends State<_AttendanceByDateChartPanel> {
  String selectedActivity = 'Todas';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('actividades').snapshots(),
      builder: (context, activitySnap) {
        if (activitySnap.hasError) {
          return const _EmptyData('No se pudieron cargar las actividades.');
        }
        if (!activitySnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final activities = activitySnap.data!.docs;
        if (activities.isEmpty) {
          return const _EmptyData('No hay actividades registradas.');
        }

        return FutureBuilder<_AttendanceByDateData>(
          future: _loadAttendanceByDateData(
            activities: activities,
            currentUser: widget.currentUser,
            leader: widget.leader,
          ),
          builder: (context, chartSnap) {
            if (chartSnap.hasError) {
              return const _EmptyData('No se pudo cargar la asistencia.');
            }
            if (!chartSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = chartSnap.data!;
            if (data.activityNames.isEmpty) {
              return const _EmptyData('Aún no hay asistencias registradas.');
            }

            if (selectedActivity != 'Todas' &&
                !data.activityNames.contains(selectedActivity)) {
              selectedActivity = 'Todas';
            }

            final groups = data.groupsFor(selectedActivity);
            final mobile = MediaQuery.of(context).size.width < 700;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: mobile ? double.infinity : 300,
                  child: DropdownButtonFormField<String>(
                    value: selectedActivity,
                    decoration: const InputDecoration(
                      labelText: 'Actividad',
                      prefixIcon: Icon(Icons.event_available_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'Todas',
                        child: Text('Todas'),
                      ),
                      ...data.activityNames.map(
                        (name) => DropdownMenuItem(
                          value: name,
                          child: Text(name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selectedActivity = value);
                    },
                  ),
                ),
                const SizedBox(height: 18),
                if (groups.isEmpty)
                  const _EmptyData(
                    'No hay asistencias para la actividad seleccionada.',
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: mobile ? 280 : 320,
                        width: double.infinity,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final preferredWidth = groups.length * 92.0;
                            final chartWidth =
                                preferredWidth < constraints.maxWidth
                                    ? constraints.maxWidth
                                    : preferredWidth;
                            return Scrollbar(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: chartWidth,
                                  height: double.infinity,
                                  child: _GroupedAttendanceChart(
                                    groups: groups,
                                    activityNames: selectedActivity == 'Todas'
                                        ? data.activityNames
                                        : [selectedActivity],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AttendanceChartLegend(
                        activityNames: selectedActivity == 'Todas'
                            ? data.activityNames
                            : [selectedActivity],
                      ),
                    ],
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AttendanceByDateData {
  final List<String> activityNames;
  final List<_AttendanceDateGroup> groups;

  const _AttendanceByDateData({
    required this.activityNames,
    required this.groups,
  });

  List<_AttendanceDateGroup> groupsFor(String selectedActivity) {
    if (selectedActivity == 'Todas') return groups;
    final filtered = <_AttendanceDateGroup>[];
    for (final group in groups) {
      final count = group.countsByActivity[selectedActivity] ?? 0;
      if (count == 0) continue;
      filtered.add(
        _AttendanceDateGroup(
          date: group.date,
          label: group.label,
          countsByActivity: {selectedActivity: count},
        ),
      );
    }
    return filtered;
  }
}

class _AttendanceDateGroup {
  final DateTime date;
  final String label;
  final Map<String, int> countsByActivity;

  const _AttendanceDateGroup({
    required this.date,
    required this.label,
    required this.countsByActivity,
  });
}

Future<_AttendanceByDateData> _loadAttendanceByDateData({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> activities,
  required User currentUser,
  required LeaderProfile leader,
}) async {
  final activityById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

  for (final activity in activities) {
    final name = safeString(activity.data(), 'nombre', 'Actividad').trim();
    if (name.isEmpty) continue;
    activityById[activity.id] = activity;
  }

  if (activityById.isEmpty) {
    return const _AttendanceByDateData(activityNames: [], groups: []);
  }

  final attendanceSnap = await db.collection('asistencias').get();
  final allowedJovenIds = await _loadAllowedDashboardJovenIds(
    currentUser: currentUser,
    leader: leader,
  );
  final grouped = <String, _MutableAttendanceDateGroup>{};
  final hasJovenScope = allowedJovenIds != null;

  for (final attendance in attendanceSnap.docs) {
    final data = attendance.data();
    if (data['attended'] != true) continue;

    if (hasJovenScope &&
        !allowedJovenIds.contains(safeString(data, 'jovenId'))) {
      continue;
    }

    final activityId = safeString(data, 'activityId');
    final activity = activityById[activityId];
    if (activity == null) continue;

    final activityData = activity.data();
    final date = _extractDate(activityData['fecha']);
    if (date == null) continue;

    final normalizedDate = DateTime(date.year, date.month, date.day);
    final key = DateFormat('yyyy-MM-dd').format(normalizedDate);
    final name = safeString(activityData, 'nombre', 'Actividad').trim();
    if (name.isEmpty) continue;

    final bucket = grouped.putIfAbsent(
      key,
      () => _MutableAttendanceDateGroup(
        date: normalizedDate,
        label: DateFormat('dd/MM').format(normalizedDate),
      ),
    );
    bucket.countsByActivity[name] = (bucket.countsByActivity[name] ?? 0) + 1;
  }

  final groups = grouped.values
      .map(
        (group) => _AttendanceDateGroup(
          date: group.date,
          label: group.label,
          countsByActivity: Map.unmodifiable(group.countsByActivity),
        ),
      )
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final attendedActivityNames = groups
      .expand((group) => group.countsByActivity.keys)
      .toSet()
      .toList()
    ..sort();

  return _AttendanceByDateData(
    activityNames: attendedActivityNames,
    groups: groups,
  );
}

Future<Set<String>?> _loadAllowedDashboardJovenIds({
  required User currentUser,
  required LeaderProfile leader,
}) async {
  if (isAdmin(leader.role)) return null;

  final jovenesSnap = await db
      .collection('jovenes')
      .where('leaderId', isEqualTo: currentUser.uid)
      .get();
  return jovenesSnap.docs.map((doc) => doc.id).toSet();
}

class _MutableAttendanceDateGroup {
  final DateTime date;
  final String label;
  final Map<String, int> countsByActivity = {};

  _MutableAttendanceDateGroup({
    required this.date,
    required this.label,
  });
}

class _GroupedAttendanceChart extends StatelessWidget {
  final List<_AttendanceDateGroup> groups;
  final List<String> activityNames;

  const _GroupedAttendanceChart({
    required this.groups,
    required this.activityNames,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GroupedAttendanceChartPainter(
        groups: groups,
        activityNames: activityNames,
        textDirection: Directionality.of(context),
      ),
    );
  }
}

class _GroupedAttendanceChartPainter extends CustomPainter {
  final List<_AttendanceDateGroup> groups;
  final List<String> activityNames;
  final TextDirection textDirection;

  const _GroupedAttendanceChartPainter({
    required this.groups,
    required this.activityNames,
    required this.textDirection,
  });

  static const _palette = [
    Color(0xFF4F46E5),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFF2563EB),
    Color(0xFFDB2777),
    Color(0xFF7C3AED),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (groups.isEmpty || activityNames.isEmpty) return;

    final axisPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;

    const left = 42.0;
    const right = 14.0;
    const top = 18.0;
    const bottom = 48.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final visibleActivities = activityNames.take(6).toList();
    if (visibleActivities.isEmpty) return;

    final maxValue = groups
        .expand((group) => visibleActivities.map(
              (name) => group.countsByActivity[name] ?? 0,
            ))
        .fold<int>(0, (max, value) => value > max ? value : max);
    final effectiveMax = maxValue <= 0 ? 1 : maxValue;
    final step = (effectiveMax / 4).ceil().clamp(1, effectiveMax).toInt();
    final yMax =
        ((effectiveMax / step).ceil() * step).clamp(1, 999999).toInt();

    for (var value = 0; value <= yMax; value += step) {
      final y = top + chartHeight - (value / yMax) * chartHeight;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
      _drawText(
        canvas,
        '$value',
        Offset(0, y - 8),
        width: left - 8,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        align: TextAlign.right,
      );
    }

    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + chartHeight),
      axisPaint,
    );
    canvas.drawLine(
      Offset(left, top + chartHeight),
      Offset(size.width - right, top + chartHeight),
      axisPaint,
    );

    final groupWidth = chartWidth / groups.length;
    final barGap = visibleActivities.length == 1 ? 0.0 : 3.0;
    final barsWidth = groupWidth * .68;
    final barWidth =
        ((barsWidth - barGap * (visibleActivities.length - 1)) /
                visibleActivities.length)
            .clamp(4.0, 24.0)
            .toDouble();

    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      final groupStart = left + groupIndex * groupWidth;
      final barsStart =
          groupStart + (groupWidth - (barWidth * visibleActivities.length) -
                  barGap * (visibleActivities.length - 1)) /
              2;

      for (var activityIndex = 0;
          activityIndex < visibleActivities.length;
          activityIndex++) {
        final activity = visibleActivities[activityIndex];
        final value = group.countsByActivity[activity] ?? 0;
        if (value == 0) continue;

        final barHeight = (value / yMax) * chartHeight;
        final x = barsStart + activityIndex * (barWidth + barGap);
        final y = top + chartHeight - barHeight;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(5),
        );
        final paint = Paint()
          ..color = _palette[activityIndex % _palette.length];
        canvas.drawRRect(rect, paint);

        if (barHeight > 16 || value < 100) {
          _drawText(
            canvas,
            '$value',
            Offset(x - 8, y - 16),
            width: barWidth + 16,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
            align: TextAlign.center,
          );
        }
      }

      _drawText(
        canvas,
        group.label,
        Offset(groupStart, top + chartHeight + 12),
        width: groupWidth,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        align: TextAlign.center,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double width,
    required TextStyle style,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GroupedAttendanceChartPainter oldDelegate) {
    return oldDelegate.groups != groups ||
        oldDelegate.activityNames != activityNames ||
        oldDelegate.textDirection != textDirection;
  }
}

class _AttendanceChartLegend extends StatelessWidget {
  final List<String> activityNames;

  const _AttendanceChartLegend({required this.activityNames});

  static const _palette = _GroupedAttendanceChartPainter._palette;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: activityNames.take(6).toList().asMap().entries.map((entry) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _palette[entry.key % _palette.length],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              entry.value,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      }).toList(),
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
    final mobile = MediaQuery.of(context).size.width < 900;

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
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
  final String? eyebrow;

  const _Panel({
    required this.title,
    required this.child,
    this.eyebrow,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null) ...[
              Text(
                eyebrow!,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
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
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline, color: Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
        ],
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
    final mobile = MediaQuery.of(context).size.width < 900;

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

                if (!mobile) {
                  return _LeadersDataTable(docs: docs);
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
                        '${safeString(data, "email")} · Zona: ${_displayLeaderZone(safeString(data, "zone"))}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text(safeString(data, 'role', 'leader')),
                          ),
                          IconButton(
                            onPressed: () => _showLeaderDialog(
                              context,
                              docId: d.id,
                              initial: data,
                            ),
                            tooltip: 'Editar líder',
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () =>
                                _sendLeaderAccess(context, d.id, data),
                            tooltip: 'Enviar acceso',
                            icon: const Icon(Icons.mark_email_unread_outlined),
                          ),
                          IconButton(
                            onPressed: () =>
                                _deleteDoc('leaders', d.id, context),
                            tooltip: 'Eliminar líder',
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

class _TableText extends StatelessWidget {
  final String value;
  final double width;
  final bool strong;

  const _TableText(this.value, {required this.width, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final text = value.trim().isEmpty ? '-' : value.trim();

    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: strong ? FontWeight.w800 : null),
      ),
    );
  }
}

class _LeadersDataTable extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const _LeadersDataTable({required this.docs});

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 28,
            columns: const [
              DataColumn(label: Text('Nombre')),
              DataColumn(label: Text('Correo')),
              DataColumn(label: Text('Zona')),
              DataColumn(label: Text('Rol')),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: docs.map((d) {
              final data = d.data();
              return DataRow(
                cells: [
                  DataCell(
                    _TableText(
                      safeString(data, 'name', 'Sin nombre'),
                      width: 220,
                      strong: true,
                    ),
                  ),
                  DataCell(_TableText(safeString(data, 'email'), width: 260)),
                  DataCell(
                    _TableText(
                      _displayLeaderZone(safeString(data, 'zone')),
                      width: 140,
                    ),
                  ),
                  DataCell(
                    Chip(label: Text(safeString(data, 'role', 'leader'))),
                  ),
                  DataCell(
                    Chip(label: Text(safeString(data, 'status', 'activo'))),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Editar líder',
                          onPressed: () => _showLeaderDialog(
                            context,
                            docId: d.id,
                            initial: data,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Enviar acceso',
                          onPressed: () =>
                              _sendLeaderAccess(context, d.id, data),
                          icon: const Icon(Icons.mark_email_unread_outlined),
                        ),
                        IconButton(
                          tooltip: 'Eliminar líder',
                          onPressed: () => _deleteDoc('leaders', d.id, context),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _LeaderAccessResult {
  final String? uid;
  final bool createdAuthUser;

  const _LeaderAccessResult({
    required this.uid,
    required this.createdAuthUser,
  });
}

const List<String> _leaderZones = ['Zona 1', 'Zona 2', 'Zona 3'];

String _normalizeLeaderZone(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return '';

  final numericZone = RegExp(
    r'^(zona\s*)?([0-9]+)$',
    caseSensitive: false,
  ).firstMatch(clean);
  if (numericZone != null) {
    return 'Zona ${numericZone.group(2)}';
  }

  for (final zone in _leaderZones) {
    if (zone.toLowerCase() == clean.toLowerCase()) return zone;
  }
  return clean;
}

String _displayLeaderZone(String value) {
  final zone = _normalizeLeaderZone(value);
  return zone.isEmpty ? 'Sin zona' : zone;
}

List<String> _leaderZoneQueryValues(String value) {
  final normalized = _normalizeLeaderZone(value);
  final values = <String>{normalized};
  final numericZone = RegExp(
    r'^Zona\s+([0-9]+)$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (numericZone != null) values.add(numericZone.group(1)!);
  return values.toList();
}

String _generateTemporaryPassword() {
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return 'JV-$stamp!';
}

String _authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return 'Ese correo ya existe en Authentication.';
    case 'invalid-email':
      return 'El correo no tiene un formato válido.';
    case 'operation-not-allowed':
      return 'El proveedor Email/Password no está habilitado en Firebase Authentication.';
    case 'weak-password':
      return 'La contraseña temporal es muy débil.';
    case 'network-request-failed':
      return 'No se pudo conectar con Firebase. Revisa la conexión e intenta de nuevo.';
    default:
      return e.message ?? 'No se pudo preparar el acceso del líder.';
  }
}

Future<_LeaderAccessResult> _ensureLeaderAuthAccess({
  required String email,
  required String temporaryPassword,
}) async {
  FirebaseApp? secondaryApp;
  try {
    secondaryApp = await Firebase.initializeApp(
      name: 'leader-access-${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    String? uid;
    var createdAuthUser = false;
    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: temporaryPassword,
      );
      uid = credential.user?.uid;
      createdAuthUser = true;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
    }

    await secondaryAuth.sendPasswordResetEmail(email: email);
    await secondaryAuth.signOut();

    return _LeaderAccessResult(
      uid: uid,
      createdAuthUser: createdAuthUser,
    );
  } finally {
    await secondaryApp?.delete();
  }
}

Future<void> _migrateLeaderReferences({
  required String fromLeaderId,
  required String toLeaderId,
}) async {
  if (fromLeaderId == toLeaderId) return;

  const collections = ['registros', 'reportes', 'jovenes', 'asistencias'];
  for (final collection in collections) {
    final snap = await db
        .collection(collection)
        .where('leaderId', isEqualTo: fromLeaderId)
        .get();

    for (final chunk in _chunkList(snap.docs, 450)) {
      final batch = db.batch();
      for (final doc in chunk) {
        batch.update(doc.reference, {'leaderId': toLeaderId});
      }
      await batch.commit();
    }
  }
}

Future<void> _sendLeaderAccess(
  BuildContext context,
  String docId,
  Map<String, dynamic> data,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final email = safeString(data, 'email').trim().toLowerCase();

  if (email.isEmpty || !email.contains('@')) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Este líder no tiene un correo válido.')),
    );
    return;
  }

  try {
    final normalizedZone = _normalizeLeaderZone(safeString(data, 'zone'));
    final result = await _ensureLeaderAuthAccess(
      email: email,
      temporaryPassword: _generateTemporaryPassword(),
    );

    if (result.uid != null && result.uid != docId) {
      final payload = Map<String, dynamic>.from(data)
        ..remove('reports')
        ..['email'] = email
        ..['zone'] = normalizedZone
        ..['updatedAt'] = FieldValue.serverTimestamp();

      await db.collection('leaders').doc(result.uid).set(
            payload,
            SetOptions(merge: true),
          );
      await _migrateLeaderReferences(
        fromLeaderId: docId,
        toLeaderId: result.uid!,
      );
      await db.collection('leaders').doc(docId).delete();
    } else {
      await db.collection('leaders').doc(docId).set(
        {
          'email': email,
          'zone': normalizedZone,
          'reports': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    final message = result.createdAuthUser
        ? 'Cuenta creada y correo de acceso enviado a $email.'
        : result.uid == null && docId.length < 20
            ? 'El correo ya existe en Authentication. Se envió recuperación, pero valida que el documento use el UID real de Auth.'
            : 'Correo de recuperación enviado a $email.';

    messenger.showSnackBar(SnackBar(content: Text(message)));
  } on FirebaseAuthException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(_authErrorMessage(e))));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo enviar el acceso.')),
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
  final nameCtrl = TextEditingController(text: safeString(data, 'name'));
  final emailCtrl = TextEditingController(text: safeString(data, 'email'));
  final passwordCtrl = TextEditingController(
    text: _generateTemporaryPassword(),
  );
  final normalizedInitialZone = _normalizeLeaderZone(safeString(data, 'zone'));
  String zone = normalizedInitialZone.isEmpty
      ? _leaderZones.first
      : normalizedInitialZone;
  final zoneOptions = [
    ..._leaderZones,
    if (!_leaderZones.contains(zone)) zone,
  ];
  String status = safeString(data, 'status', 'activo');
  String role = safeString(data, 'role', 'leader');

  await showDialog(
    context: context,
    builder: (context) {
      var saving = false;

      return StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(docId == null ? 'Nuevo líder' : 'Editar líder'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (docId == null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEBFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Al guardar se creará la cuenta en Authentication, se registrará el perfil con el UID real y se enviará un correo para definir contraseña.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
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
                      enabled: docId == null,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Correo'),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return 'Requerido.';
                        if (!value.contains('@')) return 'Correo inválido.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    if (docId == null) ...[
                      TextFormField(
                        controller: passwordCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña temporal',
                          helperText:
                              'Se usa solo para crear la cuenta; el líder recibirá correo para cambiarla.',
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().length < 6) {
                            return 'Debe tener al menos 6 caracteres.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    DropdownButtonFormField<String>(
                      value: zone,
                      items: zoneOptions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => zone = v ?? _leaderZones.first,
                      decoration: const InputDecoration(labelText: 'Zona'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: status,
                      items: const [
                        DropdownMenuItem(
                          value: 'activo',
                          child: Text('activo'),
                        ),
                        DropdownMenuItem(
                          value: 'inactivo',
                          child: Text('inactivo'),
                        ),
                      ],
                      onChanged: (v) => status = v ?? 'activo',
                      decoration: const InputDecoration(labelText: 'Estado'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: role,
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('admin')),
                        DropdownMenuItem(
                          value: 'leader',
                          child: Text('leader'),
                        ),
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
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setLocal(() => saving = true);

                      final messenger = ScaffoldMessenger.of(context);
                      final email = emailCtrl.text.trim().toLowerCase();
                      final payload = {
                        'name': nameCtrl.text.trim(),
                        'email': email,
                        'zone': zone,
                        'status': status,
                        'role': role,
                        'createdAt': initial?['createdAt'] ??
                            FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      };
                      if (docId != null) {
                        payload['reports'] = FieldValue.delete();
                      }

                      try {
                        final targetDocId = docId ??
                            (await _ensureLeaderAuthAccess(
                              email: email,
                              temporaryPassword: passwordCtrl.text.trim(),
                            ))
                                .uid;

                        if (targetDocId == null) {
                          throw FirebaseAuthException(
                            code: 'email-already-in-use',
                          );
                        }

                        await db.collection('leaders').doc(targetDocId).set(
                              payload,
                              SetOptions(merge: true),
                            );

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              docId == null
                                  ? 'Líder creado y acceso enviado a $email.'
                                  : 'Líder actualizado.',
                            ),
                          ),
                        );
                      } on FirebaseAuthException catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(_authErrorMessage(e))),
                        );
                      } catch (_) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo guardar el líder.'),
                          ),
                        );
                      } finally {
                        if (context.mounted) {
                          setLocal(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      );
    },
  );
  nameCtrl.dispose();
  emailCtrl.dispose();
  passwordCtrl.dispose();
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
    final mobile = MediaQuery.of(context).size.width < 900;

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

                if (!mobile) {
                  return _CrudDataTable(
                    docs: docs,
                    fields: fields,
                    collection: collection,
                    currentUser: currentUser,
                  );
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

class _CrudDataTable extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final List<CrudField> fields;
  final String collection;
  final User currentUser;

  const _CrudDataTable({
    required this.docs,
    required this.fields,
    required this.collection,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 28,
            columns: [
              ...fields.map((field) => DataColumn(label: Text(field.label))),
              const DataColumn(label: Text('Acciones')),
            ],
            rows: docs.map((d) {
              final data = d.data();
              return DataRow(
                cells: [
                  ...fields.map((field) {
                    final width = field.keyboardType == TextInputType.number
                        ? 110.0
                        : (field.maxLines > 1 ? 360.0 : 220.0);
                    return DataCell(
                      _TableText(
                        safeString(data, field.key),
                        width: width,
                        strong: field == fields.first,
                      ),
                    );
                  }),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Editar',
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
                          tooltip: 'Eliminar',
                          onPressed: () =>
                              _deleteDoc(collection, d.id, context),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
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

                if (!mobile) {
                  return _JovenesDataTable(
                    docs: docs,
                    isAdminUser: isAdmin(widget.leader.role),
                    onHistory: (id, data) => _openHistory(context, id, data),
                    onExportLeader: (leaderId) =>
                        _exportJovenesXlsx(leaderId: leaderId),
                    onEdit: (id, data) => _showJovenDialog(
                      context,
                      currentUser: widget.currentUser,
                      docId: id,
                      initial: data,
                    ),
                    onDelete: (id) => _deleteDoc('jovenes', id, context),
                  );
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

class _JovenesDataTable extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool isAdminUser;
  final void Function(String id, Map<String, dynamic> data) onHistory;
  final void Function(String leaderId) onExportLeader;
  final void Function(String id, Map<String, dynamic> data) onEdit;
  final void Function(String id) onDelete;

  const _JovenesDataTable({
    required this.docs,
    required this.isAdminUser,
    required this.onHistory,
    required this.onExportLeader,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 28,
            columns: const [
              DataColumn(label: Text('Nombre')),
              DataColumn(label: Text('Edad')),
              DataColumn(label: Text('Teléfono')),
              DataColumn(label: Text('Formación')),
              DataColumn(label: Text('Bautismo')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: docs.map((d) {
              final data = d.data();
              return DataRow(
                cells: [
                  DataCell(
                    _TableText(
                      safeString(data, 'nombre', 'Sin nombre'),
                      width: 260,
                      strong: true,
                    ),
                  ),
                  DataCell(_TableText(safeString(data, 'edad'), width: 80)),
                  DataCell(
                    _TableText(safeString(data, 'telefono'), width: 150),
                  ),
                  DataCell(_TableText(_formationSummary(data), width: 300)),
                  DataCell(
                    Chip(
                      label: Text(safeBool(data, 'bautismo') ? 'Sí' : 'No'),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Historial',
                          onPressed: () => onHistory(d.id, data),
                          icon: const Icon(Icons.history),
                        ),
                        if (isAdminUser)
                          IconButton(
                            tooltip: 'Exportar por líder',
                            onPressed: () =>
                                onExportLeader(safeString(data, 'leaderId')),
                            icon: const Icon(Icons.file_download_outlined),
                          ),
                        IconButton(
                          tooltip: 'Editar',
                          onPressed: () => onEdit(d.id, data),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          onPressed: () => onDelete(d.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _formationSummary(Map<String, dynamic> data) {
    final completed = [
      if (safeBool(data, 'claseNuevo')) 'Nuevo',
      if (safeBool(data, 'claseDoctrina')) 'Doctrina',
      if (safeBool(data, 'claseMaestro')) 'Maestro',
      if (safeBool(data, 'claseLiderazgo')) 'Liderazgo',
    ];

    return completed.isEmpty ? 'Sin clases registradas' : completed.join(', ');
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
                      'Agenda y asistencia',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Prioriza la próxima actividad y abre el pase de asistencia desde la lista.',
                      style: TextStyle(color: Color(0xFF6B7280)),
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
                          color: const Color(0xFF4F46E5),
                        ),
                        _MiniStatCard(
                          label: 'Activas',
                          value: '$activas',
                          color: const Color(0xFF059669),
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
                      hintText: 'Buscar actividad...',
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
                      labelText: 'Estado',
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
                                color: Color(0xFF4F46E5),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Contexto para asistencia',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
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
                                          (e) => _normalizeLeaderZone(
                                            safeString(e.data(), 'zone'),
                                          ),
                                        )
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
  String attendanceSearch = '';
  bool bulkSaving = false;

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
      final zoneValues = _leaderZoneQueryValues(widget.selectedZone!);
      final leadersSnap = await db
          .collection('leaders')
          .where('zone', whereIn: zoneValues)
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

  Future<void> _setAttendanceFor(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> jovenes,
    bool attended,
  ) async {
    if (bulkSaving) return;
    final targets = jovenes.toList();
    if (targets.isEmpty) return;

    setState(() => bulkSaving = true);
    try {
      for (final joven in targets) {
        _localAttendance[joven.id] = attended;
        await _saveAttendance(joven.id, attended);
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            attended
                ? 'Se marcaron ${targets.length} jóvenes visibles como presentes.'
                : 'Se limpiaron ${targets.length} marcas visibles.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => bulkSaving = false);
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
            final filteredJovenes = attendanceSearch.isEmpty
                ? jovenes
                : jovenes.where((joven) {
                    final data = joven.data();
                    final name = safeString(data, 'nombre').toLowerCase();
                    final phone = safeString(data, 'telefono').toLowerCase();
                    return name.contains(attendanceSearch) ||
                        phone.contains(attendanceSearch);
                  }).toList();
            final presentCount = jovenes
                .where((joven) => _localAttendance[joven.id] == true)
                .length;
            final visiblePresentCount = filteredJovenes
                .where((joven) => _localAttendance[joven.id] == true)
                .length;

            return Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            Chip(
                              avatar:
                                  const Icon(Icons.people_outline, size: 18),
                              label: Text('${jovenes.length} jóvenes'),
                            ),
                            Chip(
                              avatar: const Icon(Icons.check_circle, size: 18),
                              label: Text('$presentCount presentes'),
                            ),
                            if (filteredJovenes.length != jovenes.length)
                              Chip(
                                avatar: const Icon(Icons.search, size: 18),
                                label: Text(
                                  '${filteredJovenes.length} visibles · $visiblePresentCount presentes',
                                ),
                              ),
                            if (widget.selectedLeaderId != null)
                              const Chip(
                                avatar: Icon(
                                  Icons.manage_accounts_outlined,
                                  size: 18,
                                ),
                                label: Text('Filtro por líder'),
                              ),
                            if (widget.selectedZone != null &&
                                widget.selectedZone!.isNotEmpty)
                              Chip(
                                avatar:
                                    const Icon(Icons.place_outlined, size: 18),
                                label: Text('Zona: ${widget.selectedZone}'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 320,
                              child: TextField(
                                decoration: const InputDecoration(
                                  hintText: 'Buscar joven o teléfono...',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (value) => setState(
                                  () => attendanceSearch =
                                      value.toLowerCase().trim(),
                                ),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: bulkSaving
                                  ? null
                                  : () => _setAttendanceFor(
                                        filteredJovenes,
                                        true,
                                      ),
                              icon: bulkSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.done_all),
                              label: const Text('Marcar visibles'),
                            ),
                            OutlinedButton.icon(
                              onPressed: bulkSaving
                                  ? null
                                  : () => _setAttendanceFor(
                                        filteredJovenes,
                                        false,
                                      ),
                              icon: const Icon(Icons.remove_done_outlined),
                              label: const Text('Limpiar visibles'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: filteredJovenes.isEmpty
                      ? const _EmptyData(
                          'No hay jóvenes que coincidan con la búsqueda.',
                        )
                      : ListView.separated(
                          itemCount: filteredJovenes.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 24),
                          itemBuilder: (context, index) {
                            final joven = filteredJovenes[index];
                            final jovenData = joven.data();
                            return _AttendanceTile(
                              jovenNombre: safeString(jovenData, 'nombre'),
                              telefono: safeString(jovenData, 'telefono'),
                              initialValue: _localAttendance[joven.id] ?? false,
                              onChanged: (value) async {
                                setState(
                                  () => _localAttendance[joven.id] = value,
                                );
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
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Panel(
          title: 'Perfil',
          eyebrow: 'CUENTA ACTIVA',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFEDEBFF),
                child: Text(
                  leader.name.trim().isEmpty
                      ? 'JV'
                      : leader.name.trim().characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leader.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser.email ?? leader.email,
                      style: const TextStyle(color: Color(0xFF6B7280)),
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
                            leader.status.isEmpty
                                ? 'Sin estado'
                                : leader.status,
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
        const SizedBox(height: 16),
        _Panel(
          title: 'Permisos',
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Nivel de acceso',
                value: isAdmin(leader.role)
                    ? 'Acceso completo al sistema'
                    : 'Gestión limitada a tus registros',
              ),
              const Divider(height: 24),
              _SettingsRow(
                icon: Icons.groups_outlined,
                title: 'Jóvenes y reportes',
                value: isAdmin(leader.role)
                    ? 'Puede consultar registros de todos los líderes'
                    : 'Solo puede consultar sus jóvenes y reportes',
              ),
              const Divider(height: 24),
              _SettingsRow(
                icon: Icons.event_available_outlined,
                title: 'Asistencia',
                value: isAdmin(leader.role)
                    ? 'Puede filtrar asistencia por líder o zona'
                    : 'Puede marcar asistencia de sus jóvenes',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Sesión',
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Cierra sesión al terminar de trabajar en un equipo compartido.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () => auth.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF4F46E5)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
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
