part of '../../app.dart';

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
  String selectedPeriod = 'todas';
  Future<QuerySnapshot<Map<String, dynamic>>>? _leadersFuture;

  @override
  void initState() {
    super.initState();
    if (isAdmin(widget.leader.role)) {
      _leadersFuture = db.collection('leaders').get();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 900;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _activitiesStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Text('No se pudieron cargar las actividades.'),
          );
        }
        if (snap.hasError) return _ErrorState(_errorMessage(snap.error!));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = _sortActivitiesByProximity(
          snap.data!.docs.where((doc) => doc.data()['archived'] != true),
        );
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final upcomingDocs = docs.where((doc) {
          final date = _extractDate(doc.data()['fecha']);
          if (date == null) return false;
          final normalized = DateTime(date.year, date.month, date.day);
          return !normalized.isBefore(today);
        }).toList();
        final pastDocs = docs.where((doc) {
          final date = _extractDate(doc.data()['fecha']);
          if (date == null) return false;
          final normalized = DateTime(date.year, date.month, date.day);
          return normalized.isBefore(today);
        }).toList();
        final filteredDocs = docs.where((doc) {
          final data = doc.data();
          final matchesSearch =
              search.isEmpty ||
              safeString(data, 'nombre').toLowerCase().contains(search) ||
              safeString(data, 'descripcion').toLowerCase().contains(search);
          final status = safeString(data, 'estado', 'programada');
          final matchesStatus =
              selectedStatus == 'todos' || status == selectedStatus;
          final date = _extractDate(data['fecha']);
          final normalized = date == null
              ? null
              : DateTime(date.year, date.month, date.day);
          final matchesPeriod =
              selectedPeriod == 'todas' ||
              (selectedPeriod == 'proximas' &&
                  normalized != null &&
                  !normalized.isBefore(today)) ||
              (selectedPeriod == 'pasadas' &&
                  normalized != null &&
                  normalized.isBefore(today));
          return matchesSearch && matchesStatus && matchesPeriod;
        }).toList();
        final nextActivity = upcomingDocs.isEmpty ? null : upcomingDocs.first;

        final total = docs.length;
        final activas = docs
            .where((e) => safeString(e.data(), 'estado') == 'activa')
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
                      'Actividades y asistencia',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Consulta próximas actividades o recupera cualquier fecha pasada por año y mes.',
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
                          label: 'Próximas',
                          value: '${upcomingDocs.length}',
                          color: const Color(0xFF2563EB),
                        ),
                        _MiniStatCard(
                          label: 'Pasadas',
                          value: '${pastDocs.length}',
                          color: const Color(0xFFB45309),
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
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Estado'),
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
                OutlinedButton.icon(
                  onPressed: docs.isEmpty
                      ? null
                      : () => showAttendanceExportDialog(
                          context: context,
                          firestore: db,
                          activities: docs
                              .map(
                                (doc) => AttendanceExportActivity(
                                  id: doc.id,
                                  data: doc.data(),
                                ),
                              )
                              .toList(),
                          user: AttendanceExportUser(
                            uid: widget.currentUser.uid,
                            name: widget.leader.name,
                            role: widget.leader.role,
                            zone: widget.leader.zone,
                          ),
                        ),
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('Exportar asistencia'),
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
                  ChoiceChip(
                    selected: selectedPeriod == 'todas',
                    avatar: const Icon(
                      Icons.calendar_view_month_outlined,
                      size: 18,
                    ),
                    label: Text('Todas · $total'),
                    onSelected: (_) => setState(() => selectedPeriod = 'todas'),
                  ),
                  ChoiceChip(
                    selected: selectedPeriod == 'proximas',
                    avatar: const Icon(Icons.upcoming_outlined, size: 18),
                    label: Text('Próximas · ${upcomingDocs.length}'),
                    onSelected: (_) =>
                        setState(() => selectedPeriod = 'proximas'),
                  ),
                  ChoiceChip(
                    selected: selectedPeriod == 'pasadas',
                    avatar: const Icon(Icons.history, size: 18),
                    label: Text('Pasadas · ${pastDocs.length}'),
                    onSelected: (_) =>
                        setState(() => selectedPeriod = 'pasadas'),
                  ),
                ],
              ),
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
                  Chip(
                    avatar: const Icon(Icons.sort_outlined, size: 18),
                    label: Text(
                      selectedPeriod == 'proximas'
                          ? 'Más cercana a más lejana'
                          : 'Más reciente a más antigua',
                    ),
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
                future: _leadersFuture,
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
                                  initialValue: selectedLeaderId,
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
                                  initialValue: selectedZone,
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
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 4),
                      leading: CircleAvatar(
                        backgroundColor: Color(0xFFEDEBFF),
                        child: Icon(
                          Icons.calendar_month_outlined,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      title: Text(
                        'Calendario de actividades',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        'Abre un año, luego un mes y selecciona la actividad para registrar asistencia.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (filteredDocs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text(
                            docs.isEmpty
                                ? 'No hay actividades registradas.'
                                : 'No hay actividades para los filtros seleccionados.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      _buildActivityArchive(
                        context,
                        filteredDocs,
                        nextActivity?.id,
                        mobile,
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityArchive(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activities,
    String? nextActivityId,
    bool mobile,
  ) {
    final nearestFirst = selectedPeriod == 'proximas';
    final sorted = activities.toList()
      ..sort((a, b) {
        final aDate = _extractDate(a.data()['fecha']);
        final bDate = _extractDate(b.data()['fecha']);
        if (aDate == null && bDate == null) {
          return safeString(
            a.data(),
            'nombre',
          ).compareTo(safeString(b.data(), 'nombre'));
        }
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        final dateComparison = nearestFirst
            ? aDate.compareTo(bDate)
            : bDate.compareTo(aDate);
        if (dateComparison != 0) return dateComparison;
        return safeString(
          a.data(),
          'nombre',
        ).compareTo(safeString(b.data(), 'nombre'));
      });

    final grouped =
        <int, Map<int, List<QueryDocumentSnapshot<Map<String, dynamic>>>>>{};
    for (final activity in sorted) {
      final date = _extractDate(activity.data()['fecha']);
      final year = date?.year ?? 0;
      final month = date?.month ?? 0;
      grouped
          .putIfAbsent(year, () => {})
          .putIfAbsent(month, () => [])
          .add(activity);
    }

    final years = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 0) return 1;
        if (b == 0) return -1;
        return nearestFirst ? a.compareTo(b) : b.compareTo(a);
      });
    final now = DateTime.now();

    return Column(
      children: [
        for (final year in years)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: ExpansionTile(
              key: PageStorageKey('activity-year-$selectedPeriod-$year'),
              initiallyExpanded: year == now.year || year == years.first,
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const Icon(
                Icons.folder_outlined,
                color: Color(0xFF4F46E5),
              ),
              title: Text(
                year == 0 ? 'Sin fecha válida' : '$year',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(
                '${grouped[year]!.values.fold<int>(0, (total, items) => total + items.length)} actividades',
              ),
              children: _buildMonthGroups(
                context,
                year,
                grouped[year]!,
                nextActivityId,
                mobile,
                now,
                nearestFirst,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildMonthGroups(
    BuildContext context,
    int year,
    Map<int, List<QueryDocumentSnapshot<Map<String, dynamic>>>> months,
    String? nextActivityId,
    bool mobile,
    DateTime now,
    bool nearestFirst,
  ) {
    final monthKeys = months.keys.toList()
      ..sort((a, b) {
        if (a == 0) return 1;
        if (b == 0) return -1;
        return nearestFirst ? a.compareTo(b) : b.compareTo(a);
      });

    return [
      for (final month in monthKeys)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EAF1)),
            ),
            child: ExpansionTile(
              key: PageStorageKey(
                'activity-month-$selectedPeriod-$year-$month',
              ),
              initiallyExpanded:
                  (year == now.year && month == now.month) ||
                  month == monthKeys.first,
              shape: const Border(),
              collapsedShape: const Border(),
              leading: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEBFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  month == 0 ? '--' : month.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              title: Text(
                month == 0 ? 'Sin mes' : _spanishMonthName(month),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${months[month]!.length} ${months[month]!.length == 1 ? "actividad" : "actividades"}',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                for (var index = 0; index < months[month]!.length; index++) ...[
                  _buildActivityItem(
                    context,
                    months[month]![index],
                    nextActivityId == months[month]![index].id,
                    mobile,
                  ),
                  if (index != months[month]!.length - 1)
                    const Divider(height: 20),
                ],
              ],
            ),
          ),
        ),
    ];
  }

  String _spanishMonthName(int month) {
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
    if (month < 1 || month > months.length) return 'Sin mes';
    return months[month - 1];
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
    final activityDate = _extractDate(data['fecha']);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isPast =
        activityDate != null &&
        DateTime(
          activityDate.year,
          activityDate.month,
          activityDate.day,
        ).isBefore(today);
    final attendanceLabel = isPast
        ? 'Registrar asistencia'
        : 'Abrir asistencia';

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
                    style: const TextStyle(color: Colors.black87, height: 1.4),
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
                    label: Text(attendanceLabel),
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
                      icon: const Icon(Icons.archive_outlined),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEDE6FF),
        child: Icon(Icons.event_note, color: _activityStatusColor(status)),
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
            label: Text(attendanceLabel),
          ),
          if (isAdmin(widget.leader.role))
            IconButton(
              tooltip: 'Editar actividad',
              onPressed: () =>
                  _showActividadDialog(context, docId: d.id, initial: data),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (isAdmin(widget.leader.role))
            IconButton(
              tooltip: 'Archivar actividad',
              onPressed: () => _deleteDoc('actividades', d.id, context),
              icon: const Icon(Icons.archive_outlined),
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
    final query = <String, String>{
      if (selectedLeaderId != null) 'leader': selectedLeaderId!,
      if (selectedZone != null) 'zone': selectedZone!,
    };
    context.push(
      Uri(
        path: '/actividades/$activityId',
        queryParameters: query.isEmpty ? null : query,
      ).toString(),
    );
  }
}

Future<void> _showActividadDialog(
  BuildContext context, {
  String? docId,
  Map<String, dynamic>? initial,
}) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: safeString(initial ?? {}, 'nombre'));
  final date = TextEditingController(
    text: _formatAnyDate(initial?['fecha'] ?? Timestamp.now()),
  );
  final description = TextEditingController(
    text: safeString(initial ?? {}, 'descripcion'),
  );
  var status = safeString(initial ?? {}, 'estado', 'programada');
  try {
    await _showEditor(
      context,
      title: docId == null ? 'Nueva actividad' : 'Editar actividad',
      formKey: formKey,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: name,
            maxLength: 150,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: date,
            readOnly: true,
            onTap: () => _pickDateIntoController(context, date),
            decoration: const InputDecoration(
              labelText: 'Fecha',
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            validator: (v) =>
                parseDate(v) == null ? 'Selecciona una fecha válida.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: description,
            maxLines: 3,
            maxLength: 3000,
            decoration: const InputDecoration(labelText: 'Descripción'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: ['programada', 'activa', 'cerrada']
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(_activityStatusLabel(v)),
                  ),
                )
                .toList(),
            onChanged: (v) => status = v!,
          ),
        ],
      ),
      onSave: () async {
        await (docId == null
                ? db.collection('actividades').doc()
                : db.collection('actividades').doc(docId))
            .set({
              if (docId == null) 'archived': false,
              'nombre': name.text.trim(),
              'fecha': dateTimestamp(date.text),
              'descripcion': description.text.trim(),
              'estado': status,
              'createdAt':
                  initial?['createdAt'] ?? FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        return 'Actividad guardada.';
      },
    );
  } finally {
    name.dispose();
    date.dispose();
    description.dispose();
  }
}
