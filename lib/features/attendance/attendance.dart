part of '../../app.dart';

class AsistenciaPage extends StatefulWidget {
  final String activityId;
  final Map<String, dynamic> activityData;
  final User currentUser;
  final LeaderProfile leader;
  final String? selectedLeaderId, selectedZone;
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
  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _people;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _attendance;
  final Set<String> _saving = {};
  final Map<String, String> _errors = {};
  String search = '';
  bool bulkSaving = false;
  bool get readOnly =>
      widget.activityData['archived'] == true ||
      widget.activityData['estado'] == 'cerrada';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _people = _loadPeople();
    _attendance = appServices.attendance
        .query(
          widget.activityId,
          leaderId: isAdmin(widget.leader.role) ? null : widget.currentUser.uid,
        )
        .snapshots();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _loadPeople() async {
    Query<Map<String, dynamic>> query = db
        .collection('jovenes')
        .where('archived', isEqualTo: false);
    final leaderId = isAdmin(widget.leader.role)
        ? widget.selectedLeaderId
        : widget.currentUser.uid;
    if (leaderId != null) query = query.where('leaderId', isEqualTo: leaderId);
    var docs = (await query.get()).docs
        .where((doc) => doc.data()['archived'] != true)
        .toList();
    if (isAdmin(widget.leader.role) && widget.selectedZone != null) {
      final leaders = await db
          .collection('leaders')
          .where('zone', whereIn: _leaderZoneQueryValues(widget.selectedZone!))
          .get();
      final ids = leaders.docs.map((doc) => doc.id).toSet();
      docs = docs.where((doc) => ids.contains(doc.data()['leaderId'])).toList();
    }
    docs.sort(
      (a, b) => safeString(
        a.data(),
        'nombre',
      ).toLowerCase().compareTo(safeString(b.data(), 'nombre').toLowerCase()),
    );
    return docs;
  }

  Future<bool> _save(
    QueryDocumentSnapshot<Map<String, dynamic>> joven,
    bool value,
    int version,
  ) async {
    if (_saving.contains(joven.id) || readOnly) return false;
    setState(() {
      _saving.add(joven.id);
      _errors.remove(joven.id);
    });
    try {
      final data = joven.data();
      final owner = safeString(data, 'leaderId');
      await appServices.attendance.save({
        'activityId': widget.activityId,
        'activityName': safeString(widget.activityData, 'nombre'),
        'activityDate': _formatAnyDate(widget.activityData['fecha']),
        'jovenId': joven.id,
        'jovenNombre': safeString(data, 'nombre'),
        'leaderId': owner,
        'leaderName': owner == widget.currentUser.uid
            ? widget.leader.name
            : safeString(data, 'leaderName'),
        'leaderZone': owner == widget.currentUser.uid ? widget.leader.zone : '',
        'attended': value,
        'updatedBy': widget.currentUser.uid,
      }, expectedVersion: version);
      return true;
    } catch (error) {
      if (mounted) setState(() => _errors[joven.id] = _errorMessage(error));
      return false;
    } finally {
      if (mounted) setState(() => _saving.remove(joven.id));
    }
  }

  Future<void> _saveVisible(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    bool value,
    Map<String, int> versions,
  ) async {
    if (bulkSaving || _saving.isNotEmpty || docs.isEmpty || readOnly) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Marcar ${docs.length} jóvenes'),
        content: Text(
          value
              ? 'Los jóvenes visibles quedarán presentes.'
              : 'Los jóvenes visibles quedarán ausentes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => bulkSaving = true);
    var saved = 0;
    try {
      for (final chunk in _chunkList(docs, 5)) {
        if (!mounted) break;
        final results = await Future.wait(
          chunk.map((doc) => _save(doc, value, versions[doc.id] ?? 0)),
        );
        saved += results.where((ok) => ok).length;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$saved de ${docs.length} guardados.${saved < docs.length ? ' Revisa los errores y reintenta los pendientes.' : ''}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => bulkSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Volver a actividades',
        icon: const Icon(Icons.arrow_back),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/actividades'),
      ),
      title: Text(
        '${safeString(widget.activityData, 'nombre', 'Actividad')} · ${_formatAnyDate(widget.activityData['fecha'])}',
      ),
    ),
    body: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _people,
      builder: (context, people) {
        if (people.hasError) {
          return _ErrorState(
            _errorMessage(people.error!),
            onRetry: () => setState(_load),
          );
        }
        if (!people.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _attendance,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorState(
                _errorMessage(snapshot.error!),
                onRetry: () => setState(_load),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final records = AttendanceRepository.latest(snapshot.data!.docs);
            final versions = <String, int>{
              for (final doc in snapshot.data!.docs)
                if (doc.id ==
                    '${doc.data()['activityId']}:${doc.data()['jovenId']}')
                  safeString(doc.data(), 'jovenId'):
                      (doc.data()['version'] as num?)?.toInt() ?? 0,
            };
            final all = people.data!;
            final visible = all
                .where(
                  (doc) =>
                      search.isEmpty ||
                      safeString(
                        doc.data(),
                        'nombre',
                      ).toLowerCase().contains(search) ||
                      safeString(doc.data(), 'telefono').contains(search),
                )
                .toList();
            final present = all
                .where((doc) => records[doc.id]?.attended == true)
                .length;
            final absent = all
                .where((doc) => records[doc.id]?.attended == false)
                .length;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (readOnly)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Consulta del historial. Para corregir una actividad cerrada, un administrador debe reabrirla.',
                                ),
                              ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(label: Text('$present presentes')),
                                Chip(label: Text('$absent ausentes')),
                                Chip(
                                  label: Text(
                                    '${all.length - present - absent} pendientes',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Buscar joven o teléfono',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (value) => setState(
                                () => search = value.toLowerCase().trim(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (!readOnly)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: bulkSaving || _saving.isNotEmpty
                                        ? null
                                        : () => _saveVisible(
                                            visible,
                                            true,
                                            versions,
                                          ),
                                    icon: const Icon(Icons.done_all),
                                    label: const Text('Presentes visibles'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: bulkSaving || _saving.isNotEmpty
                                        ? null
                                        : () => _saveVisible(
                                            visible,
                                            false,
                                            versions,
                                          ),
                                    icon: const Icon(Icons.person_off_outlined),
                                    label: const Text('Ausentes visibles'),
                                  ),
                                ],
                              ),
                            if (bulkSaving)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: LinearProgressIndicator(),
                              ),
                            const SizedBox(height: 8),
                            const Text(
                              'Pendiente significa que todavía no se ha registrado una respuesta.',
                              style: TextStyle(color: JVTheme.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (visible.isEmpty)
                  const SliverToBoxAdapter(
                    child: _EmptyData('No hay jóvenes para estos filtros.'),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final joven = visible[index];
                      final record = records[joven.id];
                      final saving = _saving.contains(joven.id);
                      final status = record == null
                          ? 'Pendiente'
                          : record.attended
                          ? 'Presente'
                          : 'Ausente';
                      return Card(
                        key: ValueKey(joven.id),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                safeString(joven.data(), 'nombre'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Semantics(
                                liveRegion: true,
                                child: Text(saving ? 'Guardando…' : status),
                              ),
                              if (saving) const LinearProgressIndicator(),
                              if (_errors[joven.id] != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    _errors[joven.id]!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                              if (!readOnly)
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton.icon(
                                      onPressed: saving || bulkSaving
                                          ? null
                                          : () => _save(
                                              joven,
                                              true,
                                              versions[joven.id] ?? 0,
                                            ),
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                      ),
                                      label: const Text('Presente'),
                                    ),
                                    TextButton.icon(
                                      onPressed: saving || bulkSaving
                                          ? null
                                          : () => _save(
                                              joven,
                                              false,
                                              versions[joven.id] ?? 0,
                                            ),
                                      icon: const Icon(Icons.cancel_outlined),
                                      label: const Text('Ausente'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}
