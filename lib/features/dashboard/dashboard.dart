part of '../../app.dart';

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
    Query<Map<String, dynamic>> query = db
        .collection(collection)
        .where('archived', isEqualTo: false);
    if (!isAdmin(leader.role)) {
      query = query.where('leaderId', isEqualTo: currentUser.uid);
    }
    return query;
  }

  Query<Map<String, dynamic>> _leadersMetricQuery() => isAdmin(leader.role)
      ? db.collection('leaders').where('status', isEqualTo: 'activo')
      : db
            .collection('leaders')
            .where(FieldPath.documentId, isEqualTo: currentUser.uid);
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final mobile = width < 900;
    final metrics = [
      _MetricCard(
        width: mobile ? double.infinity : 0,
        title: 'Líderes',
        icon: Icons.manage_accounts,
        query: _leadersMetricQuery(),
      ),
      _MetricCard(
        width: mobile ? double.infinity : 0,
        title: 'Reportes',
        icon: Icons.assessment,
        query: _queryFor('reportes'),
      ),
      _MetricCard(
        width: mobile ? double.infinity : 0,
        title: 'Jóvenes',
        icon: Icons.groups,
        query: _queryFor('jovenes'),
      ),
      _MetricCard(
        width: mobile ? double.infinity : 0,
        title: 'Actividades',
        icon: Icons.event_note,
        query: db.collection('actividades').where('archived', isEqualTo: false),
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
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: metrics
                  .map(
                    (metric) => SizedBox(
                      width:
                          (constraints.maxWidth - (mobile ? 12 : 36)) /
                          (mobile ? 2 : 4),
                      child: metric,
                    ),
                  )
                  .toList(),
            ),
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
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: actions
                        .map(
                          (action) => ActionChip(
                            avatar: Icon(action.icon, size: 18),
                            label: Text(action.title),
                            onPressed: () => onSelectSection(action.section),
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

  const _QuickActionButton({required this.action, required this.onTap});

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

class _MetricCard extends StatefulWidget {
  final double width;
  final String title;
  final IconData icon;
  final Query<Map<String, dynamic>> query;
  const _MetricCard({
    required this.width,
    required this.title,
    required this.icon,
    required this.query,
  });
  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  late Future<AggregateQuerySnapshot> _count;
  @override
  void initState() {
    super.initState();
    _count = widget.query.count().get();
  }

  @override
  void didUpdateWidget(_MetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _count = widget.query.count().get();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: JVTheme.primary),
              const Spacer(),
              IconButton(
                tooltip: 'Actualizar ${widget.title}',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    setState(() => _count = widget.query.count().get()),
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.title,
            style: const TextStyle(
              color: JVTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FutureBuilder<AggregateQuerySnapshot>(
            future: _count,
            builder: (context, snap) {
              if (snap.hasError) return const Text('No disponible');
              if (!snap.hasData) return const LinearProgressIndicator();
              return Text(
                '${snap.data!.count ?? 0}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
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
  String selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _activitiesStream(),
      builder: (context, activitySnap) {
        if (activitySnap.hasError) {
          return const _EmptyData('No se pudieron cargar las actividades.');
        }
        if (activitySnap.hasError) {
          return _ErrorState(_errorMessage(activitySnap.error!));
        }
        if (!activitySnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final activities = activitySnap.data!.docs;
        if (activities.isEmpty) {
          return const _EmptyData('No hay actividades registradas.');
        }

        Query<Map<String, dynamic>> attendanceQuery = db.collection(
          'asistencias',
        );
        if (selectedMonth != 'Todos') {
          attendanceQuery = attendanceQuery
              .where(
                'activityDate',
                isGreaterThanOrEqualTo: '$selectedMonth-01',
              )
              .where('activityDate', isLessThanOrEqualTo: '$selectedMonth-31');
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: appServices.watch('chart:$selectedMonth', attendanceQuery),
          builder: (context, chartSnap) {
            if (chartSnap.hasError) {
              return const _EmptyData('No se pudo cargar la asistencia.');
            }
            if (chartSnap.hasError) {
              return _ErrorState(_errorMessage(chartSnap.error!));
            }
            if (!chartSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = _loadAttendanceByDateData(
              activities: activities,
              attendanceDocs: chartSnap.data!.docs,
            );
            if (data.activityNames.isEmpty) {
              return const _EmptyData('Aún no hay asistencias registradas.');
            }

            if (selectedActivity != 'Todas' &&
                !data.activityNames.contains(selectedActivity)) {
              selectedActivity = 'Todas';
            }

            final groups = data.groupsFor(
              selectedActivity: selectedActivity,
              selectedMonth: selectedMonth,
            );
            final mobile = MediaQuery.of(context).size.width < 700;
            final visibleActivityNames = data.visibleActivityNamesFor(
              selectedActivity: selectedActivity,
              groups: groups,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: mobile ? double.infinity : 300,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedActivity,
                        isExpanded: true,
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
                              child: Text(
                                data.labels[name] ?? name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => selectedActivity = value);
                        },
                      ),
                    ),
                    SizedBox(
                      width: mobile ? double.infinity : 240,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedMonth,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Mes',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'Todos',
                            child: Text('Todos'),
                          ),
                          if (selectedMonth != 'Todos' &&
                              !data.monthOptions.any(
                                (m) => m.key == selectedMonth,
                              ))
                            DropdownMenuItem(
                              value: selectedMonth,
                              child: Text(
                                _formatDashboardMonth(
                                  parseDate('$selectedMonth-01')!,
                                ),
                              ),
                            ),
                          ...data.monthOptions.map(
                            (month) => DropdownMenuItem(
                              value: month.key,
                              child: Text(month.label),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => selectedMonth = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (groups.isEmpty)
                  const _EmptyData(
                    'No hay asistencias para los filtros seleccionados.',
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
                            final preferredWidth =
                                groups.length *
                                (visibleActivityNames.length * 22.0 + 56);
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
                                    activityNames: visibleActivityNames,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AttendanceChartLegend(
                        activityNames: visibleActivityNames,
                        labels: data.labels,
                      ),
                      ExpansionTile(
                        title: const Text('Ver datos del gráfico'),
                        children: [
                          for (final group in groups)
                            ListTile(
                              title: Text(group.label),
                              subtitle: Text(
                                group.countsByActivity.entries
                                    .map(
                                      (entry) =>
                                          '${data.labels[entry.key] ?? entry.key}: ${entry.value}',
                                    )
                                    .join(' · '),
                              ),
                            ),
                        ],
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
  final Map<String, String> labels;
  final List<_AttendanceMonthOption> monthOptions;
  final List<_AttendanceDateGroup> groups;

  const _AttendanceByDateData({
    required this.activityNames,
    this.labels = const {},
    required this.monthOptions,
    required this.groups,
  });

  List<_AttendanceDateGroup> groupsFor({
    required String selectedActivity,
    required String selectedMonth,
  }) {
    final filtered = <_AttendanceDateGroup>[];
    for (final group in groups) {
      if (selectedMonth != 'Todos' &&
          DateFormat('yyyy-MM').format(group.date) != selectedMonth) {
        continue;
      }

      if (selectedActivity == 'Todas') {
        filtered.add(group);
        continue;
      }

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

  List<String> visibleActivityNamesFor({
    required String selectedActivity,
    required List<_AttendanceDateGroup> groups,
  }) {
    if (selectedActivity != 'Todas') return [selectedActivity];
    final names =
        groups
            .expand((group) => group.countsByActivity.keys)
            .where((name) => activityNames.contains(name))
            .toSet()
            .toList()
          ..sort();
    return names;
  }
}

class _AttendanceMonthOption {
  final String key;
  final String label;

  const _AttendanceMonthOption({required this.key, required this.label});
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

_AttendanceByDateData _loadAttendanceByDateData({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> activities,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> attendanceDocs,
}) {
  final activityById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

  for (final activity in activities) {
    final name = safeString(activity.data(), 'nombre', 'Actividad').trim();
    if (name.isEmpty) continue;
    activityById[activity.id] = activity;
  }

  if (activityById.isEmpty) {
    return const _AttendanceByDateData(
      activityNames: [],
      monthOptions: [],
      groups: [],
    );
  }

  final catalogActivityNames = activityById.keys.toList();
  final labels = {
    for (final activity in activityById.values)
      activity.id:
          '${safeString(activity.data(), 'nombre')} · ${_formatAnyDate(activity.data()['fecha'])}',
  };
  final catalogMonths = <String, DateTime>{};

  for (final activity in activityById.values) {
    final date = _extractDate(activity.data()['fecha']);
    if (date == null) continue;
    final normalizedMonth = DateTime(date.year, date.month);
    catalogMonths[DateFormat('yyyy-MM').format(normalizedMonth)] =
        normalizedMonth;
  }

  final monthOptions =
      catalogMonths.entries
          .map(
            (entry) => _AttendanceMonthOption(
              key: entry.key,
              label: _formatDashboardMonth(entry.value),
            ),
          )
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));

  final grouped = <String, _MutableAttendanceDateGroup>{};
  for (final attendance in _uniqueAttendance(attendanceDocs)) {
    final data = attendance.data();
    if (data['attended'] != true) continue;
    final activityId = safeString(data, 'activityId');
    final activity = activityById[activityId];
    if (activity == null) continue;

    final activityData = activity.data();
    final date = _extractDate(activityData['fecha']);
    if (date == null) continue;

    final normalizedDate = DateTime(date.year, date.month, date.day);
    final key = DateFormat('yyyy-MM-dd').format(normalizedDate);
    final name = activityId;

    final bucket = grouped.putIfAbsent(
      key,
      () => _MutableAttendanceDateGroup(
        date: normalizedDate,
        label: DateFormat('dd/MM').format(normalizedDate),
      ),
    );
    bucket.countsByActivity[name] = (bucket.countsByActivity[name] ?? 0) + 1;
  }

  final groups =
      grouped.values
          .map(
            (group) => _AttendanceDateGroup(
              date: group.date,
              label: group.label,
              countsByActivity: Map.unmodifiable(group.countsByActivity),
            ),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  return _AttendanceByDateData(
    activityNames: catalogActivityNames,
    labels: labels,
    monthOptions: monthOptions,
    groups: groups,
  );
}

String _formatDashboardMonth(DateTime date) {
  const months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

class _MutableAttendanceDateGroup {
  final DateTime date;
  final String label;
  final Map<String, int> countsByActivity = {};

  _MutableAttendanceDateGroup({required this.date, required this.label});
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
      ),
    );
  }
}

class _GroupedAttendanceChartPainter extends CustomPainter {
  final List<_AttendanceDateGroup> groups;
  final List<String> activityNames;

  const _GroupedAttendanceChartPainter({
    required this.groups,
    required this.activityNames,
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

    final visibleActivities = activityNames.toList();
    if (visibleActivities.isEmpty) return;

    final maxValue = groups
        .expand(
          (group) => visibleActivities.map(
            (name) => group.countsByActivity[name] ?? 0,
          ),
        )
        .fold<int>(0, (max, value) => value > max ? value : max);
    final effectiveMax = maxValue <= 0 ? 1 : maxValue;
    final step = (effectiveMax / 4).ceil().clamp(1, effectiveMax).toInt();
    final yMax = ((effectiveMax / step).ceil() * step).clamp(1, 999999).toInt();

    for (var value = 0; value <= yMax; value += step) {
      final y = top + chartHeight - (value / yMax) * chartHeight;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
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
          groupStart +
          (groupWidth -
                  (barWidth * visibleActivities.length) -
                  barGap * (visibleActivities.length - 1)) /
              2;

      for (
        var activityIndex = 0;
        activityIndex < visibleActivities.length;
        activityIndex++
      ) {
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
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GroupedAttendanceChartPainter oldDelegate) {
    return oldDelegate.groups != groups ||
        oldDelegate.activityNames != activityNames;
  }
}

class _AttendanceChartLegend extends StatelessWidget {
  final List<String> activityNames;

  final Map<String, String> labels;
  const _AttendanceChartLegend({
    required this.activityNames,
    this.labels = const {},
  });

  static const _palette = _GroupedAttendanceChartPainter._palette;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: activityNames.toList().asMap().entries.map((entry) {
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
              labels[entry.value] ?? entry.value,
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

class _ActivityStatusPanel extends StatelessWidget {
  const _ActivityStatusPanel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _activitiesStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _EmptyData('No se pudieron cargar las actividades.');
        }
        if (snap.hasError) return _ErrorState(_errorMessage(snap.error!));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs
            .where((doc) => doc.data()['archived'] != true)
            .toList();
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
      stream: _activitiesStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _EmptyData('No se pudieron cargar las actividades.');
        }
        if (snap.hasError) return _ErrorState(_errorMessage(snap.error!));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = _sortActivitiesByProximity(
          snap.data!.docs.where((doc) => doc.data()['archived'] != true),
        ).take(5).toList();
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
      stream: _activitiesStream(),
      builder: (context, actSnap) {
        if (actSnap.hasError) {
          return const _EmptyData('No se pudieron cargar las actividades.');
        }
        if (actSnap.hasError) return _ErrorState(_errorMessage(actSnap.error!));
        if (!actSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final acts =
            (actSnap.data!.docs.toList()..sort(
                  (a, b) => _formatAnyDate(
                    b.data()['fecha'],
                  ).compareTo(_formatAnyDate(a.data()['fecha'])),
                ))
                .take(10)
                .toList();
        if (acts.isEmpty) {
          return const _EmptyData('No hay actividades registradas.');
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: appServices.watch(
            'summary:${acts.map((d) => d.id).join(',')}',
            db
                .collection('asistencias')
                .where('activityId', whereIn: acts.map((d) => d.id).toList()),
          ),
          builder: (context, sumSnap) {
            if (sumSnap.hasError) {
              return const _EmptyData('No se pudo cargar la asistencia.');
            }
            if (sumSnap.hasError) {
              return _ErrorState(_errorMessage(sumSnap.error!));
            }
            if (!sumSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = _loadActivityAttendanceSummaries(
              acts,
              sumSnap.data!.docs,
            );
            if (list.isEmpty) {
              return const _EmptyData('Aún no hay asistencias registradas.');
            }

            return Column(
              children: list.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.activityName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: e.total == 0 ? 0 : e.attended / e.total,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      const SizedBox(height: 6),
                      Text('${e.attended}/${e.total} registros'),
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

List<_ActivityAttendanceSummary> _loadActivityAttendanceSummaries(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> acts,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> attendanceDocs,
) {
  final totalsByActivity = <String, int>{};
  final attendedByActivity = <String, int>{};

  for (final doc in _uniqueAttendance(attendanceDocs)) {
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
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .18)),
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
      side: BorderSide(color: color.withValues(alpha: .18)),
      backgroundColor: color.withValues(alpha: .08),
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
          colors: [const Color(0xFFFFFFFF), color.withValues(alpha: .06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: .16)),
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
              color: color.withValues(alpha: .12),
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
                  style: const TextStyle(color: Colors.black87, height: 1.45),
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
        color: tone.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: .16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: tone, fontWeight: FontWeight.w700),
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

  const _Panel({required this.title, required this.child, this.eyebrow});

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
