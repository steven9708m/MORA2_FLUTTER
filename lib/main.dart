import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

enum DashboardRange { all, last30Days, thisMonth, thisYear }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3B82F6),
        brightness: Brightness.light,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF111827),
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.4),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const HomePage();
          }

          return const LoginPage();
        },
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
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool isRegisterMode = false;
  bool obscurePassword = true;

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa correo y contraseña.")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      if (isRegisterMode) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Ocurrió un error.";
      switch (e.code) {
        case "user-not-found":
          message = "No existe un usuario con ese correo.";
          break;
        case "wrong-password":
          message = "Contraseña incorrecta.";
          break;
        case "email-already-in-use":
          message = "Ese correo ya está registrado.";
          break;
        case "invalid-email":
          message = "Correo inválido.";
          break;
        case "weak-password":
          message = "La contraseña es muy débil.";
          break;
        case "invalid-credential":
          message = "Credenciales inválidas.";
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = isRegisterMode ? "Crear cuenta" : "Iniciar sesión";
    final buttonText = isRegisterMode ? "Registrarme" : "Entrar";
    final toggleText = isRegisterMode
        ? "¿Ya tienes cuenta? Inicia sesión"
        : "¿No tienes cuenta? Regístrate";

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: const Color(0xFFEFF6FF),
                      ),
                      child: const Icon(
                        Icons.groups_2_outlined,
                        size: 36,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Sistema de gestión del ministerio juvenil",
                      style: TextStyle(color: Color(0xFF6B7280)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: "Correo",
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Contraseña",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => obscurePassword = !obscurePassword);
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : submit,
                        child: isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(buttonText),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              setState(() {
                                isRegisterMode = !isRegisterMode;
                              });
                            },
                      child: Text(toggleText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  final pages = const [
    LeadersPage(),
    YouthsPage(),
    AttendancePage(),
    ReportsPage(),
    DashboardPage(),
  ];

  final titles = const [
    "Líderes",
    "Jóvenes",
    "Asistencia",
    "Reportes",
    "Dashboard",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: "Cerrar sesión",
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: pages[index],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: "Líderes"),
          NavigationDestination(icon: Icon(Icons.groups), label: "Jóvenes"),
          NavigationDestination(
            icon: Icon(Icons.checklist),
            label: "Asistencia",
          ),
          NavigationDestination(icon: Icon(Icons.analytics), label: "Reportes"),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: "Dashboard",
          ),
        ],
      ),
    );
  }
}

class LeadersPage extends StatefulWidget {
  const LeadersPage({super.key});

  @override
  State<LeadersPage> createState() => _LeadersPageState();
}

class _LeadersPageState extends State<LeadersPage> {
  final TextEditingController nameController = TextEditingController();
  late final FirebaseFirestore db;

  @override
  void initState() {
    super.initState();
    db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: "mora2",
    );
  }

  Future<void> addLeader() async {
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    try {
      await db.collection("leaders").add({
        "name": name,
        "createdAt": Timestamp.now(),
      });
      nameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ Líder guardado")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error guardando líder: $e")));
      }
    }
  }

  Future<void> diagnosticsGetLeaders() async {
    try {
      final snap = await db
          .collection("leaders")
          .orderBy("createdAt", descending: true)
          .limit(5)
          .get();

      debugPrint("✅ mora2 leaders count (últimos 5): ${snap.docs.length}");
      for (final d in snap.docs) {
        debugPrint(" - ${d.id} => ${d.data()}");
      }
    } catch (e) {
      debugPrint("❌ Diagnóstico mora2 error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Nombre del líder",
                  ),
                  onSubmitted: (_) => addLeader(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: addLeader,
                child: const Text("Guardar"),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.bug_report),
            label: const Text("Diagnóstico: leer leaders (get) en mora2"),
            onPressed: diagnosticsGetLeaders,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db
                .collection("leaders")
                .orderBy("createdAt", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final leaders = snapshot.data!.docs;
              if (leaders.isEmpty) {
                return const Center(
                  child: Text("No hay líderes registrados en mora2"),
                );
              }

              return ListView.builder(
                itemCount: leaders.length,
                itemBuilder: (context, index) {
                  final leader = leaders[index];
                  final data = leader.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text((data["name"] ?? "").toString()),
                    subtitle: Text("docId: ${leader.id}"),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class YouthsPage extends StatefulWidget {
  const YouthsPage({super.key});

  @override
  State<YouthsPage> createState() => _YouthsPageState();
}

class _YouthsPageState extends State<YouthsPage> {
  late final FirebaseFirestore db;

  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();

  String? selectedLeaderId;
  String spiritualLevel = "nuevos";

  final spiritualLevels = const [
    "nuevos",
    "doctrina",
    "bautismo",
    "maestro_ninos",
    "liderazgo",
  ];

  @override
  void initState() {
    super.initState();
    db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: "mora2",
    );
  }

  Future<void> addYouth() async {
    final name = fullNameController.text.trim();
    final phone = phoneController.text.trim();

    if (selectedLeaderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona un líder primero.")),
      );
      return;
    }
    if (name.isEmpty) return;

    try {
      await db.collection("youths").add({
        "fullName": name,
        "phone": phone,
        "leaderId": selectedLeaderId,
        "spiritualLevel": spiritualLevel,
        "createdAt": Timestamp.now(),
      });

      fullNameController.clear();
      phoneController.clear();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ Joven guardado")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
      }
    }
  }

  Future<void> updateYouthLevel(String youthId, String newLevel) async {
    try {
      await db.collection("youths").doc(youthId).update({
        "spiritualLevel": newLevel,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error actualizando: $e")));
      }
    }
  }

  Future<void> deleteYouth(String youthId) async {
    try {
      await db.collection("youths").doc(youthId).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error eliminando: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<QuerySnapshot>(
            stream: db
                .collection("leaders")
                .orderBy("createdAt", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              final leaders = snapshot.data!.docs;

              if (leaders.isEmpty) {
                return const Text(
                  "Primero registra al menos 1 líder en la pestaña Líderes.",
                );
              }

              selectedLeaderId ??= leaders.first.id;

              return Row(
                children: [
                  const Text("Líder: "),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedLeaderId,
                      items: leaders.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final name = (data["name"] ?? "").toString();
                        return DropdownMenuItem(
                          value: d.id,
                          child: Text(name.isEmpty ? d.id : name),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() {
                        selectedLeaderId = val;
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(
                  labelText: "Nombre del joven",
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: "Teléfono (opcional)",
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text("Nivel: "),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: spiritualLevel,
                      items: spiritualLevels
                          .map(
                            (lvl) =>
                                DropdownMenuItem(value: lvl, child: Text(lvl)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() {
                        spiritualLevel = val ?? "nuevos";
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: addYouth,
                    child: const Text("Guardar"),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: selectedLeaderId == null
              ? const Center(child: Text("Selecciona un líder."))
              : StreamBuilder<QuerySnapshot>(
                  stream: db
                      .collection("youths")
                      .where("leaderId", isEqualTo: selectedLeaderId)
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final youths = snapshot.data!.docs;
                    if (youths.isEmpty) {
                      return const Center(
                        child: Text(
                          "No hay jóvenes registrados para este líder.",
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: youths.length,
                      itemBuilder: (context, index) {
                        final doc = youths[index];
                        final data = doc.data() as Map<String, dynamic>;

                        final fullName = (data["fullName"] ?? "").toString();
                        final phone = (data["phone"] ?? "").toString();
                        final level = (data["spiritualLevel"] ?? "nuevos")
                            .toString();

                        return ListTile(
                          title: Text(fullName.isEmpty ? doc.id : fullName),
                          subtitle: Text(
                            phone.isEmpty ? "Sin teléfono" : phone,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DropdownButton<String>(
                                value: level,
                                items: spiritualLevels
                                    .map(
                                      (lvl) => DropdownMenuItem(
                                        value: lvl,
                                        child: Text(lvl),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val == null) return;
                                  updateYouthLevel(doc.id, val);
                                },
                              ),
                              IconButton(
                                tooltip: "Eliminar",
                                icon: const Icon(Icons.delete),
                                onPressed: () => deleteYouth(doc.id),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late final FirebaseFirestore db;

  String? selectedLeaderId;
  String? selectedEventId;
  DateTime selectedDate = DateTime.now();

  final Map<String, bool> presentMap = {};
  final eventNameController = TextEditingController();
  String eventType = "virtual";

  @override
  void initState() {
    super.initState();
    db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: "mora2",
    );
  }

  String dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day";
  }

  Future<void> createEvent() async {
    final name = eventNameController.text.trim();
    if (name.isEmpty) return;

    try {
      await db.collection("events").add({
        "name": name,
        "type": eventType,
        "active": true,
        "createdAt": Timestamp.now(),
      });
      eventNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ Evento creado")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error creando evento: $e")));
      }
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        presentMap.clear();
      });
    }
  }

  Future<void> loadYouthsForLeader() async {
    if (selectedLeaderId == null) return;

    final snap = await db
        .collection("youths")
        .where("leaderId", isEqualTo: selectedLeaderId)
        .get();

    setState(() {
      presentMap.clear();
      for (final d in snap.docs) {
        presentMap[d.id] = false;
      }
    });
  }

  Future<void> saveAttendance() async {
    if (selectedLeaderId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Selecciona un líder.")));
      return;
    }
    if (selectedEventId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Selecciona un evento.")));
      return;
    }
    if (presentMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No hay jóvenes cargados para este líder."),
        ),
      );
      return;
    }

    try {
      final eventDoc = await db.collection("events").doc(selectedEventId).get();
      final eventName = (eventDoc.data()?["name"] ?? "").toString();

      final sessionRef = await db.collection("attendance_sessions").add({
        "leaderId": selectedLeaderId,
        "eventId": selectedEventId,
        "eventName": eventName,
        "dateKey": dateKey(selectedDate),
        "createdAt": Timestamp.now(),
      });

      final batch = db.batch();
      presentMap.forEach((youthId, present) {
        final markRef = db.collection("attendance_marks").doc();
        batch.set(markRef, {
          "sessionId": sessionRef.id,
          "youthId": youthId,
          "present": present,
          "createdAt": Timestamp.now(),
        });
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ Asistencia guardada")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error guardando asistencia: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = dateKey(selectedDate);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Crear evento (solo 1 vez)"),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: eventNameController,
                      decoration: const InputDecoration(
                        labelText: "Nombre del evento (ej: Sábado 8pm Virtual)",
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: eventType,
                    items: const [
                      DropdownMenuItem(
                        value: "virtual",
                        child: Text("virtual"),
                      ),
                      DropdownMenuItem(
                        value: "presencial",
                        child: Text("presencial"),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => eventType = v ?? "virtual"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: createEvent,
                    child: const Text("Crear"),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: db.collection("leaders").snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const LinearProgressIndicator();
                  final leaders = snap.data!.docs;
                  if (leaders.isEmpty) {
                    return const Text("Crea líderes primero.");
                  }
                  selectedLeaderId ??= leaders.first.id;

                  return Row(
                    children: [
                      const Text("Líder: "),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedLeaderId,
                          items: leaders.map((d) {
                            final name =
                                ((d.data() as Map<String, dynamic>)["name"] ??
                                        "")
                                    .toString();
                            return DropdownMenuItem(
                              value: d.id,
                              child: Text(name.isEmpty ? d.id : name),
                            );
                          }).toList(),
                          onChanged: (v) async {
                            setState(() {
                              selectedLeaderId = v;
                            });
                            await loadYouthsForLeader();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: loadYouthsForLeader,
                        child: const Text("Cargar jóvenes"),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: db
                    .collection("events")
                    .where("active", isEqualTo: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const LinearProgressIndicator();
                  final events = snap.data!.docs;
                  if (events.isEmpty) {
                    return const Text("Crea al menos 1 evento.");
                  }
                  selectedEventId ??= events.first.id;

                  return Row(
                    children: [
                      const Text("Evento: "),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedEventId,
                          items: events.map((d) {
                            final data = d.data() as Map<String, dynamic>;
                            final name = (data["name"] ?? "").toString();
                            final type = (data["type"] ?? "").toString();
                            return DropdownMenuItem(
                              value: d.id,
                              child: Text("$name ($type)"),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => selectedEventId = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: pickDate,
                        child: Text("Fecha: $dk"),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: presentMap.isEmpty
              ? const Center(
                  child: Text("Pulsa 'Cargar jóvenes' para marcar asistencia."),
                )
              : FutureBuilder<QuerySnapshot>(
                  future: db
                      .collection("youths")
                      .where("leaderId", isEqualTo: selectedLeaderId)
                      .get(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final youths = snap.data!.docs;

                    return ListView.builder(
                      itemCount: youths.length,
                      itemBuilder: (context, i) {
                        final d = youths[i];
                        final data = d.data() as Map<String, dynamic>;
                        final name = (data["fullName"] ?? "").toString();

                        final present = presentMap[d.id] ?? false;

                        return CheckboxListTile(
                          title: Text(name.isEmpty ? d.id : name),
                          value: present,
                          onChanged: (v) {
                            setState(() {
                              presentMap[d.id] = v ?? false;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("Guardar asistencia"),
              onPressed: saveAttendance,
            ),
          ),
        ),
      ],
    );
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final FirebaseFirestore db;
  String? selectedLeaderId;

  @override
  void initState() {
    super.initState();
    db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: "mora2",
    );
  }

  Future<void> exportLeaderExcel(String leaderId) async {
    try {
      final leaderDoc = await db.collection("leaders").doc(leaderId).get();
      final leaderName = (leaderDoc.data()?["name"] ?? leaderId).toString();

      final youthsSnap = await db
          .collection("youths")
          .where("leaderId", isEqualTo: leaderId)
          .get();

      final sessionsSnap = await db
          .collection("attendance_sessions")
          .where("leaderId", isEqualTo: leaderId)
          .get();

      final sessionIds = sessionsSnap.docs.map((d) => d.id).toList();

      final excel = Excel.createExcel();
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final sheetYouth = excel["Jovenes"];
      sheetYouth.appendRow([
        TextCellValue("Nombre"),
        TextCellValue("Teléfono"),
        TextCellValue("Nivel espiritual"),
        TextCellValue("Asistencias"),
        TextCellValue("Total sesiones"),
        TextCellValue("%"),
      ]);

      for (final y in youthsSnap.docs) {
        final data = y.data();
        final fullName = (data["fullName"] ?? "").toString();
        final phone = (data["phone"] ?? "").toString();
        final level = (data["spiritualLevel"] ?? "").toString();

        int present = 0;
        int total = 0;

        if (sessionIds.isNotEmpty) {
          for (final sId in sessionIds) {
            final markSnap = await db
                .collection("attendance_marks")
                .where("sessionId", isEqualTo: sId)
                .where("youthId", isEqualTo: y.id)
                .limit(1)
                .get();

            if (markSnap.docs.isNotEmpty) {
              total += 1;
              final mark = markSnap.docs.first.data();
              if (mark["present"] == true) present += 1;
            }
          }
        }

        final percent = total == 0 ? 0 : ((present / total) * 100).round();

        sheetYouth.appendRow([
          TextCellValue(fullName),
          TextCellValue(phone),
          TextCellValue(level),
          IntCellValue(present),
          IntCellValue(total),
          IntCellValue(percent),
        ]);
      }

      final sheetSessions = excel["Sesiones"];
      sheetSessions.appendRow([
        TextCellValue("Evento"),
        TextCellValue("Fecha"),
        TextCellValue("Presentes"),
        TextCellValue("Total"),
      ]);

      for (final s in sessionsSnap.docs) {
        final data = s.data();
        final eventName = (data["eventName"] ?? "").toString();
        final dateKey = (data["dateKey"] ?? "").toString();

        final totalMarks = await db
            .collection("attendance_marks")
            .where("sessionId", isEqualTo: s.id)
            .get();

        final presentMarks = await db
            .collection("attendance_marks")
            .where("sessionId", isEqualTo: s.id)
            .where("present", isEqualTo: true)
            .get();

        sheetSessions.appendRow([
          TextCellValue(eventName),
          TextCellValue(dateKey),
          IntCellValue(presentMarks.docs.length),
          IntCellValue(totalMarks.docs.length),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception("No se pudo generar el archivo.");

      final fileName = "reporte_lider_${leaderName.replaceAll(' ', '_')}.xlsx";

      await FileSaver.instance.saveFile(
        name: fileName.replaceAll(".xlsx", ""),
        bytes: Uint8List.fromList(bytes),
        ext: "xlsx",
        mimeType: MimeType.microsoftExcel,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Excel del líder descargado: $fileName")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error exportando líder: $e")));
      }
    }
  }

  Future<void> exportGlobalExcel() async {
    try {
      final leadersSnap = await db.collection("leaders").get();
      final youthsSnap = await db.collection("youths").get();
      final sessionsSnap = await db
          .collection("attendance_sessions")
          .orderBy("createdAt", descending: true)
          .get();

      final leaderNameById = <String, String>{};
      for (final l in leadersSnap.docs) {
        final data = l.data();
        leaderNameById[l.id] = (data["name"] ?? l.id).toString();
      }

      final excel = Excel.createExcel();
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final shSessions = excel["Sesiones"];
      shSessions.appendRow([
        TextCellValue("Fecha"),
        TextCellValue("Evento"),
        TextCellValue("Líder"),
        TextCellValue("Presentes"),
        TextCellValue("Total"),
        TextCellValue("sessionId"),
      ]);

      for (final s in sessionsSnap.docs) {
        final data = s.data();
        final dateKey = (data["dateKey"] ?? "").toString();
        final eventName = (data["eventName"] ?? "").toString();
        final leaderId = (data["leaderId"] ?? "").toString();
        final leaderName = leaderNameById[leaderId] ?? leaderId;

        final totalMarks = await db
            .collection("attendance_marks")
            .where("sessionId", isEqualTo: s.id)
            .get();

        final presentMarks = await db
            .collection("attendance_marks")
            .where("sessionId", isEqualTo: s.id)
            .where("present", isEqualTo: true)
            .get();

        shSessions.appendRow([
          TextCellValue(dateKey),
          TextCellValue(eventName),
          TextCellValue(leaderName),
          IntCellValue(presentMarks.docs.length),
          IntCellValue(totalMarks.docs.length),
          TextCellValue(s.id),
        ]);
      }

      final shYouths = excel["Jovenes"];
      shYouths.appendRow([
        TextCellValue("Líder"),
        TextCellValue("Joven"),
        TextCellValue("Nivel espiritual"),
        TextCellValue("Teléfono"),
        TextCellValue("youthId"),
      ]);

      for (final y in youthsSnap.docs) {
        final data = y.data();
        final leaderId = (data["leaderId"] ?? "").toString();
        final leaderName = leaderNameById[leaderId] ?? leaderId;

        shYouths.appendRow([
          TextCellValue(leaderName),
          TextCellValue((data["fullName"] ?? "").toString()),
          TextCellValue((data["spiritualLevel"] ?? "").toString()),
          TextCellValue((data["phone"] ?? "").toString()),
          TextCellValue(y.id),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception("No se pudo generar el archivo.");

      const fileName = "reporte_general_grupo_juvenil.xlsx";

      await FileSaver.instance.saveFile(
        name: fileName.replaceAll(".xlsx", ""),
        bytes: Uint8List.fromList(bytes),
        ext: "xlsx",
        mimeType: MimeType.microsoftExcel,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "✅ Excel general descargado: reporte_general_grupo_juvenil.xlsx",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error exportando general: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text("Excel del líder"),
                  onPressed: selectedLeaderId == null
                      ? null
                      : () => exportLeaderExcel(selectedLeaderId!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text("Excel general"),
                  onPressed: exportGlobalExcel,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder<QuerySnapshot>(
            stream: db
                .collection("leaders")
                .orderBy("createdAt", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              final leaders = snapshot.data!.docs;

              if (leaders.isEmpty) {
                return const Text(
                  "Primero registra al menos 1 líder en la pestaña Líderes.",
                );
              }

              selectedLeaderId ??= leaders.first.id;

              return Row(
                children: [
                  const Text("Líder: "),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedLeaderId,
                      items: leaders.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final name = (data["name"] ?? "").toString();
                        return DropdownMenuItem(
                          value: d.id,
                          child: Text(name.isEmpty ? d.id : name),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => selectedLeaderId = v),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "1) Sesiones registradas (recientes)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              _RecentSessionsReport(db: db),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "2) Asistencia por joven (según líder)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (selectedLeaderId != null)
                _YouthAttendanceReport(db: db, leaderId: selectedLeaderId!),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentSessionsReport extends StatelessWidget {
  const _RecentSessionsReport({required this.db});

  final FirebaseFirestore db;

  Future<int> _countPresents(String sessionId) async {
    final snap = await db
        .collection("attendance_marks")
        .where("sessionId", isEqualTo: sessionId)
        .where("present", isEqualTo: true)
        .get();
    return snap.docs.length;
  }

  Future<int> _countTotalMarks(String sessionId) async {
    final snap = await db
        .collection("attendance_marks")
        .where("sessionId", isEqualTo: sessionId)
        .get();
    return snap.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection("attendance_sessions")
          .orderBy("createdAt", descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Text("Error: ${snap.error}");
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sessions = snap.data!.docs;
        if (sessions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text("Aún no hay sesiones registradas."),
          );
        }

        return Column(
          children: sessions.map((s) {
            final data = s.data() as Map<String, dynamic>;
            final dateKey = (data["dateKey"] ?? "").toString();
            final eventName = (data["eventName"] ?? "").toString();
            final leaderId = (data["leaderId"] ?? "").toString();

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                title: Text("$eventName — $dateKey"),
                subtitle: Text("leaderId: $leaderId\nsessionId: ${s.id}"),
                trailing: FutureBuilder<List<int>>(
                  future: Future.wait([
                    _countPresents(s.id),
                    _countTotalMarks(s.id),
                  ]),
                  builder: (context, countsSnap) {
                    if (!countsSnap.hasData) {
                      return const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(),
                      );
                    }
                    final presents = countsSnap.data![0];
                    final total = countsSnap.data![1];
                    return Text("$presents/$total");
                  },
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _YouthAttendanceReport extends StatelessWidget {
  const _YouthAttendanceReport({required this.db, required this.leaderId});

  final FirebaseFirestore db;
  final String leaderId;

  Future<List<Map<String, dynamic>>> _buildReport() async {
    final youthsSnap = await db
        .collection("youths")
        .where("leaderId", isEqualTo: leaderId)
        .get();

    final youths = youthsSnap.docs;

    final sessionsSnap = await db
        .collection("attendance_sessions")
        .where("leaderId", isEqualTo: leaderId)
        .get();

    final sessionIds = sessionsSnap.docs.map((d) => d.id).toList();

    if (sessionIds.isEmpty) {
      return youths.map((y) {
        final data = y.data();
        return {
          "youthId": y.id,
          "fullName": (data["fullName"] ?? "").toString(),
          "present": 0,
          "total": 0,
          "percent": 0.0,
        };
      }).toList();
    }

    final List<Map<String, dynamic>> result = [];

    for (final y in youths) {
      final data = y.data();
      final fullName = (data["fullName"] ?? "").toString();

      final idsForWhereIn = sessionIds.length > 10
          ? sessionIds.sublist(0, 10)
          : sessionIds;

      final totalMarksSnap = await db
          .collection("attendance_marks")
          .where("youthId", isEqualTo: y.id)
          .where("sessionId", whereIn: idsForWhereIn)
          .get();

      final presentMarksSnap = await db
          .collection("attendance_marks")
          .where("youthId", isEqualTo: y.id)
          .where("present", isEqualTo: true)
          .where("sessionId", whereIn: idsForWhereIn)
          .get();

      final total = totalMarksSnap.docs.length;
      final present = presentMarksSnap.docs.length;
      final percent = total == 0 ? 0.0 : (present / total) * 100.0;

      result.add({
        "youthId": y.id,
        "fullName": fullName.isEmpty ? y.id : fullName,
        "present": present,
        "total": total,
        "percent": percent,
      });
    }

    result.sort(
      (a, b) => (b["percent"] as double).compareTo(a["percent"] as double),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _buildReport(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Error: ${snap.error}"),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final rows = snap.data!;
        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text("No hay jóvenes para este líder."),
          );
        }

        return Column(
          children: rows.map((r) {
            final name = r["fullName"].toString();
            final present = r["present"] as int;
            final total = r["total"] as int;
            final percent = (r["percent"] as double).toStringAsFixed(0);

            return ListTile(
              title: Text(name),
              subtitle: Text("Asistencias: $present de $total"),
              trailing: Text("$percent%"),
            );
          }).toList(),
        );
      },
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final FirebaseFirestore db;
  DashboardRange selectedRange = DashboardRange.all;

  @override
  void initState() {
    super.initState();
    db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: "mora2",
    );
  }

  DateTime _now() => DateTime.now();

  bool _isInRange(DateTime date) {
    final now = _now();

    switch (selectedRange) {
      case DashboardRange.all:
        return true;
      case DashboardRange.last30Days:
        final limit = now.subtract(const Duration(days: 30));
        return !date.isBefore(limit);
      case DashboardRange.thisMonth:
        return date.year == now.year && date.month == now.month;
      case DashboardRange.thisYear:
        return date.year == now.year;
    }
  }

  DateTime? _parseDateKey(String dateKey) {
    try {
      final parts = dateKey.split("-");
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, int>> getSummaryCounts() async {
    final leaders = await db.collection("leaders").get();
    final youths = await db.collection("youths").get();
    final events = await db.collection("events").get();
    final sessions = await db.collection("attendance_sessions").get();

    int filteredSessions = 0;

    for (final s in sessions.docs) {
      final data = s.data();
      final date = _parseDateKey((data["dateKey"] ?? "").toString());
      if (date != null && _isInRange(date)) {
        filteredSessions++;
      }
    }

    return {
      "leaders": leaders.docs.length,
      "youths": youths.docs.length,
      "events": events.docs.length,
      "sessions": filteredSessions,
    };
  }

  Future<double> getAverageAttendance() async {
    final sessionsSnap = await db.collection("attendance_sessions").get();

    int totalPresent = 0;
    int totalMarks = 0;

    for (final session in sessionsSnap.docs) {
      final data = session.data();
      final date = _parseDateKey((data["dateKey"] ?? "").toString());

      if (date == null || !_isInRange(date)) continue;

      final marksSnap = await db
          .collection("attendance_marks")
          .where("sessionId", isEqualTo: session.id)
          .get();

      totalMarks += marksSnap.docs.length;

      for (final mark in marksSnap.docs) {
        final markData = mark.data();
        if (markData["present"] == true) {
          totalPresent += 1;
        }
      }
    }

    if (totalMarks == 0) return 0;
    return (totalPresent / totalMarks) * 100;
  }

  Future<List<Map<String, dynamic>>> getAttendanceByLeader() async {
    final leadersSnap = await db.collection("leaders").get();
    final sessionsSnap = await db.collection("attendance_sessions").get();

    final Map<String, String> leaderNames = {};
    for (final doc in leadersSnap.docs) {
      final data = doc.data();
      leaderNames[doc.id] = (data["name"] ?? doc.id).toString();
    }

    final Map<String, int> counts = {};

    for (final session in sessionsSnap.docs) {
      final data = session.data();
      final leaderId = (data["leaderId"] ?? "").toString();
      final date = _parseDateKey((data["dateKey"] ?? "").toString());

      if (date == null || !_isInRange(date)) continue;

      final presentSnap = await db
          .collection("attendance_marks")
          .where("sessionId", isEqualTo: session.id)
          .where("present", isEqualTo: true)
          .get();

      counts[leaderId] = (counts[leaderId] ?? 0) + presentSnap.docs.length;
    }

    return counts.entries.map((e) {
      return {
        "label": leaderNames[e.key] ?? e.key,
        "value": e.value.toDouble(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAttendanceByEvent() async {
    final sessionsSnap = await db.collection("attendance_sessions").get();
    final Map<String, int> counts = {};

    for (final session in sessionsSnap.docs) {
      final data = session.data();
      final eventName = (data["eventName"] ?? "Sin nombre").toString();
      final date = _parseDateKey((data["dateKey"] ?? "").toString());

      if (date == null || !_isInRange(date)) continue;

      final presentSnap = await db
          .collection("attendance_marks")
          .where("sessionId", isEqualTo: session.id)
          .where("present", isEqualTo: true)
          .get();

      counts[eventName] = (counts[eventName] ?? 0) + presentSnap.docs.length;
    }

    return counts.entries.map((e) {
      return {"label": e.key, "value": e.value.toDouble()};
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAttendanceByYouth() async {
    final youthsSnap = await db.collection("youths").get();
    final sessionsSnap = await db.collection("attendance_sessions").get();

    final validSessionIds = <String>{};

    for (final session in sessionsSnap.docs) {
      final data = session.data();
      final date = _parseDateKey((data["dateKey"] ?? "").toString());
      if (date != null && _isInRange(date)) {
        validSessionIds.add(session.id);
      }
    }

    final Map<String, int> counts = {};

    for (final youth in youthsSnap.docs) {
      final data = youth.data();
      final fullName = (data["fullName"] ?? youth.id).toString();

      final marksSnap = await db
          .collection("attendance_marks")
          .where("youthId", isEqualTo: youth.id)
          .where("present", isEqualTo: true)
          .get();

      int presentCount = 0;
      for (final mark in marksSnap.docs) {
        final markData = mark.data();
        final sessionId = (markData["sessionId"] ?? "").toString();
        if (validSessionIds.contains(sessionId)) {
          presentCount++;
        }
      }

      counts[fullName] = presentCount;
    }

    final list = counts.entries.map((e) {
      return {"label": e.key, "value": e.value.toDouble()};
    }).toList();

    list.sort((a, b) => (b["value"] as double).compareTo(a["value"] as double));
    return list.take(10).toList();
  }

  Future<List<Map<String, dynamic>>> getAttendanceByMonth() async {
    final sessionsSnap = await db.collection("attendance_sessions").get();
    final Map<String, int> counts = {};

    for (final session in sessionsSnap.docs) {
      final data = session.data();
      final dateKey = (data["dateKey"] ?? "").toString();
      final date = _parseDateKey(dateKey);

      if (date == null || !_isInRange(date)) continue;

      final monthKey = dateKey.substring(0, 7);

      final presentSnap = await db
          .collection("attendance_marks")
          .where("sessionId", isEqualTo: session.id)
          .where("present", isEqualTo: true)
          .get();

      counts[monthKey] = (counts[monthKey] ?? 0) + presentSnap.docs.length;
    }

    final list = counts.entries.map((e) {
      return {"label": e.key, "value": e.value.toDouble()};
    }).toList();

    list.sort((a, b) => a["label"].toString().compareTo(b["label"].toString()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text("Rango: "),
                const SizedBox(width: 12),
                DropdownButton<DashboardRange>(
                  value: selectedRange,
                  items: const [
                    DropdownMenuItem(
                      value: DashboardRange.all,
                      child: Text("Todo"),
                    ),
                    DropdownMenuItem(
                      value: DashboardRange.last30Days,
                      child: Text("Últimos 30 días"),
                    ),
                    DropdownMenuItem(
                      value: DashboardRange.thisMonth,
                      child: Text("Este mes"),
                    ),
                    DropdownMenuItem(
                      value: DashboardRange.thisYear,
                      child: Text("Este año"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      selectedRange = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, int>>(
          future: getSummaryCounts(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snap.data!;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  title: "Líderes",
                  value: "${data["leaders"]}",
                  icon: Icons.people,
                ),
                _MetricCard(
                  title: "Jóvenes",
                  value: "${data["youths"]}",
                  icon: Icons.groups,
                ),
                _MetricCard(
                  title: "Eventos",
                  value: "${data["events"]}",
                  icon: Icons.event,
                ),
                _MetricCard(
                  title: "Sesiones",
                  value: "${data["sessions"]}",
                  icon: Icons.checklist,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<double>(
          future: getAverageAttendance(),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Asistencia promedio general: ${snap.data!.toStringAsFixed(0)}%",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            "Asistencia por líder",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: getAttendanceByLeader(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return SizedBox(
              height: 320,
              child: AttendanceBarChart(data: snap.data!),
            );
          },
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            "Distribución de asistencia por líder",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: getAttendanceByLeader(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return SizedBox(
              height: 320,
              child: AttendancePieChart(data: snap.data!),
            );
          },
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            "Asistencia por evento",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: getAttendanceByEvent(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return SizedBox(
              height: 320,
              child: AttendanceBarChart(data: snap.data!),
            );
          },
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            "Asistencia por mes",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: getAttendanceByMonth(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return SizedBox(
              height: 320,
              child: AttendanceBarChart(data: snap.data!),
            );
          },
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            "Top 10 jóvenes con más asistencias",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: getAttendanceByYouth(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 340,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return SizedBox(
              height: 340,
              child: AttendanceBarChart(data: snap.data!),
            );
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(title, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class AttendanceBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const AttendanceBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text("No hay datos suficientes."));
    }

    final maxValue = data
        .map((e) => e["value"] as double)
        .reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceEvenly,
            maxY: maxValue + 1,
            gridData: FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 70,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= data.length) {
                      return const SizedBox();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Text(
                          data[index]["label"].toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(
              data.length,
              (i) => BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i]["value"] as double,
                    width: 24,
                    borderRadius: BorderRadius.circular(8),
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

class AppSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;

  const AppSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class AppPageSpacer extends StatelessWidget {
  final Widget child;

  const AppPageSpacer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(top: 8), child: child);
  }
}

class AttendancePieChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const AttendancePieChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text("No hay datos suficientes."));
    }

    final total = data.fold<double>(
      0,
      (sum, item) => sum + (item["value"] as double),
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 45,
                  sections: List.generate(data.length, (i) {
                    final value = data[i]["value"] as double;
                    final percent = total == 0 ? 0 : (value / total) * 100;

                    return PieChartSectionData(
                      value: value,
                      title: "${percent.toStringAsFixed(0)}%",
                      radius: 95,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: data.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      "${data[i]["label"]}: ${(data[i]["value"] as double).toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
