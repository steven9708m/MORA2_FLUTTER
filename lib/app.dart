import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

import 'app_theme.dart';
import 'attendance_export.dart';
import 'core/validation.dart';
import 'data/app_services.dart';
import 'ui/async_editor.dart';
import 'ui/paged_query.dart';

part 'core/ui_helpers.dart';
part 'features/auth/auth.dart';
part 'features/navigation/home_shell.dart';
part 'features/dashboard/dashboard.dart';
part 'features/leaders/leaders.dart';
part 'features/records/records.dart';
part 'features/youth/youth.dart';
part 'features/activities/activities.dart';
part 'features/attendance/attendance.dart';
part 'features/settings/settings.dart';
part 'core/editing.dart';

late AppServices appServices;
FirebaseAuth get auth => appServices.auth;
FirebaseFirestore get db => appServices.firestore;

Stream<QuerySnapshot<Map<String, dynamic>>> _activitiesStream() =>
    appServices.watch(
      'activities',
      db.collection('actividades').where('archived', isEqualTo: false),
    );

class JVApp extends StatefulWidget {
  const JVApp({super.key});
  @override
  State<JVApp> createState() => _JVAppState();
}

class _JVAppState extends State<JVApp> {
  late final router = GoRouter(
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/dashboard'),
      GoRoute(
        path: '/actividades/:id',
        builder: (_, state) => AuthGate(
          section: 'actividades',
          activityId: state.pathParameters['id'],
          selectedLeaderId: state.uri.queryParameters['leader'],
          selectedZone: state.uri.queryParameters['zone'],
        ),
      ),
      GoRoute(
        path: '/jovenes/:id',
        builder: (_, state) =>
            AuthGate(section: 'jovenes', jovenId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/:section',
        builder: (_, state) =>
            AuthGate(section: state.pathParameters['section']!),
      ),
    ],
    errorBuilder: (_, __) =>
        const Scaffold(body: Center(child: Text('Página no encontrada.'))),
  );
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'JV Líderes',
    debugShowCheckedModeBanner: false,
    theme: JVTheme.light,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: router,
  );
}
