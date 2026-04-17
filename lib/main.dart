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
                  if ((v ?? '').length < 6)
                    return 'Debe tener al menos 6 caracteres.';
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
                stream: db.collection('leaders').snapshots(),
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
              title: 'Líderes recientes',
              child: _RecentLeadersPanel(),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _Panel(
                    title: 'Jóvenes por líder',
                    child: _YoungPeopleByLeaderChart(
                      currentUser: currentUser,
                      leader: leader,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: _Panel(
                    title: 'Líderes recientes',
                    child: _RecentLeadersPanel(),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const _Panel(
            title: 'Asistencia por actividad',
            child: _AttendanceByActivityPanel(),
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
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 26,
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
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAdmin(leader.role)
                        ? 'Tienes acceso completo al sistema.'
                        : 'Aquí puedes gestionar tus jóvenes, reportes y asistencias.',
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

        return FutureBuilder<Map<String, String>>(
          future: fetchLeaderNames(),
          builder: (context, namesSnap) {
            final names = namesSnap.data ?? {};
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

class _AttendanceByActivityPanel extends StatelessWidget {
  const _AttendanceByActivityPanel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('actividades').snapshots(),
      builder: (context, actSnap) {
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
  final out = <_ActivityAttendanceSummary>[];
  for (final act in acts) {
    final asistenciaSnap = await db
        .collection('asistencias')
        .where('activityId', isEqualTo: act.id)
        .get();
    int attended = 0;
    for (final a in asistenciaSnap.docs) {
      if ((a.data()['attended'] ?? false) == true) attended++;
    }
    out.add(
      _ActivityAttendanceSummary(
        activityName: safeString(act.data(), 'nombre', 'Actividad'),
        attended: attended,
        total: asistenciaSnap.docs.length,
      ),
    );
  }
  out.sort((a, b) => b.attended.compareTo(a.attended));
  return out;
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
                  if (aTs is Timestamp && bTs is Timestamp)
                    return bTs.compareTo(aTs);
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

            if (docId == null) {
              await db.collection('leaders').add(payload);
            } else {
              await db.collection('leaders').doc(docId).set(
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
              payload[f.key] = ctrls[f.key]!.text.trim();
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
                      decoration: const InputDecoration(
                        labelText: 'Fecha de nacimiento (yyyy-MM-dd)',
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Requerido.' : null,
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
  final out = <_HistorialItem>[];
  for (final a in asistencias) {
    final data = a.data();
    final activityId = safeString(data, 'activityId');
    final act = await db.collection('actividades').doc(activityId).get();
    final actData = act.data() ?? {};
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

  Query<Map<String, dynamic>> _activitiesQuery() {
    return db.collection('actividades').orderBy('fecha', descending: true);
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
            if (isAdmin(widget.leader.role))
              FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: db.collection('leaders').get(),
                builder: (context, snap) {
                  final leaders = snap.data?.docs ?? [];
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: mobile ? double.infinity : 220,
                        child: DropdownButtonFormField<String?>(
                          value: selectedLeaderId,
                          decoration: const InputDecoration(
                            labelText: 'Filtrar por líder',
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
                                  safeString(e.data(), 'name', 'Sin nombre'),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => selectedLeaderId = v),
                        ),
                      ),
                      SizedBox(
                        width: mobile ? double.infinity : 220,
                        child: DropdownButtonFormField<String?>(
                          value: selectedZone,
                          decoration: const InputDecoration(
                            labelText: 'Filtrar por zona',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Todas'),
                            ),
                            ...leaders
                                .map((e) => safeString(e.data(), 'zone'))
                                .where((z) => z.isNotEmpty)
                                .toSet()
                                .map(
                                  (z) => DropdownMenuItem<String?>(
                                    value: z,
                                    child: Text(z),
                                  ),
                                ),
                          ],
                          onChanged: (v) => setState(() => selectedZone = v),
                        ),
                      ),
                    ],
                  );
                },
              ),
            FilledButton.icon(
              onPressed: () => _showActividadDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Nueva actividad'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Card(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _activitiesQuery().snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No hay actividades.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
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
                                safeString(data, 'nombre', 'Actividad'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_formatAnyDate(data["fecha"])} · ${safeString(data, "estado")}',
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: () => _openAttendance(
                                      context,
                                      d.id,
                                      data,
                                    ),
                                    icon: const Icon(Icons.how_to_reg),
                                    label: const Text('Asistencia'),
                                  ),
                                  IconButton.filledTonal(
                                    onPressed: () => _showActividadDialog(
                                      context,
                                      docId: d.id,
                                      initial: data,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton.filledTonal(
                                    onPressed: () => _deleteDoc(
                                      'actividades',
                                      d.id,
                                      context,
                                    ),
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
                      title: Text(safeString(data, 'nombre', 'Actividad')),
                      subtitle: Text(
                        '${_formatAnyDate(data["fecha"])} · ${safeString(data, "estado")}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _openAttendance(context, d.id, data),
                            icon: const Icon(Icons.how_to_reg),
                            label: const Text('Asistencia'),
                          ),
                          IconButton(
                            onPressed: () => _showActividadDialog(
                              context,
                              docId: d.id,
                              initial: data,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () =>
                                _deleteDoc('actividades', d.id, context),
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
                  decoration: const InputDecoration(
                    labelText: 'Fecha (yyyy-MM-dd)',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Requerido.' : null,
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

class _AsistenciaPageState extends State<AsistenciaPage> {
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

  Future<bool> _getAttendance(String jovenId) async {
    final snap = await db
        .collection('asistencias')
        .where('activityId', isEqualTo: widget.activityId)
        .where('jovenId', isEqualTo: jovenId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return false;
    return (snap.docs.first.data()['attended'] ?? false) == true;
  }

  Future<void> _saveAttendance(String jovenId, bool attended) async {
    final snap = await db
        .collection('asistencias')
        .where('activityId', isEqualTo: widget.activityId)
        .where('jovenId', isEqualTo: jovenId)
        .limit(1)
        .get();

    final payload = <String, dynamic>{
      'activityId': widget.activityId,
      'jovenId': jovenId,
      'attended': attended,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (snap.docs.isEmpty) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      await db.collection('asistencias').add(payload);
    } else {
      await db.collection('asistencias').doc(snap.docs.first.id).set(
            payload,
            SetOptions(merge: true),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityName = safeString(widget.activityData, 'nombre', 'Actividad');

    return Scaffold(
      appBar: AppBar(title: Text('Asistencia · $activityName')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          future: _loadJovenes(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final jovenes = snap.data!;
            if (jovenes.isEmpty) {
              return const Center(child: Text('No hay jóvenes para mostrar.'));
            }

            return ListView.separated(
              itemCount: jovenes.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final joven = jovenes[index];
                final data = joven.data();
                return FutureBuilder<bool>(
                  future: _getAttendance(joven.id),
                  builder: (context, attSnap) {
                    return _AttendanceTile(
                      jovenNombre: safeString(data, 'nombre'),
                      telefono: safeString(data, 'telefono'),
                      initialValue: attSnap.data ?? false,
                      onChanged: (value) => _saveAttendance(joven.id, value),
                    );
                  },
                );
              },
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
