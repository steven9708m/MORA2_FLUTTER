part of '../../app.dart';

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
  String? selectedOwner;
  Timer? _searchTimer;
  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> query = db
        .collection('jovenes')
        .where('archived', isEqualTo: false);
    final owner = isAdmin(widget.leader.role)
        ? selectedOwner
        : widget.currentUser.uid;
    if (owner != null) query = query.where('leaderId', isEqualTo: owner);
    if (search.isNotEmpty) {
      return query.orderBy('searchName').startAt([search]).endAt([
        '$search\uf8ff',
      ]);
    }
    return query.orderBy('createdAt', descending: true);
  }

  Stream<Map<String, String>> _leaderNamesStream() {
    if (!isAdmin(widget.leader.role)) {
      return Stream.value({widget.currentUser.uid: widget.leader.name});
    }

    return appServices.watch('leaders', db.collection('leaders')).map((snap) {
      return {
        for (final doc in snap.docs)
          doc.id: safeString(doc.data(), 'name', 'Sin nombre'),
      };
    });
  }

  Future<Map<String, String>> _loadLeaderNamesForExport() async {
    if (!isAdmin(widget.leader.role)) {
      return {widget.currentUser.uid: widget.leader.name};
    }

    final snap = await db.collection('leaders').get();
    return {
      for (final doc in snap.docs)
        doc.id: safeString(doc.data(), 'name', 'Sin nombre'),
    };
  }

  bool _exporting = false;
  Future<void> _exportJovenesXlsx({String? leaderId}) async {
    if (_exporting) return;
    _exporting = true;
    try {
      Query<Map<String, dynamic>> query = db
          .collection('jovenes')
          .where('archived', isEqualTo: false);

      if (leaderId != null) {
        query = query.where('leaderId', isEqualTo: leaderId);
      } else if (!isAdmin(widget.leader.role)) {
        query = query.where('leaderId', isEqualTo: widget.currentUser.uid);
      }

      final snap = await query.get();
      final leaderNames = await _loadLeaderNamesForExport();

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
        'Líder',
        'LeaderId',
      ];

      for (int c = 0; c < headers.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
            .value = TextCellValue(
          headers[c],
        );
      }

      for (int i = 0; i < snap.docs.length; i++) {
        final d = snap.docs[i].data();
        final row = i + 1;
        final values = [
          safeString(d, 'nombre'),
          _ageDisplay(d),
          _formatAnyDate(d['fechaNacimiento']),
          safeString(d, 'telefono'),
          _boolToSiNo(d['claseNuevo']),
          _boolToSiNo(d['claseDoctrina']),
          _boolToSiNo(d['claseMaestro']),
          _boolToSiNo(d['claseLiderazgo']),
          _boolToSiNo(d['bautismo']),
          _leaderDisplayName(d, leaderNames),
          safeString(d, 'leaderId'),
        ];

        for (int c = 0; c < values.length; c++) {
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
              .value = TextCellValue(
            values[c],
          );
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
      }
    } finally {
      _exporting = false;
    }
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
                  hintText: 'Nombre que empieza por…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) {
                  _searchTimer?.cancel();
                  _searchTimer = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      setState(() => search = v.toLowerCase().trim());
                    }
                  });
                },
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: kIsWeb ? () => _exportJovenesXlsx() : null,
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
                    currentLeader: widget.leader,
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
            child: StreamBuilder<Map<String, String>>(
              stream: _leaderNamesStream(),
              builder: (context, leaderSnap) {
                if (leaderSnap.hasError) {
                  return _ErrorState(_errorMessage(leaderSnap.error!));
                }
                if (!leaderSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final leaderNames = leaderSnap.data!;

                return Column(
                  children: [
                    if (isAdmin(widget.leader.role))
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedOwner ?? '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Filtrar por líder',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Todos los líderes'),
                            ),
                            ...leaderNames.entries.map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => selectedOwner = value == '' ? null : value,
                          ),
                        ),
                      ),
                    Expanded(
                      child: PagedQuery(
                        query: _query(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return _ErrorState(_errorMessage(snap.error!));
                          }
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          var docs = snap.data!.docs
                              .where((doc) => doc.data()['archived'] != true)
                              .toList();

                          if (docs.isEmpty) {
                            return const Center(child: Text('No hay jóvenes.'));
                          }

                          if (!mobile) {
                            return _JovenesDataTable(
                              docs: docs,
                              leaderNames: leaderNames,
                              isAdminUser: isAdmin(widget.leader.role),
                              onHistory: (id, data) =>
                                  _openHistory(context, id, data),
                              onExportLeader: (leaderId) =>
                                  _exportJovenesXlsx(leaderId: leaderId),
                              onEdit: (id, data) => _showJovenDialog(
                                context,
                                currentUser: widget.currentUser,
                                currentLeader: widget.leader,
                                docId: id,
                                initial: data,
                              ),
                              onDelete: (id) =>
                                  _deleteDoc('jovenes', id, context),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 22),
                            itemBuilder: (context, index) {
                              final d = docs[index];
                              final data = d.data();
                              final leaderName = _leaderDisplayName(
                                data,
                                leaderNames,
                              );

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        'Líder: $leaderName · Edad: ${_ageDisplay(data)} · ${_phoneDisplay(data)}',
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: [
                                          _ActionIcon(
                                            icon: Icons.history,
                                            tooltip: 'Historial',
                                            onTap: () => _openHistory(
                                              context,
                                              d.id,
                                              data,
                                            ),
                                          ),
                                          if (isAdmin(widget.leader.role))
                                            _ActionIcon(
                                              icon:
                                                  Icons.file_download_outlined,
                                              tooltip: 'Exportar por líder',
                                              onTap: () => _exportJovenesXlsx(
                                                leaderId: safeString(
                                                  data,
                                                  'leaderId',
                                                ),
                                              ),
                                            ),
                                          _ActionIcon(
                                            icon: Icons.edit_outlined,
                                            tooltip: 'Editar',
                                            onTap: () => _showJovenDialog(
                                              context,
                                              currentUser: widget.currentUser,
                                              currentLeader: widget.leader,
                                              docId: d.id,
                                              initial: data,
                                            ),
                                          ),
                                          _ActionIcon(
                                            icon: Icons.archive_outlined,
                                            tooltip: 'Archivar',
                                            onTap: () => _deleteDoc(
                                              'jovenes',
                                              d.id,
                                              context,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
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
        ),
      ],
    );
  }

  void _openHistory(
    BuildContext context,
    String jovenId,
    Map<String, dynamic> data,
  ) {
    context.push('/jovenes/$jovenId');
  }
}

class _JovenesDataTable extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final Map<String, String> leaderNames;
  final bool isAdminUser;
  final void Function(String id, Map<String, dynamic> data) onHistory;
  final void Function(String leaderId) onExportLeader;
  final void Function(String id, Map<String, dynamic> data) onEdit;
  final void Function(String id) onDelete;

  const _JovenesDataTable({
    required this.docs,
    required this.leaderNames,
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
              DataColumn(label: Text('Líder')),
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
                  DataCell(
                    _TableText(
                      _leaderDisplayName(data, leaderNames),
                      width: 200,
                    ),
                  ),
                  DataCell(_TableText(_ageDisplay(data), width: 80)),
                  DataCell(_TableText(_phoneDisplay(data), width: 150)),
                  DataCell(_TableText(_formationSummary(data), width: 300)),
                  DataCell(
                    Chip(label: Text(safeBool(data, 'bautismo') ? 'Sí' : 'No')),
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
                          tooltip: 'Archivar',
                          onPressed: () => onDelete(d.id),
                          icon: const Icon(Icons.archive_outlined),
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
  required LeaderProfile currentLeader,
  String? docId,
  Map<String, dynamic>? initial,
}) async {
  final formKey = GlobalKey<FormState>();
  final data = initial ?? {};
  final name = TextEditingController(text: safeString(data, 'nombre'));
  final birth = TextEditingController(
    text: _formatAnyDate(data['fechaNacimiento']),
  );
  final phone = TextEditingController(text: safeString(data, 'telefono'));
  var leaderId = safeString(data, 'leaderId', currentUser.uid);
  var leaderName = safeString(data, 'leaderName', currentLeader.name);
  final formation = {
    for (final key in [
      'claseNuevo',
      'claseDoctrina',
      'claseMaestro',
      'claseLiderazgo',
      'bautismo',
    ])
      key: safeBool(data, key),
  };
  const labels = {
    'claseNuevo': 'Clase de Nuevo',
    'claseDoctrina': 'Clase de Doctrina',
    'claseMaestro': 'Clase de Maestro',
    'claseLiderazgo': 'Clase de Liderazgo',
    'bautismo': 'Bautismo',
  };
  try {
    final leaders = isAdmin(currentLeader.role)
        ? (await db
                  .collection('leaders')
                  .where('status', isEqualTo: 'activo')
                  .get())
              .docs
        : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    if (!context.mounted) return;
    await _showEditor(
      context,
      title: docId == null ? 'Nuevo joven' : 'Editar joven',
      formKey: formKey,
      content: StatefulBuilder(
        builder: (context, update) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Nombre y apellido'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: birth,
              readOnly: true,
              validator: (value) => validateBirthDate(value),
              onTap: () async {
                await _pickDateIntoController(context, birth, birthDate: true);
                if (context.mounted) update(() {});
              },
              decoration: InputDecoration(
                labelText: 'Fecha de nacimiento',
                suffixIcon: const Icon(Icons.calendar_today_outlined),
                helperText: parseDate(birth.text) == null
                    ? null
                    : 'Edad: ${ageOn(parseDate(birth.text)!, DateTime.now())} años',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phone,
              maxLength: 30,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
              ),
              validator: (v) =>
                  (v ?? '').isEmpty ||
                      RegExp(r'^[+0-9 ()-]{5,30}$').hasMatch(v!)
                  ? null
                  : 'Revisa el teléfono.',
            ),
            if (isAdmin(currentLeader.role)) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: leaderId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Líder responsable',
                ),
                items: [
                  if (!leaders.any((d) => d.id == leaderId))
                    DropdownMenuItem(value: leaderId, child: Text(leaderName)),
                  ...leaders.map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        safeString(d.data(), 'name'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (id) {
                  leaderId = id!;
                  leaderName = safeString(
                    leaders.firstWhere((d) => d.id == id).data(),
                    'name',
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            for (final key in formation.keys)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(labels[key]!),
                value: formation[key]!,
                onChanged: (value) => update(() => formation[key] = value),
              ),
          ],
        ),
      ),
      onSave: () async {
        final payload = {
          if (docId == null) 'archived': false,
          'nombre': name.text.trim(),
          'searchName': name.text.trim().toLowerCase(),
          'fechaNacimiento': dateTimestamp(birth.text),
          'edad': ageOn(parseDate(birth.text)!, DateTime.now()),
          'telefono': phone.text.trim(),
          ...formation,
          'leaderId': leaderId,
          'leaderName': leaderName,
          'createdAt': initial?['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await (docId == null
                ? db.collection('jovenes').doc()
                : db.collection('jovenes').doc(docId))
            .set(payload, SetOptions(merge: true));
        return 'Joven guardado.';
      },
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
    }
  } finally {
    name.dispose();
    birth.dispose();
    phone.dispose();
  }
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
            if (jovenSnap.hasError) {
              return _ErrorState(_errorMessage(jovenSnap.error!));
            }
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
                    Text('Edad: ${_ageDisplay(jovenData)}'),
                    Text(
                      'Fecha de nacimiento: ${_formatAnyDate(jovenData["fechaNacimiento"])}',
                    ),
                    Text('Teléfono: ${_phoneDisplay(jovenData)}'),
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
                    if (asSnap.hasError) {
                      return _ErrorState(_errorMessage(asSnap.error!));
                    }
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
                        if (histSnap.hasError) {
                          return _ErrorState(_errorMessage(histSnap.error!));
                        }
                        if (!histSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                                        ? Colors.green.withValues(alpha: .12)
                                        : Colors.red.withValues(alpha: .12),
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
                children: [infoCard, const SizedBox(height: 16), historyCard],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SingleChildScrollView(child: infoCard)),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(child: historyCard),
                ),
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
    backgroundColor: ok
        ? Colors.green.withValues(alpha: .12)
        : Colors.grey.shade200,
  );
}
