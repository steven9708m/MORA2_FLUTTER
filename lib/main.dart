import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const JvLeadersApp());
}

class JvLeadersApp extends StatelessWidget {
  const JvLeadersApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1D4ED8),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JV Líderes',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF0F172A),
          displayColor: const Color(0xFF0F172A),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          prefixIconColor: const Color(0xFF64748B),
          suffixIconColor: const Color(0xFF64748B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
          ),
        ),
        chipTheme: ThemeData.light().chipTheme.copyWith(
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFDCE7FF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide.none,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                  AUTH GATE                                 */
/* -------------------------------------------------------------------------- */

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData) {
          return const DashboardShell();
        }

        return const LoginPage();
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/* -------------------------------------------------------------------------- */
/*                                   LOGIN                                    */
/* -------------------------------------------------------------------------- */

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool loading = false;
  String? errorText;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorText = e.message ?? 'Ocurrió un error al iniciar sesión.';
      });
    } catch (_) {
      setState(() {
        errorText = 'Ocurrió un error inesperado.';
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> createLeaderUser() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('leaders')
          .doc(cred.user!.uid)
          .set({
            'name': emailCtrl.text.trim().split('@').first,
            'email': emailCtrl.text.trim(),
            'zone': 'Zona 1',
            'reports': 0,
            'status': 'Activo',
            'lastActivity': Timestamp.now(),
            'createdAt': Timestamp.now(),
          }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorText = e.message ?? 'No se pudo crear el usuario.';
      });
    } catch (_) {
      setState(() {
        errorText = 'Ocurrió un error inesperado.';
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SurfaceCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.groups_2,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'JV Líderes',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Inicia sesión para entrar al panel',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : signIn,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Iniciar sesión'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: loading ? null : createLeaderUser,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Crear usuario líder'),
                    ),
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

/* -------------------------------------------------------------------------- */
/*                                   MODELS                                   */
/* -------------------------------------------------------------------------- */

class NavItem {
  final String label;
  final IconData icon;

  const NavItem(this.label, this.icon);
}

class DashboardStat {
  final String title;
  final String value;
  final String change;
  final IconData icon;
  final Color color;

  const DashboardStat({
    required this.title,
    required this.value,
    required this.change,
    required this.icon,
    required this.color,
  });
}

class LeaderRecord {
  final String id;
  final String name;
  final String email;
  final String zone;
  final int reports;
  final DateTime? lastActivity;
  final String status;

  const LeaderRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.zone,
    required this.reports,
    required this.lastActivity,
    required this.status,
  });

  factory LeaderRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return LeaderRecord(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      zone: (data['zone'] ?? '').toString(),
      reports: (data['reports'] ?? 0) is int
          ? (data['reports'] ?? 0) as int
          : int.tryParse('${data['reports']}') ?? 0,
      lastActivity: (data['lastActivity'] is Timestamp)
          ? (data['lastActivity'] as Timestamp).toDate()
          : null,
      status: (data['status'] ?? 'Activo').toString(),
    );
  }
}

class RegistroRecord {
  final String id;
  final String leaderId;
  final String leaderName;
  final String zone;
  final String type;
  final String description;
  final String status;
  final DateTime? createdAt;

  const RegistroRecord({
    required this.id,
    required this.leaderId,
    required this.leaderName,
    required this.zone,
    required this.type,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory RegistroRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return RegistroRecord(
      id: doc.id,
      leaderId: (data['leaderId'] ?? '').toString(),
      leaderName: (data['leaderName'] ?? '').toString(),
      zone: (data['zone'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      status: (data['status'] ?? 'Pendiente').toString(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class ReporteRecord {
  final String id;
  final String leaderId;
  final String leaderName;
  final String zone;
  final String week;
  final int attendance;
  final int newPeople;
  final String status;
  final DateTime? createdAt;

  const ReporteRecord({
    required this.id,
    required this.leaderId,
    required this.leaderName,
    required this.zone,
    required this.week,
    required this.attendance,
    required this.newPeople,
    required this.status,
    required this.createdAt,
  });

  factory ReporteRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return ReporteRecord(
      id: doc.id,
      leaderId: (data['leaderId'] ?? '').toString(),
      leaderName: (data['leaderName'] ?? '').toString(),
      zone: (data['zone'] ?? '').toString(),
      week: (data['week'] ?? '').toString(),
      attendance: (data['attendance'] ?? 0) is int
          ? data['attendance'] as int
          : int.tryParse('${data['attendance']}') ?? 0,
      newPeople: (data['newPeople'] ?? 0) is int
          ? data['newPeople'] as int
          : int.tryParse('${data['newPeople']}') ?? 0,
      status: (data['status'] ?? 'Pendiente').toString(),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class ActivityEntry {
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  const ActivityEntry({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });
}

/* -------------------------------------------------------------------------- */
/*                                 FIRESTORE                                  */
/* -------------------------------------------------------------------------- */

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static Stream<List<LeaderRecord>> leadersStream() {
    return _db
        .collection('leaders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(LeaderRecord.fromDoc).toList();
        });
  }

  static Stream<List<RegistroRecord>> registrosStream() {
    return _db
        .collection('registros')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(RegistroRecord.fromDoc).toList();
        });
  }

  static Stream<List<ReporteRecord>> reportesStream() {
    return _db
        .collection('reportes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(ReporteRecord.fromDoc).toList();
        });
  }

  static Future<void> addLeader({
    required String name,
    required String email,
    required String zone,
    required int reports,
    required String status,
  }) async {
    await _db.collection('leaders').add({
      'name': name,
      'email': email,
      'zone': zone,
      'reports': reports,
      'status': status,
      'lastActivity': Timestamp.now(),
      'createdAt': Timestamp.now(),
    });
  }

  static Future<void> updateLeader({
    required String leaderId,
    required String name,
    required String email,
    required String zone,
    required int reports,
    required String status,
  }) async {
    await _db.collection('leaders').doc(leaderId).update({
      'name': name,
      'email': email,
      'zone': zone,
      'reports': reports,
      'status': status,
      'lastActivity': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  static Future<void> deleteLeader({required String leaderId}) async {
    final registros = await _db
        .collection('registros')
        .where('leaderId', isEqualTo: leaderId)
        .get();
    final reportes = await _db
        .collection('reportes')
        .where('leaderId', isEqualTo: leaderId)
        .get();

    final batch = _db.batch();
    for (final doc in registros.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in reportes.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('leaders').doc(leaderId));
    await batch.commit();
  }

  static Future<void> addRegistro({
    required String leaderId,
    required String leaderName,
    required String zone,
    required String type,
    required String description,
    required String status,
  }) async {
    await _db.collection('registros').add({
      'leaderId': leaderId,
      'leaderName': leaderName,
      'zone': zone,
      'type': type,
      'description': description,
      'status': status,
      'createdAt': Timestamp.now(),
    });

    await _db.collection('leaders').doc(leaderId).set({
      'lastActivity': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateRegistro({
    required String registroId,
    required String leaderId,
    required String leaderName,
    required String zone,
    required String type,
    required String description,
    required String status,
  }) async {
    await _db.collection('registros').doc(registroId).update({
      'leaderId': leaderId,
      'leaderName': leaderName,
      'zone': zone,
      'type': type,
      'description': description,
      'status': status,
      'updatedAt': Timestamp.now(),
    });

    await _db.collection('leaders').doc(leaderId).set({
      'lastActivity': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteRegistro({required String registroId}) async {
    await _db.collection('registros').doc(registroId).delete();
  }

  static Future<void> addReporte({
    required String leaderId,
    required String leaderName,
    required String zone,
    required String week,
    required int attendance,
    required int newPeople,
    required String status,
  }) async {
    await _db.collection('reportes').add({
      'leaderId': leaderId,
      'leaderName': leaderName,
      'zone': zone,
      'week': week,
      'attendance': attendance,
      'newPeople': newPeople,
      'status': status,
      'createdAt': Timestamp.now(),
    });

    await _db.collection('leaders').doc(leaderId).set({
      'reports': FieldValue.increment(1),
      'lastActivity': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateReporte({
    required String reporteId,
    required String oldLeaderId,
    required String leaderId,
    required String leaderName,
    required String zone,
    required String week,
    required int attendance,
    required int newPeople,
    required String status,
  }) async {
    final batch = _db.batch();

    batch.update(_db.collection('reportes').doc(reporteId), {
      'leaderId': leaderId,
      'leaderName': leaderName,
      'zone': zone,
      'week': week,
      'attendance': attendance,
      'newPeople': newPeople,
      'status': status,
      'updatedAt': Timestamp.now(),
    });

    if (oldLeaderId != leaderId) {
      batch.set(_db.collection('leaders').doc(oldLeaderId), {
        'reports': FieldValue.increment(-1),
      }, SetOptions(merge: true));
      batch.set(_db.collection('leaders').doc(leaderId), {
        'reports': FieldValue.increment(1),
        'lastActivity': Timestamp.now(),
      }, SetOptions(merge: true));
    } else {
      batch.set(_db.collection('leaders').doc(leaderId), {
        'lastActivity': Timestamp.now(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  static Future<void> deleteReporte({
    required String reporteId,
    required String leaderId,
  }) async {
    final batch = _db.batch();
    batch.delete(_db.collection('reportes').doc(reporteId));
    batch.set(_db.collection('leaders').doc(leaderId), {
      'reports': FieldValue.increment(-1),
      'lastActivity': Timestamp.now(),
    }, SetOptions(merge: true));
    await batch.commit();
  }
}

/* -------------------------------------------------------------------------- */
/*                                    DATA                                    */
/* -------------------------------------------------------------------------- */

const _navItems = <NavItem>[
  NavItem('Dashboard', Icons.dashboard_rounded),
  NavItem('Registros', Icons.receipt_long_rounded),
  NavItem('Reportes', Icons.bar_chart_rounded),
  NavItem('Configuración', Icons.settings_rounded),
];

const _activities = <ActivityEntry>[
  ActivityEntry(
    title: 'María Gómez',
    subtitle: 'Subió el reporte semanal',
    time: '12 min',
    color: Color(0xFF059669),
  ),
  ActivityEntry(
    title: 'Carlos Pérez',
    subtitle: 'Actualizó asistencia de líderes',
    time: '38 min',
    color: Color(0xFF2563EB),
  ),
  ActivityEntry(
    title: 'Ana Martínez',
    subtitle: 'Quedó marcada para revisión',
    time: '1 h',
    color: Color(0xFFF59E0B),
  ),
  ActivityEntry(
    title: 'Sofía Rodríguez',
    subtitle: 'Cerró seguimiento pendiente',
    time: '2 h',
    color: Color(0xFF7C3AED),
  ),
];

const _weekTrend = <double>[12, 15, 13, 18, 17, 21, 24];
const _zoneBars = <double>[78, 64, 89, 56, 72];

/* -------------------------------------------------------------------------- */
/*                                   SHELL                                    */
/* -------------------------------------------------------------------------- */

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int selectedIndex = 0;

  void onSelectPage(int index) {
    setState(() => selectedIndex = index);
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1150;
        final isTablet = constraints.maxWidth >= 760;

        return Scaffold(
          drawer: isDesktop
              ? null
              : AppDrawer(
                  selectedIndex: selectedIndex,
                  onSelect: (index) {
                    Navigator.of(context).pop();
                    onSelectPage(index);
                  },
                  onLogout: signOut,
                ),
          floatingActionButton: selectedIndex == 0
              ? FloatingActionButton.extended(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const AddLeaderDialog(),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar líder'),
                )
              : selectedIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const AddRegistroDialog(),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar registro'),
                )
              : selectedIndex == 2
              ? FloatingActionButton.extended(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const AddReporteDialog(),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar reporte'),
                )
              : null,
          body: SafeArea(
            child: Row(
              children: [
                if (isDesktop)
                  DesktopRail(
                    selectedIndex: selectedIndex,
                    onSelect: onSelectPage,
                    onLogout: signOut,
                  ),
                Expanded(
                  child: IndexedStack(
                    index: selectedIndex,
                    children: [
                      DashboardHomePage(
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                      ),
                      RegistrosPage(isDesktop: isDesktop, isTablet: isTablet),
                      ReportesPage(isDesktop: isDesktop, isTablet: isTablet),
                      ModulePlaceholderPage(
                        isDesktop: isDesktop,
                        title: 'Configuración',
                        subtitle: 'Espacio para ajustes generales del sistema.',
                        icon: Icons.settings_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DesktopRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const DesktopRail({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final extend = MediaQuery.of(context).size.width >= 1400;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: NavigationRail(
        extended: extend,
        backgroundColor: Colors.white,
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelect,
        minWidth: 76,
        minExtendedWidth: 230,
        groupAlignment: -0.9,
        indicatorColor: const Color(0xFFDCE7FF),
        selectedIconTheme: const IconThemeData(
          color: Color(0xFF1D4ED8),
          size: 24,
        ),
        unselectedIconTheme: const IconThemeData(
          color: Color(0xFF64748B),
          size: 22,
        ),
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 28),
          child: extend
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.groups_2, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JV Líderes',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Admin panel',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.groups_2, color: Colors.white),
                ),
        ),
        trailing: Padding(
          padding: const EdgeInsets.all(12),
          child: extend
              ? OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Salir'),
                )
              : IconButton(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                ),
        ),
        destinations: _navItems
            .map(
              (item) => NavigationRailDestination(
                icon: Icon(item.icon),
                label: Text(item.label),
              ),
            )
            .toList(),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.groups_2,
                    color: Color(0xFF1E3A8A),
                    size: 30,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'JV Líderes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Panel administrativo',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    selected: selectedIndex == index,
                    selectedTileColor: const Color(0xFFDCE7FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    onTap: () => onSelect(index),
                  ),
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Salir'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               DASHBOARD HOME                               */
/* -------------------------------------------------------------------------- */

class DashboardHomePage extends StatefulWidget {
  final bool isDesktop;
  final bool isTablet;

  const DashboardHomePage({
    super.key,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  State<DashboardHomePage> createState() => _DashboardHomePageState();
}

class _DashboardHomePageState extends State<DashboardHomePage> {
  final searchCtrl = TextEditingController();
  String selectedZone = 'Todas';
  String selectedStatus = 'Todos';

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  List<LeaderRecord> _applyFilters(List<LeaderRecord> leaders) {
    final query = searchCtrl.text.trim().toLowerCase();

    return leaders.where((leader) {
      final matchesSearch =
          query.isEmpty ||
          leader.name.toLowerCase().contains(query) ||
          leader.email.toLowerCase().contains(query) ||
          leader.zone.toLowerCase().contains(query) ||
          leader.status.toLowerCase().contains(query);

      final matchesZone =
          selectedZone == 'Todas' || leader.zone == selectedZone;
      final matchesStatus =
          selectedStatus == 'Todos' || leader.status == selectedStatus;

      return matchesSearch && matchesZone && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeaderRecord>>(
      stream: FirestoreService.leadersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error cargando datos: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final leaders = snapshot.data!;
        final filteredLeaders = _applyFilters(leaders);

        final activeCount = leaders
            .where((e) => e.status.toLowerCase() == 'activo')
            .length;
        final pendingCount = leaders
            .where((e) => e.status.toLowerCase() == 'pendiente')
            .length;
        final reviewCount = leaders
            .where((e) => e.status.toLowerCase().contains('revisión'))
            .length;
        final totalReports = leaders.fold<int>(0, (sum, e) => sum + e.reports);

        final stats = [
          DashboardStat(
            title: 'Líderes activos',
            value: '$activeCount',
            change: '${leaders.length} en total',
            icon: Icons.groups_2_outlined,
            color: const Color(0xFF2563EB),
          ),
          DashboardStat(
            title: 'Reportes',
            value: '$totalReports',
            change: 'acumulados',
            icon: Icons.insert_chart_outlined_rounded,
            color: const Color(0xFF059669),
          ),
          DashboardStat(
            title: 'Pendientes',
            value: '$pendingCount',
            change: 'por revisar',
            icon: Icons.schedule_outlined,
            color: const Color(0xFFF59E0B),
          ),
          DashboardStat(
            title: 'En revisión',
            value: '$reviewCount',
            change: 'estado actual',
            icon: Icons.task_alt_rounded,
            color: const Color(0xFF7C3AED),
          ),
        ];

        return SingleChildScrollView(
          padding: EdgeInsets.all(widget.isDesktop ? 28 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                isDesktop: widget.isDesktop,
                title: 'Dashboard General',
                subtitle: 'Resumen visual de líderes, reportes y seguimiento.',
              ),
              const SizedBox(height: 20),
              HeroBanner(
                isTablet: widget.isTablet,
                totalLeaders: leaders.length,
                totalReports: totalReports,
                completionPercent: leaders.isEmpty
                    ? 0
                    : (activeCount / leaders.length).clamp(0, 1),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                itemCount: stats.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: widget.isDesktop
                      ? 4
                      : (widget.isTablet ? 2 : 1),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: widget.isDesktop
                      ? 2.15
                      : (widget.isTablet ? 2.25 : 2.5),
                ),
                itemBuilder: (context, index) {
                  return StatCard(stat: stats[index]);
                },
              ),
              const SizedBox(height: 20),
              DashboardFiltersCard(
                isTablet: widget.isTablet,
                leadersCount: filteredLeaders.length,
                searchCtrl: searchCtrl,
                selectedZone: selectedZone,
                selectedStatus: selectedStatus,
                onSearchChanged: (_) => setState(() {}),
                onZoneChanged: (value) => setState(() => selectedZone = value!),
                onStatusChanged: (value) =>
                    setState(() => selectedStatus = value!),
                onClear: () {
                  setState(() {
                    searchCtrl.clear();
                    selectedZone = 'Todas';
                    selectedStatus = 'Todos';
                  });
                },
              ),
              const SizedBox(height: 20),
              if (widget.isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          DashboardChartsGrid(isWide: true),
                          const SizedBox(height: 20),
                          LeadersSection(
                            tableView: true,
                            leaders: filteredLeaders,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          ActivityCard(),
                          SizedBox(height: 20),
                          CompletionCard(),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    DashboardChartsGrid(isWide: widget.isTablet),
                    const SizedBox(height: 20),
                    const ActivityCard(),
                    const SizedBox(height: 20),
                    const CompletionCard(),
                    const SizedBox(height: 20),
                    LeadersSection(
                      tableView: widget.isTablet,
                      leaders: filteredLeaders,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                 REGISTROS                                  */
/* -------------------------------------------------------------------------- */

class RegistrosPage extends StatefulWidget {
  final bool isDesktop;
  final bool isTablet;

  const RegistrosPage({
    super.key,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  State<RegistrosPage> createState() => _RegistrosPageState();
}

class _RegistrosPageState extends State<RegistrosPage> {
  final searchCtrl = TextEditingController();
  String selectedZone = 'Todas';
  String selectedStatus = 'Todos';
  String selectedType = 'Todos';

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Sin fecha';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  List<RegistroRecord> _applyFilters(List<RegistroRecord> registros) {
    final query = searchCtrl.text.trim().toLowerCase();

    return registros.where((r) {
      final matchesSearch =
          query.isEmpty ||
          r.leaderName.toLowerCase().contains(query) ||
          r.zone.toLowerCase().contains(query) ||
          r.type.toLowerCase().contains(query) ||
          r.description.toLowerCase().contains(query) ||
          r.status.toLowerCase().contains(query);

      final matchesZone = selectedZone == 'Todas' || r.zone == selectedZone;
      final matchesStatus =
          selectedStatus == 'Todos' || r.status == selectedStatus;
      final matchesType = selectedType == 'Todos' || r.type == selectedType;

      return matchesSearch && matchesZone && matchesStatus && matchesType;
    }).toList();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RegistroRecord registro,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text(
          '¿Seguro que deseas eliminar el registro de ${registro.leaderName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirestoreService.deleteRegistro(registroId: registro.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registro eliminado correctamente')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar registro: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RegistroRecord>>(
      stream: FirestoreService.registrosStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error cargando registros: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final registros = _applyFilters(snapshot.data!);

        return SingleChildScrollView(
          padding: EdgeInsets.all(widget.isDesktop ? 28 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                isDesktop: widget.isDesktop,
                title: 'Registros',
                subtitle: 'Colección real conectada a Firestore.',
              ),
              const SizedBox(height: 20),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Buscar y filtrar',
                      subtitle: 'Filtra por texto, zona, tipo y estado.',
                      pillText: '${registros.length} resultados',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Buscar líder, descripción, zona o estado...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              searchCtrl.clear();
                              selectedZone = 'Todas';
                              selectedStatus = 'Todos';
                              selectedType = 'Todos';
                            });
                          },
                          icon: const Icon(Icons.restart_alt_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.isTablet)
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedZone,
                              decoration: const InputDecoration(
                                labelText: 'Zona',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Todas',
                                  child: Text('Todas'),
                                ),
                                DropdownMenuItem(
                                  value: 'Zona 1',
                                  child: Text('Zona 1'),
                                ),
                                DropdownMenuItem(
                                  value: 'Zona 2',
                                  child: Text('Zona 2'),
                                ),
                                DropdownMenuItem(
                                  value: 'Zona 3',
                                  child: Text('Zona 3'),
                                ),
                                DropdownMenuItem(
                                  value: 'Zona 4',
                                  child: Text('Zona 4'),
                                ),
                                DropdownMenuItem(
                                  value: 'Zona 5',
                                  child: Text('Zona 5'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => selectedZone = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Tipo',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Todos',
                                  child: Text('Todos'),
                                ),
                                DropdownMenuItem(
                                  value: 'Asistencia',
                                  child: Text('Asistencia'),
                                ),
                                DropdownMenuItem(
                                  value: 'Visita',
                                  child: Text('Visita'),
                                ),
                                DropdownMenuItem(
                                  value: 'Seguimiento',
                                  child: Text('Seguimiento'),
                                ),
                                DropdownMenuItem(
                                  value: 'Reunión',
                                  child: Text('Reunión'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => selectedType = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Estado',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Todos',
                                  child: Text('Todos'),
                                ),
                                DropdownMenuItem(
                                  value: 'Completado',
                                  child: Text('Completado'),
                                ),
                                DropdownMenuItem(
                                  value: 'Pendiente',
                                  child: Text('Pendiente'),
                                ),
                                DropdownMenuItem(
                                  value: 'En revisión',
                                  child: Text('En revisión'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => selectedStatus = v!),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: selectedZone,
                            decoration: const InputDecoration(
                              labelText: 'Zona',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Todas',
                                child: Text('Todas'),
                              ),
                              DropdownMenuItem(
                                value: 'Zona 1',
                                child: Text('Zona 1'),
                              ),
                              DropdownMenuItem(
                                value: 'Zona 2',
                                child: Text('Zona 2'),
                              ),
                              DropdownMenuItem(
                                value: 'Zona 3',
                                child: Text('Zona 3'),
                              ),
                              DropdownMenuItem(
                                value: 'Zona 4',
                                child: Text('Zona 4'),
                              ),
                              DropdownMenuItem(
                                value: 'Zona 5',
                                child: Text('Zona 5'),
                              ),
                            ],
                            onChanged: (v) => setState(() => selectedZone = v!),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Tipo',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Todos',
                                child: Text('Todos'),
                              ),
                              DropdownMenuItem(
                                value: 'Asistencia',
                                child: Text('Asistencia'),
                              ),
                              DropdownMenuItem(
                                value: 'Visita',
                                child: Text('Visita'),
                              ),
                              DropdownMenuItem(
                                value: 'Seguimiento',
                                child: Text('Seguimiento'),
                              ),
                              DropdownMenuItem(
                                value: 'Reunión',
                                child: Text('Reunión'),
                              ),
                            ],
                            onChanged: (v) => setState(() => selectedType = v!),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Estado',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Todos',
                                child: Text('Todos'),
                              ),
                              DropdownMenuItem(
                                value: 'Completado',
                                child: Text('Completado'),
                              ),
                              DropdownMenuItem(
                                value: 'Pendiente',
                                child: Text('Pendiente'),
                              ),
                              DropdownMenuItem(
                                value: 'En revisión',
                                child: Text('En revisión'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => selectedStatus = v!),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Listado de registros',
                      subtitle: 'Datos en tiempo real.',
                      pillText: '${registros.length} registros',
                    ),
                    const SizedBox(height: 16),
                    if (registros.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No hay registros con esos filtros.'),
                      )
                    else if (widget.isTablet)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Líder')),
                            DataColumn(label: Text('Zona')),
                            DataColumn(label: Text('Tipo')),
                            DataColumn(label: Text('Descripción')),
                            DataColumn(label: Text('Estado')),
                            DataColumn(label: Text('Fecha')),
                            DataColumn(label: Text('Acciones')),
                          ],
                          rows: registros.map((r) {
                            return DataRow(
                              cells: [
                                DataCell(Text(r.leaderName)),
                                DataCell(Text(r.zone)),
                                DataCell(Text(r.type)),
                                DataCell(Text(r.description)),
                                DataCell(StatusBadge(status: r.status)),
                                DataCell(Text(_formatDate(r.createdAt))),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Editar',
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          color: Color(0xFF2563EB),
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) =>
                                                EditRegistroDialog(registro: r),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        tooltip: 'Eliminar',
                                        icon: const Icon(
                                          Icons.delete_rounded,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          _confirmDelete(context, r);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      )
                    else
                      Column(
                        children: registros.map((r) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        backgroundColor: Color(0xFFDCE7FF),
                                        child: Icon(
                                          Icons.receipt_long_rounded,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.leaderName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              r.description,
                                              style: const TextStyle(
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusBadge(status: r.status),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      InfoChip(
                                        icon: Icons.place_outlined,
                                        text: r.zone,
                                      ),
                                      InfoChip(
                                        icon: Icons.category_outlined,
                                        text: r.type,
                                      ),
                                      InfoChip(
                                        icon: Icons.calendar_month_outlined,
                                        text: _formatDate(r.createdAt),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) =>
                                                EditRegistroDialog(registro: r),
                                          );
                                        },
                                        icon: const Icon(Icons.edit_rounded),
                                        label: const Text('Editar'),
                                      ),
                                      const SizedBox(width: 10),
                                      FilledButton.icon(
                                        onPressed: () {
                                          _confirmDelete(context, r);
                                        },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        icon: const Icon(Icons.delete_rounded),
                                        label: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ReportesPage extends StatefulWidget {
  final bool isDesktop;
  final bool isTablet;

  const ReportesPage({
    super.key,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final searchCtrl = TextEditingController();
  String selectedZone = 'Todas';
  String selectedStatus = 'Todos';

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Sin fecha';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  List<ReporteRecord> _applyFilters(List<ReporteRecord> reportes) {
    final query = searchCtrl.text.trim().toLowerCase();

    return reportes.where((r) {
      final matchesSearch =
          query.isEmpty ||
          r.leaderName.toLowerCase().contains(query) ||
          r.zone.toLowerCase().contains(query) ||
          r.week.toLowerCase().contains(query) ||
          r.status.toLowerCase().contains(query);

      final matchesZone = selectedZone == 'Todas' || r.zone == selectedZone;
      final matchesStatus =
          selectedStatus == 'Todos' || r.status == selectedStatus;

      return matchesSearch && matchesZone && matchesStatus;
    }).toList();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ReporteRecord reporte,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar reporte'),
        content: Text(
          '¿Seguro que deseas eliminar el reporte de ${reporte.leaderName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirestoreService.deleteReporte(
          reporteId: reporte.id,
          leaderId: reporte.leaderId,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reporte eliminado correctamente')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar reporte: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReporteRecord>>(
      stream: FirestoreService.reportesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error cargando reportes: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reportes = _applyFilters(snapshot.data!);
        final totalAttendance = reportes.fold<int>(
          0,
          (sum, item) => sum + item.attendance,
        );
        final totalNewPeople = reportes.fold<int>(
          0,
          (sum, item) => sum + item.newPeople,
        );

        return SingleChildScrollView(
          padding: EdgeInsets.all(widget.isDesktop ? 28 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                isDesktop: widget.isDesktop,
                title: 'Reportes',
                subtitle: 'Colección real conectada a Firestore.',
              ),
              const SizedBox(height: 20),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Buscar y filtrar',
                      subtitle: 'Filtra por texto, zona y estado.',
                      pillText: '${reportes.length} resultados',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Buscar líder, semana, zona o estado...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              searchCtrl.clear();
                              selectedZone = 'Todas';
                              selectedStatus = 'Todos';
                            });
                          },
                          icon: const Icon(Icons.restart_alt_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.isTablet)
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedZone,
                              decoration: const InputDecoration(
                                labelText: 'Zona',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Todas',
                                  child: Text('Todas'),
                                ),
                                DropdownMenuItem(
                                  value: 'Zona 1',
                                  child: Text('Zona 1'),
                                ),
                                DropdownMenuItem(
                                  value: 'Zona 2',
                                  child: Text('Zona 2'),
                                ),
                                DropdownMenuItem(
                                  value: 'Zona 3',
                                  child: Text('Zona 3'),
                                ),
                                DropdownMenuItem(
                                  value: 'Zona 4',
                                  child: Text('Zona 4'),
                                ),
                                DropdownMenuItem(
                                  value: 'Zona 5',
                                  child: Text('Zona 5'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => selectedZone = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Estado',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Todos',
                                  child: Text('Todos'),
                                ),
                                DropdownMenuItem(
                                  value: 'Enviado',
                                  child: Text('Enviado'),
                                ),
                                DropdownMenuItem(
                                  value: 'Pendiente',
                                  child: Text('Pendiente'),
                                ),
                                DropdownMenuItem(
                                  value: 'En revisión',
                                  child: Text('En revisión'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => selectedStatus = v!),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: selectedZone,
                            decoration: const InputDecoration(
                              labelText: 'Zona',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Todas',
                                child: Text('Todas'),
                              ),
                              DropdownMenuItem(
                                value: 'Zona 1',
                                child: Text('Zona 1'),
                              ),
                              DropdownMenuItem(
                                value: 'Zona 2',
                                child: Text('Zona 2'),
                              ),
                              DropdownMenuItem(
                                value: 'Zona 3',
                                child: Text('Zona 3'),
                              ),
                              DropdownMenuItem(
                                value: 'Zona 4',
                                child: Text('Zona 4'),
                              ),
                              DropdownMenuItem(
                                value: 'Zona 5',
                                child: Text('Zona 5'),
                              ),
                            ],
                            onChanged: (v) => setState(() => selectedZone = v!),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Estado',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Todos',
                                child: Text('Todos'),
                              ),
                              DropdownMenuItem(
                                value: 'Enviado',
                                child: Text('Enviado'),
                              ),
                              DropdownMenuItem(
                                value: 'Pendiente',
                                child: Text('Pendiente'),
                              ),
                              DropdownMenuItem(
                                value: 'En revisión',
                                child: Text('En revisión'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => selectedStatus = v!),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: widget.isDesktop ? 3 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: widget.isDesktop ? 2.4 : 2.8,
                children: [
                  StatCard(
                    stat: DashboardStat(
                      title: 'Total reportes',
                      value: '${reportes.length}',
                      change: 'filtrados',
                      icon: Icons.assessment_outlined,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  StatCard(
                    stat: DashboardStat(
                      title: 'Asistencia total',
                      value: '$totalAttendance',
                      change: 'acumulada',
                      icon: Icons.groups_2_outlined,
                      color: const Color(0xFF059669),
                    ),
                  ),
                  StatCard(
                    stat: DashboardStat(
                      title: 'Nuevas personas',
                      value: '$totalNewPeople',
                      change: 'reportadas',
                      icon: Icons.person_add_alt_1_outlined,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Listado de reportes',
                      subtitle: 'Datos en tiempo real.',
                      pillText: '${reportes.length} reportes',
                    ),
                    const SizedBox(height: 16),
                    if (reportes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No hay reportes con esos filtros.'),
                      )
                    else if (widget.isTablet)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Líder')),
                            DataColumn(label: Text('Zona')),
                            DataColumn(label: Text('Semana')),
                            DataColumn(label: Text('Asistencia')),
                            DataColumn(label: Text('Nuevos')),
                            DataColumn(label: Text('Estado')),
                            DataColumn(label: Text('Fecha')),
                            DataColumn(label: Text('Acciones')),
                          ],
                          rows: reportes.map((r) {
                            return DataRow(
                              cells: [
                                DataCell(Text(r.leaderName)),
                                DataCell(Text(r.zone)),
                                DataCell(Text(r.week)),
                                DataCell(Text('${r.attendance}')),
                                DataCell(Text('${r.newPeople}')),
                                DataCell(StatusBadge(status: r.status)),
                                DataCell(Text(_formatDate(r.createdAt))),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Editar',
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          color: Color(0xFF2563EB),
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) =>
                                                EditReporteDialog(reporte: r),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        tooltip: 'Eliminar',
                                        icon: const Icon(
                                          Icons.delete_rounded,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          _confirmDelete(context, r);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      )
                    else
                      Column(
                        children: reportes.map((r) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        backgroundColor: Color(0xFFDCE7FF),
                                        child: Icon(
                                          Icons.bar_chart_rounded,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.leaderName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              '${r.week} · ${r.zone}',
                                              style: const TextStyle(
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusBadge(status: r.status),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      InfoChip(
                                        icon: Icons.people_outline,
                                        text: 'Asistencia: ${r.attendance}',
                                      ),
                                      InfoChip(
                                        icon: Icons.person_add_alt,
                                        text: 'Nuevos: ${r.newPeople}',
                                      ),
                                      InfoChip(
                                        icon: Icons.calendar_month_outlined,
                                        text: _formatDate(r.createdAt),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) =>
                                                EditReporteDialog(reporte: r),
                                          );
                                        },
                                        icon: const Icon(Icons.edit_rounded),
                                        label: const Text('Editar'),
                                      ),
                                      const SizedBox(width: 10),
                                      FilledButton.icon(
                                        onPressed: () {
                                          _confirmDelete(context, r);
                                        },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        icon: const Icon(Icons.delete_rounded),
                                        label: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ModulePlaceholderPage extends StatelessWidget {
  final bool isDesktop;
  final String title;
  final String subtitle;
  final IconData icon;

  const ModulePlaceholderPage({
    super.key,
    required this.isDesktop,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(isDesktop: isDesktop, title: title, subtitle: subtitle),
          const SizedBox(height: 20),
          SurfaceCard(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE7FF),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(icon, size: 36, color: const Color(0xFF1D4ED8)),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '$title listo para conectar',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               COMMON WIDGETS                               */
/* -------------------------------------------------------------------------- */

class PageHeader extends StatelessWidget {
  final bool isDesktop;
  final String title;
  final String subtitle;

  const PageHeader({
    super.key,
    required this.isDesktop,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!isDesktop)
          Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: HeaderIconButton(
                icon: Icons.menu_rounded,
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        HeaderIconButton(
          icon: Icons.notifications_none_rounded,
          onPressed: () {},
        ),
        const SizedBox(width: 12),
        const CircleAvatar(
          radius: 22,
          backgroundColor: Color(0xFFDCE7FF),
          child: Icon(Icons.person, color: Color(0xFF1D4ED8)),
        ),
      ],
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: const Color(0xFF0F172A)),
        ),
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? pillText;

  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.pillText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        if (pillText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              pillText!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                 HERO BANNER                                */
/* -------------------------------------------------------------------------- */

class HeroBanner extends StatelessWidget {
  final bool isTablet;
  final int totalLeaders;
  final int totalReports;
  final double completionPercent;

  const HeroBanner({
    super.key,
    required this.isTablet,
    required this.totalLeaders,
    required this.totalReports,
    required this.completionPercent,
  });

  @override
  Widget build(BuildContext context) {
    final percentText = '${(completionPercent * 100).round()}%';

    final mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hola, equipo 👋',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const Text(
          'Dashboard ejecutivo para líderes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Revisa rendimiento semanal y datos en vivo desde Firestore.',
          style: TextStyle(color: Colors.white70, height: 1.45, fontSize: 14),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            BannerPill(
              icon: Icons.check_circle_outline_rounded,
              text: '$percentText cumplimiento',
            ),
            BannerPill(
              icon: Icons.groups_2_outlined,
              text: '$totalLeaders líderes',
            ),
            BannerPill(
              icon: Icons.bar_chart_rounded,
              text: '$totalReports reportes',
            ),
          ],
        ),
      ],
    );

    final sideCard = Container(
      width: 250,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Meta semanal',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 118,
            height: 118,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: completionPercent,
                    strokeWidth: 10,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      percentText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'completado',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: isTablet
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: mainContent),
                const SizedBox(width: 20),
                sideCard,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [mainContent, const SizedBox(height: 18), sideCard],
            ),
    );
  }
}

class BannerPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const BannerPill({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
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

/* -------------------------------------------------------------------------- */
/*                                   STATS                                    */
/* -------------------------------------------------------------------------- */

class StatCard extends StatelessWidget {
  final DashboardStat stat;

  const StatCard({super.key, required this.stat});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: stat.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(stat.icon, color: stat.color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stat.title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stat.change,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                  FILTERS                                   */
/* -------------------------------------------------------------------------- */

class DashboardFiltersCard extends StatelessWidget {
  final bool isTablet;
  final int leadersCount;
  final TextEditingController searchCtrl;
  final String selectedZone;
  final String selectedStatus;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onZoneChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onClear;

  const DashboardFiltersCard({
    super.key,
    required this.isTablet,
    required this.leadersCount,
    required this.searchCtrl,
    required this.selectedZone,
    required this.selectedStatus,
    required this.onSearchChanged,
    required this.onZoneChanged,
    required this.onStatusChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final zoneDropdown = DropdownButtonFormField<String>(
      initialValue: selectedZone,
      decoration: const InputDecoration(
        labelText: 'Zona',
        prefixIcon: Icon(Icons.place_outlined),
      ),
      items: const [
        DropdownMenuItem(value: 'Todas', child: Text('Todas')),
        DropdownMenuItem(value: 'Zona 1', child: Text('Zona 1')),
        DropdownMenuItem(value: 'Zona 2', child: Text('Zona 2')),
        DropdownMenuItem(value: 'Zona 3', child: Text('Zona 3')),
        DropdownMenuItem(value: 'Zona 4', child: Text('Zona 4')),
        DropdownMenuItem(value: 'Zona 5', child: Text('Zona 5')),
      ],
      onChanged: onZoneChanged,
    );

    final statusDropdown = DropdownButtonFormField<String>(
      initialValue: selectedStatus,
      decoration: const InputDecoration(
        labelText: 'Estado',
        prefixIcon: Icon(Icons.flag_outlined),
      ),
      items: const [
        DropdownMenuItem(value: 'Todos', child: Text('Todos')),
        DropdownMenuItem(value: 'Activo', child: Text('Activo')),
        DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente')),
        DropdownMenuItem(value: 'En revisión', child: Text('En revisión')),
      ],
      onChanged: onStatusChanged,
    );

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Búsqueda y filtros',
            subtitle: 'Conectado a Firestore.',
            pillText: '$leadersCount resultados',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchCtrl,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar líder, correo, zona o estado...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isTablet)
            Row(
              children: [
                Expanded(child: zoneDropdown),
                const SizedBox(width: 12),
                Expanded(child: statusDropdown),
              ],
            )
          else
            Column(
              children: [
                zoneDropdown,
                const SizedBox(height: 12),
                statusDropdown,
              ],
            ),
          const SizedBox(height: 12),
          if (isTablet)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const AddLeaderDialog(),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo líder'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const AddLeaderDialog(),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo líder'),
              ),
            ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                   CHARTS                                   */
/* -------------------------------------------------------------------------- */

class DashboardChartsGrid extends StatelessWidget {
  final bool isWide;

  const DashboardChartsGrid({super.key, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 2 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isWide ? 1.48 : 1.18,
      ),
      children: const [WeeklyTrendCard(), ZonePerformanceCard()],
    );
  }
}

class WeeklyTrendCard extends StatelessWidget {
  const WeeklyTrendCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SectionHeader(
            title: 'Tendencia semanal',
            subtitle: 'Visual demo',
            pillText: '+18%',
          ),
          SizedBox(height: 22),
          SizedBox(
            height: 190,
            child: CustomPaint(
              painter: LineChartPainter(
                values: _weekTrend,
                color: Color(0xFF2563EB),
              ),
              child: SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class ZonePerformanceCard extends StatelessWidget {
  const ZonePerformanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Rendimiento por zona',
            subtitle: 'Visual demo',
            pillText: '5 zonas',
          ),
          SizedBox(height: 24),
          SizedBox(height: 220, child: SimpleBarChart(values: _zoneBars)),
        ],
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const LineChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = (maxValue - minValue) == 0 ? 1 : (maxValue - minValue);

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = i * (size.width / (values.length - 1));
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 20)) - 10;
      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    final areaPath = Path()
      ..moveTo(points.first.dx, size.height)
      ..lineTo(points.first.dx, points.first.dy);

    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
      areaPath.lineTo(point.dx, point.dy);
    }

    areaPath
      ..lineTo(points.last.dx, size.height)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.22), color.withOpacity(0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawPath(areaPath, areaPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) => false;
}

class SimpleBarChart extends StatelessWidget {
  final List<double> values;

  const SimpleBarChart({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.reduce(math.max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(values.length, (index) {
        final value = values[index];
        final heightFactor = value / maxValue;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(value.toInt().toString()),
                const SizedBox(height: 8),
                Container(
                  height: 150 * heightFactor,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Z${index + 1}'),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                             TABLE / RESPONSIVE                             */
/* -------------------------------------------------------------------------- */

class LeadersSection extends StatelessWidget {
  final bool tableView;
  final List<LeaderRecord> leaders;

  const LeadersSection({
    super.key,
    required this.tableView,
    required this.leaders,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Sin fecha';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _confirmDelete(BuildContext context, LeaderRecord leader) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar líder'),
        content: Text(
          '¿Seguro que deseas eliminar a ${leader.name}? También se eliminarán sus registros y reportes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirestoreService.deleteLeader(leaderId: leader.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Líder eliminado correctamente')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar líder: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Líderes',
            subtitle: 'Datos en vivo desde Firestore.',
            pillText: '${leaders.length} registros',
          ),
          const SizedBox(height: 16),
          if (leaders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No hay líderes con esos filtros.'),
            )
          else
            tableView ? _buildTable(context) : _buildCards(context),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Líder')),
          DataColumn(label: Text('Correo')),
          DataColumn(label: Text('Zona')),
          DataColumn(label: Text('Reportes')),
          DataColumn(label: Text('Última actividad')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: leaders.map((leader) {
          return DataRow(
            cells: [
              DataCell(Text(leader.name)),
              DataCell(Text(leader.email)),
              DataCell(Text(leader.zone)),
              DataCell(Text('${leader.reports}')),
              DataCell(Text(_formatDate(leader.lastActivity))),
              DataCell(StatusBadge(status: leader.status)),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: Color(0xFF2563EB),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => EditLeaderDialog(leader: leader),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_rounded, color: Colors.red),
                      onPressed: () => _confirmDelete(context, leader),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCards(BuildContext context) {
    return Column(
      children: leaders.map((leader) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFDCE7FF),
                      child: Icon(Icons.person, color: Color(0xFF1D4ED8)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            leader.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            leader.email,
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: leader.status),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    InfoChip(icon: Icons.place_outlined, text: leader.zone),
                    InfoChip(
                      icon: Icons.description_outlined,
                      text: '${leader.reports} reportes',
                    ),
                    InfoChip(
                      icon: Icons.schedule_outlined,
                      text: _formatDate(leader.lastActivity),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => EditLeaderDialog(leader: leader),
                        );
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Editar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => _confirmDelete(context, leader),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      icon: const Icon(Icons.delete_rounded),
                      label: const Text('Eliminar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status.toLowerCase()) {
      case 'activo':
      case 'completado':
      case 'enviado':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      case 'pendiente':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
      default:
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF6D28D9);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const InfoChip({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                             ACTIVITY / PROGRESS                            */
/* -------------------------------------------------------------------------- */

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Actividad reciente',
            subtitle: 'Sección visual',
          ),
          const SizedBox(height: 18),
          ...List.generate(_activities.length, (index) {
            final activity = _activities[index];

            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: activity.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            activity.subtitle,
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Text(activity.time),
                  ],
                ),
                if (index != _activities.length - 1) const Divider(height: 24),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class CompletionCard extends StatelessWidget {
  const CompletionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Cumplimiento',
            subtitle: 'Estado general visual',
          ),
          SizedBox(height: 22),
          Center(child: ProgressCircle()),
          SizedBox(height: 24),
          ProgressMetric(label: 'Reportes enviados', value: 0.86),
          SizedBox(height: 16),
          ProgressMetric(label: 'Asistencia registrada', value: 0.69),
          SizedBox(height: 16),
          ProgressMetric(label: 'Seguimientos cerrados', value: 0.58),
        ],
      ),
    );
  }
}

class ProgressCircle extends StatelessWidget {
  const ProgressCircle({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 148,
      height: 148,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 0.73,
              strokeWidth: 14,
              backgroundColor: Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '73%',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text('completado', style: TextStyle(color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }
}

class ProgressMetric extends StatelessWidget {
  final String label;
  final double value;

  const ProgressMetric({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('$percent%'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: value,
            backgroundColor: const Color(0xFFE2E8F0),
            color: const Color(0xFF2563EB),
          ),
        ),
      ],
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                  DIALOGS                                   */
/* -------------------------------------------------------------------------- */

class AddLeaderDialog extends StatefulWidget {
  const AddLeaderDialog({super.key});

  @override
  State<AddLeaderDialog> createState() => _AddLeaderDialogState();
}

class _AddLeaderDialogState extends State<AddLeaderDialog> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final reportsCtrl = TextEditingController(text: '0');

  String zone = 'Zona 1';
  String status = 'Activo';
  bool loading = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    reportsCtrl.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      await FirestoreService.addLeader(
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        zone: zone,
        reports: int.tryParse(reportsCtrl.text.trim()) ?? 0,
        status: status,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar líder: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar líder'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa el nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Correo'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa el correo'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: zone,
                  items: const [
                    DropdownMenuItem(value: 'Zona 1', child: Text('Zona 1')),
                    DropdownMenuItem(value: 'Zona 2', child: Text('Zona 2')),
                    DropdownMenuItem(value: 'Zona 3', child: Text('Zona 3')),
                    DropdownMenuItem(value: 'Zona 4', child: Text('Zona 4')),
                    DropdownMenuItem(value: 'Zona 5', child: Text('Zona 5')),
                  ],
                  onChanged: (v) => setState(() => zone = v!),
                  decoration: const InputDecoration(labelText: 'Zona'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reportsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reportes'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'Activo', child: Text('Activo')),
                    DropdownMenuItem(
                      value: 'Pendiente',
                      child: Text('Pendiente'),
                    ),
                    DropdownMenuItem(
                      value: 'En revisión',
                      child: Text('En revisión'),
                    ),
                  ],
                  onChanged: (v) => setState(() => status = v!),
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: loading ? null : save,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class EditLeaderDialog extends StatefulWidget {
  final LeaderRecord leader;

  const EditLeaderDialog({super.key, required this.leader});

  @override
  State<EditLeaderDialog> createState() => _EditLeaderDialogState();
}

class _EditLeaderDialogState extends State<EditLeaderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController nameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController reportsCtrl;

  late String zone;
  late String status;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.leader.name);
    emailCtrl = TextEditingController(text: widget.leader.email);
    reportsCtrl = TextEditingController(text: '${widget.leader.reports}');
    zone = widget.leader.zone;
    status = widget.leader.status;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    reportsCtrl.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      await FirestoreService.updateLeader(
        leaderId: widget.leader.id,
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        zone: zone,
        reports: int.tryParse(reportsCtrl.text.trim()) ?? 0,
        status: status,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Líder actualizado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar líder: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar líder'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa el nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Correo'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa el correo'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: zone,
                  items: const [
                    DropdownMenuItem(value: 'Zona 1', child: Text('Zona 1')),
                    DropdownMenuItem(value: 'Zona 2', child: Text('Zona 2')),
                    DropdownMenuItem(value: 'Zona 3', child: Text('Zona 3')),
                    DropdownMenuItem(value: 'Zona 4', child: Text('Zona 4')),
                    DropdownMenuItem(value: 'Zona 5', child: Text('Zona 5')),
                  ],
                  onChanged: (v) => setState(() => zone = v!),
                  decoration: const InputDecoration(labelText: 'Zona'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reportsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reportes'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'Activo', child: Text('Activo')),
                    DropdownMenuItem(
                      value: 'Pendiente',
                      child: Text('Pendiente'),
                    ),
                    DropdownMenuItem(
                      value: 'En revisión',
                      child: Text('En revisión'),
                    ),
                  ],
                  onChanged: (v) => setState(() => status = v!),
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: loading ? null : save,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar cambios'),
        ),
      ],
    );
  }
}

class AddRegistroDialog extends StatefulWidget {
  const AddRegistroDialog({super.key});

  @override
  State<AddRegistroDialog> createState() => _AddRegistroDialogState();
}

class _AddRegistroDialogState extends State<AddRegistroDialog> {
  final _formKey = GlobalKey<FormState>();
  final descriptionCtrl = TextEditingController();
  final zoneCtrl = TextEditingController(text: 'Zona 1');

  String? leaderId;
  String? leaderName;
  String zone = 'Zona 1';
  String type = 'Asistencia';
  String status = 'Completado';
  bool loading = false;

  @override
  void dispose() {
    descriptionCtrl.dispose();
    zoneCtrl.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;
    if (leaderId == null || leaderName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un líder')));
      return;
    }

    setState(() => loading = true);

    try {
      await FirestoreService.addRegistro(
        leaderId: leaderId!,
        leaderName: leaderName!,
        zone: zone,
        type: type,
        description: descriptionCtrl.text.trim(),
        status: status,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar registro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar registro'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<List<LeaderRecord>>(
                  stream: FirestoreService.leadersStream(),
                  builder: (context, snapshot) {
                    final leaders = snapshot.data ?? [];

                    return DropdownButtonFormField<String>(
                      initialValue: leaderId,
                      decoration: const InputDecoration(labelText: 'Líder'),
                      items: leaders.map((leader) {
                        return DropdownMenuItem(
                          value: leader.id,
                          child: Text(leader.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        final selected = leaders.firstWhere(
                          (e) => e.id == value,
                        );
                        setState(() {
                          leaderId = selected.id;
                          leaderName = selected.name;
                          zone = selected.zone;
                          zoneCtrl.text = selected.zone;
                        });
                      },
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Selecciona un líder' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: zoneCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Zona'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Asistencia',
                      child: Text('Asistencia'),
                    ),
                    DropdownMenuItem(value: 'Visita', child: Text('Visita')),
                    DropdownMenuItem(
                      value: 'Seguimiento',
                      child: Text('Seguimiento'),
                    ),
                    DropdownMenuItem(value: 'Reunión', child: Text('Reunión')),
                  ],
                  onChanged: (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa una descripción'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Completado',
                      child: Text('Completado'),
                    ),
                    DropdownMenuItem(
                      value: 'Pendiente',
                      child: Text('Pendiente'),
                    ),
                    DropdownMenuItem(
                      value: 'En revisión',
                      child: Text('En revisión'),
                    ),
                  ],
                  onChanged: (v) => setState(() => status = v!),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: loading ? null : save,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class EditRegistroDialog extends StatefulWidget {
  final RegistroRecord registro;

  const EditRegistroDialog({super.key, required this.registro});

  @override
  State<EditRegistroDialog> createState() => _EditRegistroDialogState();
}

class _EditRegistroDialogState extends State<EditRegistroDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController descriptionCtrl;
  late final TextEditingController zoneCtrl;

  String? leaderId;
  String? leaderName;
  late String zone;
  late String type;
  late String status;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    descriptionCtrl = TextEditingController(text: widget.registro.description);
    zoneCtrl = TextEditingController(text: widget.registro.zone);

    leaderId = widget.registro.leaderId;
    leaderName = widget.registro.leaderName;
    zone = widget.registro.zone;
    type = widget.registro.type;
    status = widget.registro.status;
  }

  @override
  void dispose() {
    descriptionCtrl.dispose();
    zoneCtrl.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;
    if (leaderId == null || leaderName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un líder')));
      return;
    }

    setState(() => loading = true);

    try {
      await FirestoreService.updateRegistro(
        registroId: widget.registro.id,
        leaderId: leaderId!,
        leaderName: leaderName!,
        zone: zone,
        type: type,
        description: descriptionCtrl.text.trim(),
        status: status,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro actualizado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar registro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar registro'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<List<LeaderRecord>>(
                  stream: FirestoreService.leadersStream(),
                  builder: (context, snapshot) {
                    final leaders = snapshot.data ?? [];

                    return DropdownButtonFormField<String>(
                      initialValue: leaderId,
                      decoration: const InputDecoration(labelText: 'Líder'),
                      items: leaders.map((leader) {
                        return DropdownMenuItem(
                          value: leader.id,
                          child: Text(leader.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        final selected = leaders.firstWhere(
                          (e) => e.id == value,
                        );
                        setState(() {
                          leaderId = selected.id;
                          leaderName = selected.name;
                          zone = selected.zone;
                          zoneCtrl.text = selected.zone;
                        });
                      },
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Selecciona un líder' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: zoneCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Zona'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Asistencia',
                      child: Text('Asistencia'),
                    ),
                    DropdownMenuItem(value: 'Visita', child: Text('Visita')),
                    DropdownMenuItem(
                      value: 'Seguimiento',
                      child: Text('Seguimiento'),
                    ),
                    DropdownMenuItem(value: 'Reunión', child: Text('Reunión')),
                  ],
                  onChanged: (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa una descripción'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Completado',
                      child: Text('Completado'),
                    ),
                    DropdownMenuItem(
                      value: 'Pendiente',
                      child: Text('Pendiente'),
                    ),
                    DropdownMenuItem(
                      value: 'En revisión',
                      child: Text('En revisión'),
                    ),
                  ],
                  onChanged: (v) => setState(() => status = v!),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: loading ? null : save,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar cambios'),
        ),
      ],
    );
  }
}

class EditReporteDialog extends StatefulWidget {
  final ReporteRecord reporte;

  const EditReporteDialog({super.key, required this.reporte});

  @override
  State<EditReporteDialog> createState() => _EditReporteDialogState();
}

class _EditReporteDialogState extends State<EditReporteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController weekCtrl;
  late final TextEditingController attendanceCtrl;
  late final TextEditingController newPeopleCtrl;
  late final TextEditingController zoneCtrl;

  String? leaderId;
  String? leaderName;
  late String zone;
  late String status;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    weekCtrl = TextEditingController(text: widget.reporte.week);
    attendanceCtrl = TextEditingController(
      text: '${widget.reporte.attendance}',
    );
    newPeopleCtrl = TextEditingController(text: '${widget.reporte.newPeople}');
    zoneCtrl = TextEditingController(text: widget.reporte.zone);

    leaderId = widget.reporte.leaderId;
    leaderName = widget.reporte.leaderName;
    zone = widget.reporte.zone;
    status = widget.reporte.status;
  }

  @override
  void dispose() {
    weekCtrl.dispose();
    attendanceCtrl.dispose();
    newPeopleCtrl.dispose();
    zoneCtrl.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;
    if (leaderId == null || leaderName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un líder')));
      return;
    }

    setState(() => loading = true);

    try {
      await FirestoreService.updateReporte(
        reporteId: widget.reporte.id,
        oldLeaderId: widget.reporte.leaderId,
        leaderId: leaderId!,
        leaderName: leaderName!,
        zone: zone,
        week: weekCtrl.text.trim(),
        attendance: int.tryParse(attendanceCtrl.text.trim()) ?? 0,
        newPeople: int.tryParse(newPeopleCtrl.text.trim()) ?? 0,
        status: status,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte actualizado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar reporte: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar reporte'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<List<LeaderRecord>>(
                  stream: FirestoreService.leadersStream(),
                  builder: (context, snapshot) {
                    final leaders = snapshot.data ?? [];

                    return DropdownButtonFormField<String>(
                      initialValue: leaderId,
                      decoration: const InputDecoration(labelText: 'Líder'),
                      items: leaders.map((leader) {
                        return DropdownMenuItem(
                          value: leader.id,
                          child: Text(leader.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        final selected = leaders.firstWhere(
                          (e) => e.id == value,
                        );
                        setState(() {
                          leaderId = selected.id;
                          leaderName = selected.name;
                          zone = selected.zone;
                          zoneCtrl.text = selected.zone;
                        });
                      },
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Selecciona un líder' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: zoneCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Zona'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: weekCtrl,
                  decoration: const InputDecoration(labelText: 'Semana'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa la semana'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: attendanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Asistencia'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPeopleCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nuevas personas',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(value: 'Enviado', child: Text('Enviado')),
                    DropdownMenuItem(
                      value: 'Pendiente',
                      child: Text('Pendiente'),
                    ),
                    DropdownMenuItem(
                      value: 'En revisión',
                      child: Text('En revisión'),
                    ),
                  ],
                  onChanged: (v) => setState(() => status = v!),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: loading ? null : save,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar cambios'),
        ),
      ],
    );
  }
}

class AddReporteDialog extends StatefulWidget {
  const AddReporteDialog({super.key});

  @override
  State<AddReporteDialog> createState() => _AddReporteDialogState();
}

class _AddReporteDialogState extends State<AddReporteDialog> {
  final _formKey = GlobalKey<FormState>();
  final weekCtrl = TextEditingController();
  final attendanceCtrl = TextEditingController(text: '0');
  final newPeopleCtrl = TextEditingController(text: '0');
  final zoneCtrl = TextEditingController(text: 'Zona 1');

  String? leaderId;
  String? leaderName;
  String zone = 'Zona 1';
  String status = 'Enviado';
  bool loading = false;

  @override
  void dispose() {
    weekCtrl.dispose();
    attendanceCtrl.dispose();
    newPeopleCtrl.dispose();
    zoneCtrl.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;
    if (leaderId == null || leaderName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un líder')));
      return;
    }

    setState(() => loading = true);

    try {
      await FirestoreService.addReporte(
        leaderId: leaderId!,
        leaderName: leaderName!,
        zone: zone,
        week: weekCtrl.text.trim(),
        attendance: int.tryParse(attendanceCtrl.text.trim()) ?? 0,
        newPeople: int.tryParse(newPeopleCtrl.text.trim()) ?? 0,
        status: status,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar reporte: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar reporte'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<List<LeaderRecord>>(
                  stream: FirestoreService.leadersStream(),
                  builder: (context, snapshot) {
                    final leaders = snapshot.data ?? [];

                    return DropdownButtonFormField<String>(
                      initialValue: leaderId,
                      decoration: const InputDecoration(labelText: 'Líder'),
                      items: leaders.map((leader) {
                        return DropdownMenuItem(
                          value: leader.id,
                          child: Text(leader.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        final selected = leaders.firstWhere(
                          (e) => e.id == value,
                        );
                        setState(() {
                          leaderId = selected.id;
                          leaderName = selected.name;
                          zone = selected.zone;
                          zoneCtrl.text = selected.zone;
                        });
                      },
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Selecciona un líder' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: zoneCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Zona'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: weekCtrl,
                  decoration: const InputDecoration(labelText: 'Semana'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa la semana'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: attendanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Asistencia'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPeopleCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nuevas personas',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(value: 'Enviado', child: Text('Enviado')),
                    DropdownMenuItem(
                      value: 'Pendiente',
                      child: Text('Pendiente'),
                    ),
                    DropdownMenuItem(
                      value: 'En revisión',
                      child: Text('En revisión'),
                    ),
                  ],
                  onChanged: (v) => setState(() => status = v!),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: loading ? null : save,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
