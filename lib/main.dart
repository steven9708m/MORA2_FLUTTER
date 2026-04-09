// main.dart optimizado para producción (Opción 3 corregida)
// Corrección incluida:
// - CompletionCard arreglada
// - ProgressCircle compatible
// - main completo listo para reemplazar
//
// Mantiene:
// - UI moderna
// - Auth + Firestore unificados para crear líderes
// - Firestore usando mora2
// - creación con app secundaria para no cerrar sesión del admin

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

class AppCollections {
  static const leaders = 'leaders';
  static const registros = 'registros';
  static const reportes = 'reportes';
}

class AppCatalogs {
  static const zones = <String>[
    'Zona 1',
    'Zona 2',
    'Zona 3',
    'Zona 4',
    'Zona 5',
  ];

  static const leaderStatuses = <String>['Activo', 'Pendiente', 'En revisión'];

  static const registroStatuses = <String>[
    'Completado',
    'Pendiente',
    'En revisión',
  ];

  static const reporteStatuses = <String>[
    'Enviado',
    'Pendiente',
    'En revisión',
  ];

  static const registroTypes = <String>[
    'Asistencia',
    'Visita',
    'Seguimiento',
    'Reunión',
  ];
}

class AppUi {
  static void showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class Validators {
  static String? requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa $label';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa el correo';
    }
    final email = value.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!ok) return 'Ingresa un correo válido';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa la contraseña';
    }
    if (value.trim().length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }
}

class AuthService {
  static String mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Ese correo ya está registrado.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'operation-not-allowed':
        return 'Este método de autenticación no está habilitado.';
      case 'network-request-failed':
        return 'Error de red. Revisa tu conexión.';
      default:
        return e.message ?? 'Ocurrió un error con la autenticación.';
    }
  }

  static Future<void> createLeaderAccount({
    required String name,
    required String email,
    required String password,
    required String zone,
    String status = 'Activo',
  }) async {
    FirebaseApp? secondaryApp;

    try {
      final appName =
          'secondary-leader-${DateTime.now().microsecondsSinceEpoch}';

      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await FirestoreService.upsertLeaderProfile(
        leaderId: cred.user!.uid,
        name: name.trim(),
        email: email.trim(),
        zone: zone,
        reports: 0,
        status: status,
      );

      await secondaryAuth.signOut();
    } on FirebaseAuthException {
      rethrow;
    } catch (_) {
      rethrow;
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }
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
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC), Color(0xFFEDE9FE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Cargando panel...',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
  bool obscurePassword = true;

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
      final email = emailCtrl.text.trim();
      final password = passCtrl.text.trim();
      final inferredName = email.split('@').first;

      await AuthService.createLeaderAccount(
        name: inferredName,
        email: email,
        password: password,
        zone: 'Zona 1',
        status: 'Activo',
      );

      if (mounted) {
        AppUi.showSnackBar(context, 'Usuario líder creado correctamente');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorText = AuthService.mapFirebaseAuthError(e);
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

  Widget _buildBackgroundBubble({
    required double size,
    required Alignment alignment,
    required Color color,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFEFF6FF),
                  Color(0xFFF8FAFC),
                  Color(0xFFEDE9FE),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          _buildBackgroundBubble(
            size: 280,
            alignment: const Alignment(-1.1, -0.9),
            color: const Color(0x332563EB),
          ),
          _buildBackgroundBubble(
            size: 220,
            alignment: const Alignment(1.15, -0.65),
            color: const Color(0x227C3AED),
          ),
          _buildBackgroundBubble(
            size: 240,
            alignment: const Alignment(1.1, 0.9),
            color: const Color(0x22059669),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 880;

                    return twoColumns
                        ? Row(
                            children: [
                              const Expanded(child: LoginInfoPanel()),
                              const SizedBox(width: 28),
                              Expanded(
                                child: LoginFormCard(
                                  emailCtrl: emailCtrl,
                                  passCtrl: passCtrl,
                                  loading: loading,
                                  errorText: errorText,
                                  obscurePassword: obscurePassword,
                                  onTogglePassword: () {
                                    setState(() {
                                      obscurePassword = !obscurePassword;
                                    });
                                  },
                                  onSignIn: signIn,
                                  onCreateLeader: createLeaderUser,
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: LoginFormCard(
                                emailCtrl: emailCtrl,
                                passCtrl: passCtrl,
                                loading: loading,
                                errorText: errorText,
                                obscurePassword: obscurePassword,
                                onTogglePassword: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                                onSignIn: signIn,
                                onCreateLeader: createLeaderUser,
                              ),
                            ),
                          );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginInfoPanel extends StatelessWidget {
  const LoginInfoPanel({super.key});

  Widget _infoItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: const Color(0xFF1D4ED8)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF475569), height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.28),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: const Icon(
              Icons.groups_2_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'JV Líderes',
            style: TextStyle(
              fontSize: 40,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Un panel moderno para administrar líderes, reportes y registros con Firebase en tiempo real.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF475569),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 30),
          _infoItem(
            Icons.security_rounded,
            'Acceso seguro',
            'Inicio de sesión y creación de líderes conectados con Firebase Authentication.',
          ),
          const SizedBox(height: 18),
          _infoItem(
            Icons.dashboard_customize_rounded,
            'Panel visual',
            'Dashboard claro, profesional y preparado para crecer con tu ministerio.',
          ),
          const SizedBox(height: 18),
          _infoItem(
            Icons.cloud_done_rounded,
            'Datos en vivo',
            'Todo sincronizado con Firestore en la base mora2.',
          ),
        ],
      ),
    );
  }
}

class LoginFormCard extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool loading;
  final String? errorText;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onSignIn;
  final VoidCallback onCreateLeader;

  const LoginFormCard({
    super.key,
    required this.emailCtrl,
    required this.passCtrl,
    required this.loading,
    required this.errorText,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onSignIn,
    required this.onCreateLeader,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.lock_person_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Bienvenido',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Inicia sesión para acceder al panel administrativo',
            style: TextStyle(color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
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
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                errorText!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : onSignIn,
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
              onPressed: loading ? null : onCreateLeader,
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
  final IconData icon;

  const ActivityEntry({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
    required this.icon,
  });
}

/* -------------------------------------------------------------------------- */
/*                                 FIRESTORE                                  */
/* -------------------------------------------------------------------------- */

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'mora2',
  );

  static Stream<List<LeaderRecord>> leadersStream() {
    return _db
        .collection(AppCollections.leaders)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(LeaderRecord.fromDoc).toList());
  }

  static Stream<List<RegistroRecord>> registrosStream() {
    return _db
        .collection(AppCollections.registros)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(RegistroRecord.fromDoc).toList());
  }

  static Stream<List<ReporteRecord>> reportesStream() {
    return _db
        .collection(AppCollections.reportes)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ReporteRecord.fromDoc).toList());
  }

  static Future<void> upsertLeaderProfile({
    required String leaderId,
    required String name,
    required String email,
    required String zone,
    required int reports,
    required String status,
  }) async {
    await _db.collection(AppCollections.leaders).doc(leaderId).set({
      'name': name,
      'email': email,
      'zone': zone,
      'reports': reports,
      'status': status,
      'role': 'leader',
      'lastActivity': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> addRegistro({
    required String leaderId,
    required String leaderName,
    required String zone,
    required String type,
    required String description,
    required String status,
  }) async {
    await _db.collection(AppCollections.registros).add({
      'leaderId': leaderId,
      'leaderName': leaderName,
      'zone': zone,
      'type': type,
      'description': description,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection(AppCollections.leaders).doc(leaderId).set({
      'lastActivity': FieldValue.serverTimestamp(),
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
    await _db.collection(AppCollections.registros).doc(registroId).update({
      'leaderId': leaderId,
      'leaderName': leaderName,
      'zone': zone,
      'type': type,
      'description': description,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _db.collection(AppCollections.leaders).doc(leaderId).set({
      'lastActivity': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteRegistro({required String registroId}) async {
    await _db.collection(AppCollections.registros).doc(registroId).delete();
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
    await _db.collection(AppCollections.reportes).add({
      'leaderId': leaderId,
      'leaderName': leaderName,
      'zone': zone,
      'week': week,
      'attendance': attendance,
      'newPeople': newPeople,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection(AppCollections.leaders).doc(leaderId).set({
      'reports': FieldValue.increment(1),
      'lastActivity': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
        minExtendedWidth: 235,
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
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(18),
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
                            fontWeight: FontWeight.w900,
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(18),
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
                    fontWeight: FontWeight.w900,
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

class DashboardHomePage extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;

  const DashboardHomePage({
    super.key,
    required this.isDesktop,
    required this.isTablet,
  });

  List<ActivityEntry> _buildActivities(List<LeaderRecord> leaders) {
    return leaders.take(4).map((leader) {
      final status = leader.status.toLowerCase();
      final color = status == 'activo'
          ? const Color(0xFF059669)
          : status == 'pendiente'
          ? const Color(0xFFF59E0B)
          : const Color(0xFF7C3AED);

      return ActivityEntry(
        title: leader.name,
        subtitle: 'Estado actual: ${leader.status}',
        time: leader.lastActivity == null
            ? 'Sin fecha'
            : '${leader.lastActivity!.day}/${leader.lastActivity!.month}',
        color: color,
        icon: Icons.person_outline_rounded,
      );
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
        final activities = _buildActivities(leaders);

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
          padding: EdgeInsets.all(isDesktop ? 28 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                isDesktop: isDesktop,
                title: 'Dashboard General',
                subtitle: 'Resumen visual de líderes, reportes y seguimiento.',
              ),
              const SizedBox(height: 20),
              HeroBanner(
                isTablet: isTablet,
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
                  crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 1),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isDesktop ? 2.15 : (isTablet ? 2.25 : 2.5),
                ),
                itemBuilder: (context, index) {
                  return StatCard(stat: stats[index]);
                },
              ),
              const SizedBox(height: 20),
              DashboardFiltersCard(
                isTablet: isTablet,
                leadersCount: leaders.length,
              ),
              const SizedBox(height: 20),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          DashboardChartsGrid(isWide: true),
                          const SizedBox(height: 20),
                          LeadersSection(tableView: true, leaders: leaders),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          ActivityCard(activities: activities),
                          const SizedBox(height: 20),
                          CompletionCard(
                            leadersCount: leaders.length,
                            activeCount: activeCount,
                            pendingCount: pendingCount,
                            totalReports: totalReports,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    DashboardChartsGrid(isWide: isTablet),
                    const SizedBox(height: 20),
                    ActivityCard(activities: activities),
                    const SizedBox(height: 20),
                    CompletionCard(
                      leadersCount: leaders.length,
                      activeCount: activeCount,
                      pendingCount: pendingCount,
                      totalReports: totalReports,
                    ),
                    const SizedBox(height: 20),
                    LeadersSection(tableView: isTablet, leaders: leaders),
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

class RegistrosPage extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;

  const RegistrosPage({
    super.key,
    required this.isDesktop,
    required this.isTablet,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Sin fecha';
    return '${dt.day}/${dt.month}/${dt.year}';
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
          AppUi.showSnackBar(context, 'Registro eliminado correctamente');
        }
      } catch (e) {
        if (context.mounted) {
          AppUi.showSnackBar(context, 'Error al eliminar registro: $e');
        }
      }
    }
  }

  Widget _emptyState() {
    return const EmptyStateCard(
      icon: Icons.receipt_long_rounded,
      title: 'Todavía no hay registros',
      subtitle: 'Cuando agregues registros, aparecerán aquí en tiempo real.',
    );
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

        final registros = snapshot.data!;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 28 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                isDesktop: isDesktop,
                title: 'Registros',
                subtitle: 'Colección real conectada a Firestore.',
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
                      _emptyState()
                    else if (isTablet)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 28,
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
                                      SmallActionButton(
                                        tooltip: 'Editar',
                                        icon: Icons.edit_rounded,
                                        color: const Color(0xFF2563EB),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) =>
                                                EditRegistroDialog(registro: r),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      SmallActionButton(
                                        tooltip: 'Eliminar',
                                        icon: Icons.delete_rounded,
                                        color: Colors.red,
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
                            child: ModernInfoCard(
                              icon: Icons.receipt_long_rounded,
                              iconBg: const Color(0xFFDCE7FF),
                              iconColor: const Color(0xFF1D4ED8),
                              title: r.leaderName,
                              subtitle: r.description,
                              trailing: StatusBadge(status: r.status),
                              chips: [
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
                              footer: Row(
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

/* -------------------------------------------------------------------------- */
/*                                  REPORTES                                  */
/* -------------------------------------------------------------------------- */

class ReportesPage extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;

  const ReportesPage({
    super.key,
    required this.isDesktop,
    required this.isTablet,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Sin fecha';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _emptyState() {
    return const EmptyStateCard(
      icon: Icons.bar_chart_rounded,
      title: 'Todavía no hay reportes',
      subtitle: 'Cuando agregues reportes, aparecerán aquí en tiempo real.',
    );
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

        final reportes = snapshot.data!;
        final totalAttendance = reportes.fold<int>(
          0,
          (sum, item) => sum + item.attendance,
        );
        final totalNewPeople = reportes.fold<int>(
          0,
          (sum, item) => sum + item.newPeople,
        );

        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 28 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                isDesktop: isDesktop,
                title: 'Reportes',
                subtitle: 'Colección real conectada a Firestore.',
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: isDesktop ? 3 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 2.4 : 2.8,
                children: [
                  StatCard(
                    stat: DashboardStat(
                      title: 'Total reportes',
                      value: '${reportes.length}',
                      change: 'registrados',
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
                      _emptyState()
                    else if (isTablet)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 28,
                          columns: const [
                            DataColumn(label: Text('Líder')),
                            DataColumn(label: Text('Zona')),
                            DataColumn(label: Text('Semana')),
                            DataColumn(label: Text('Asistencia')),
                            DataColumn(label: Text('Nuevos')),
                            DataColumn(label: Text('Estado')),
                            DataColumn(label: Text('Fecha')),
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
                            child: ModernInfoCard(
                              icon: Icons.bar_chart_rounded,
                              iconBg: const Color(0xFFDCE7FF),
                              iconColor: const Color(0xFF1D4ED8),
                              title: r.leaderName,
                              subtitle: '${r.week} · ${r.zone}',
                              trailing: StatusBadge(status: r.status),
                              chips: [
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

/* -------------------------------------------------------------------------- */
/*                              PLACEHOLDER PAGE                              */
/* -------------------------------------------------------------------------- */

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
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE7FF),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Icon(icon, size: 38, color: const Color(0xFF1D4ED8)),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '$title listo para conectar',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
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
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
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
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.person, color: Colors.white),
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
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
                  fontWeight: FontWeight.w900,
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

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: const Color(0xFFDCE7FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 34, color: const Color(0xFF1D4ED8)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.45),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ModernInfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final List<Widget> chips;
  final Widget? footer;

  const ModernInfoCard({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.chips = const [],
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: iconBg,
                child: Icon(icon, color: iconColor),
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
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: chips),
          ],
          if (footer != null) ...[const SizedBox(height: 14), footer!],
        ],
      ),
    );
  }
}

class SmallActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const SmallActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
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
            fontWeight: FontWeight.w900,
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
        color: Colors.white.withOpacity(0.14),
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
                        fontWeight: FontWeight.w900,
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.24),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
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
                    fontWeight: FontWeight.w900,
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

  const DashboardFiltersCard({
    super.key,
    required this.isTablet,
    required this.leadersCount,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Búsqueda y filtros',
            subtitle: 'Conectado a Firestore.',
            pillText: '$leadersCount líderes',
          ),
          const SizedBox(height: 16),
          if (isTablet)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar líder, zona o estado...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const AddLeaderDialog(),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nuevo líder'),
                ),
              ],
            )
          else
            Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar líder, zona o estado...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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

  Widget _buildEmptyState() {
    return const EmptyStateCard(
      icon: Icons.groups_2_outlined,
      title: 'No hay líderes todavía',
      subtitle: 'Cuando crees líderes, aparecerán aquí en tiempo real.',
    );
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
            _buildEmptyState()
          else
            tableView ? _buildTable() : _buildCards(),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 28,
        columns: const [
          DataColumn(label: Text('Líder')),
          DataColumn(label: Text('Correo')),
          DataColumn(label: Text('Zona')),
          DataColumn(label: Text('Reportes')),
          DataColumn(label: Text('Última actividad')),
          DataColumn(label: Text('Estado')),
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
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCards() {
    return Column(
      children: leaders.map((leader) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ModernInfoCard(
            icon: Icons.person,
            iconBg: const Color(0xFFDCE7FF),
            iconColor: const Color(0xFF1D4ED8),
            title: leader.name,
            subtitle: leader.email,
            trailing: StatusBadge(status: leader.status),
            chips: [
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
  final List<ActivityEntry> activities;

  const ActivityCard({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Actividad reciente',
            subtitle: 'Basada en los líderes más recientes',
          ),
          const SizedBox(height: 18),
          if (activities.isEmpty)
            const EmptyStateCard(
              icon: Icons.timeline_rounded,
              title: 'Sin actividad reciente',
              subtitle:
                  'A medida que trabajes con líderes, verás actividad aquí.',
            )
          else
            ...List.generate(activities.length, (index) {
              final activity = activities[index];

              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: activity.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(activity.icon, color: activity.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
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
                  if (index != activities.length - 1) const Divider(height: 24),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class CompletionCard extends StatelessWidget {
  final int leadersCount;
  final int activeCount;
  final int pendingCount;
  final int totalReports;

  const CompletionCard({
    super.key,
    required this.leadersCount,
    required this.activeCount,
    required this.pendingCount,
    required this.totalReports,
  });

  @override
  Widget build(BuildContext context) {
    final double leadersPercent = leadersCount == 0
        ? 0.0
        : (activeCount / leadersCount).clamp(0.0, 1.0);

    final double pendingPercent = leadersCount == 0
        ? 0.0
        : (pendingCount / leadersCount).clamp(0.0, 1.0);

    final double reportsPercent = leadersCount == 0
        ? 0.0
        : (totalReports / (leadersCount * 2)).clamp(0.0, 1.0);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Cumplimiento',
            subtitle: 'Resumen general del estado del panel',
          ),
          const SizedBox(height: 22),
          Center(child: ProgressCircle(value: leadersPercent)),
          const SizedBox(height: 24),
          ProgressMetric(label: 'Líderes activos', value: leadersPercent),
          const SizedBox(height: 16),
          ProgressMetric(label: 'Pendientes', value: pendingPercent),
          const SizedBox(height: 16),
          ProgressMetric(label: 'Carga de reportes', value: reportsPercent),
        ],
      ),
    );
  }
}

class ProgressCircle extends StatelessWidget {
  final double value;

  const ProgressCircle({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();

    return SizedBox(
      width: 148,
      height: 148,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 14,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF2563EB),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'completado',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
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
  final passwordCtrl = TextEditingController();

  String zone = AppCatalogs.zones.first;
  String status = AppCatalogs.leaderStatuses.first;
  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      await AuthService.createLeaderAccount(
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
        zone: zone,
        status: status,
      );

      if (!mounted) return;
      Navigator.pop(context);
      AppUi.showSnackBar(context, 'Líder creado correctamente');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      AppUi.showSnackBar(context, AuthService.mapFirebaseAuthError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      AppUi.showSnackBar(context, 'Error al crear líder: $e');
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
                  validator: (v) => Validators.requiredText(v, 'el nombre'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Correo'),
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => obscurePassword = !obscurePassword);
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: zone,
                  items: AppCatalogs.zones
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => zone = v!),
                  decoration: const InputDecoration(labelText: 'Zona'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: AppCatalogs.leaderStatuses
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
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
              : const Text('Crear líder'),
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
  final zoneCtrl = TextEditingController(text: AppCatalogs.zones.first);

  String? leaderId;
  String? leaderName;
  String zone = AppCatalogs.zones.first;
  String type = AppCatalogs.registroTypes.first;
  String status = AppCatalogs.registroStatuses.first;
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
      AppUi.showSnackBar(context, 'Selecciona un líder');
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

      if (!mounted) return;
      Navigator.pop(context);
      AppUi.showSnackBar(context, 'Registro guardado correctamente');
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      AppUi.showSnackBar(context, 'Error al guardar registro: $e');
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
                  items: AppCatalogs.registroTypes
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  validator: (v) =>
                      Validators.requiredText(v, 'una descripción'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: AppCatalogs.registroStatuses
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
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
      AppUi.showSnackBar(context, 'Selecciona un líder');
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

      if (!mounted) return;
      Navigator.pop(context);
      AppUi.showSnackBar(context, 'Registro actualizado correctamente');
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      AppUi.showSnackBar(context, 'Error al actualizar registro: $e');
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
                  items: AppCatalogs.registroTypes
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  validator: (v) =>
                      Validators.requiredText(v, 'una descripción'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: AppCatalogs.registroStatuses
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
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
  final zoneCtrl = TextEditingController(text: AppCatalogs.zones.first);

  String? leaderId;
  String? leaderName;
  String zone = AppCatalogs.zones.first;
  String status = AppCatalogs.reporteStatuses.first;
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
      AppUi.showSnackBar(context, 'Selecciona un líder');
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

      if (!mounted) return;
      Navigator.pop(context);
      AppUi.showSnackBar(context, 'Reporte guardado correctamente');
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      AppUi.showSnackBar(context, 'Error al guardar reporte: $e');
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
                  validator: (v) => Validators.requiredText(v, 'la semana'),
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
                  items: AppCatalogs.reporteStatuses
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
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
