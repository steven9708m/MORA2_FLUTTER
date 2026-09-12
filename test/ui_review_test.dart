import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grupo_juvenil_morados/app.dart';
import 'package:grupo_juvenil_morados/app_theme.dart';
import 'package:grupo_juvenil_morados/data/app_services.dart';
import 'package:grupo_juvenil_morados/ui/async_editor.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'admin';
  @override
  String get email => 'admin@example.com';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
  @override
  Stream<User?> authStateChanges() => Stream.value(currentUser);
}

class _Functions extends Fake implements FirebaseFunctions {}

Widget host(Widget child) => MaterialApp(
  theme: JVTheme.light,
  locale: const Locale('es'),
  supportedLocales: const [Locale('es')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);

Future<void> seed() async {
  final db = FakeFirebaseFirestore();
  appServices = AppServices(
    auth: _Auth(),
    firestore: db,
    functions: _Functions(),
  );
  await db.doc('leaders/admin').set({
    'name': 'María López',
    'email': 'admin@example.com',
    'role': 'admin',
    'status': 'activo',
    'zone': 'Zona 1',
  });
  for (var i = 0; i < 30; i++) {
    await db.collection('jovenes').doc('young-$i').set({
      'nombre': 'Joven ${i.toString().padLeft(2, '0')}',
      'searchName': 'joven ${i.toString().padLeft(2, '0')}',
      'edad': 18,
      'telefono': '6000-0000',
      'leaderId': 'admin',
      'leaderName': 'María López',
      'fechaNacimiento': Timestamp.fromDate(DateTime.utc(2008, 1, 1)),
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(i),
      'archived': false,
      'claseNuevo': false,
      'claseDoctrina': false,
      'claseMaestro': false,
      'claseLiderazgo': false,
      'bautismo': false,
    });
  }
  await db.doc('actividades/activity').set({
    'nombre': 'Encuentro juvenil',
    'descripcion': 'Una tarde para compartir y crecer juntos.',
    'fecha': Timestamp.fromDate(DateTime.utc(2026, 9, 5)),
    'estado': 'activa',
    'archived': false,
  });
}

Future<void> screenshot(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('SAVE_REVIEW_SCREENSHOTS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.verification/screens/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    const fontPath = String.fromEnvironment('REVIEW_FONT_PATH');
    if (fontPath.isEmpty) return;
    final font = FontLoader('Roboto')
      ..addFont(
        File(
          fontPath,
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await font.load();
    // Flutter's test binding uses Ahem for component defaults. Substitute the
    // same real font only for optional human-review captures.
    final defaults = FontLoader('Ahem')
      ..addFont(
        File(
          fontPath,
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await defaults.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets(
    'login preserves password spaces and blocks duplicate submissions',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      String? password;
      await tester.pumpWidget(
        host(
          LoginPage(
            signIn: (email, pass) {
              calls++;
              password = pass;
              return pending.future;
            },
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'ana@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), ' password ');
      await tester.ensureVisible(find.text('Entrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrar'));
      await tester.pump();
      expect(calls, 1);
      expect(password, ' password ');
      expect(
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((w) => w is FilledButton),
            )
            .onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
    },
  );
  testWidgets('failed editor retains input and supports a successful retry', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Conservar este texto');
    addTearDown(controller.dispose);
    var attempts = 0;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<String>(
                context: context,
                builder: (_) => AsyncEditor(
                  title: 'Reporte',
                  formKey: GlobalKey<FormState>(),
                  content: TextFormField(controller: controller),
                  errorMessage: (_) => 'Error recuperable',
                  onSave: () async {
                    attempts++;
                    if (attempts == 1) throw StateError('offline');
                    return 'Guardado';
                  },
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Error recuperable'), findsOneWidget);
    expect(controller.text, 'Conservar este texto');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byType(AsyncEditor), findsNothing);
  });
  for (final width in [360.0, 768.0, 1440.0]) {
    testWidgets('dashboard and youth adapt at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await seed();
      await tester.pumpWidget(
        const RepaintBoundary(key: ValueKey('capture'), child: JVApp()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await screenshot(tester, 'dashboard-${width.toInt()}');
      // Exercise real routes without relying on a particular menu layout.
      final context = tester.element(find.byType(HomeShell));
      final shell = GoRouter.of(context);
      shell.go('/jovenes');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await screenshot(tester, 'youth-${width.toInt()}');
      expect(find.textContaining('Página 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Página 2'), findsOneWidget);
      shell.go('/actividades/activity');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('30 pendientes'), findsOneWidget);
      await screenshot(tester, 'attendance-${width.toInt()}');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
