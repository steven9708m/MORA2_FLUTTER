import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:excel/excel.dart' as xlsx show Border, BorderStyle;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

class AttendanceExportActivity {
  final String id;
  final Map<String, dynamic> data;

  const AttendanceExportActivity({required this.id, required this.data});
}

class AttendanceExportUser {
  final String uid;
  final String name;
  final String role;
  final String zone;

  const AttendanceExportUser({
    required this.uid,
    required this.name,
    required this.role,
    required this.zone,
  });

  bool get isAdmin => role == 'admin';
}

Future<void> showAttendanceExportDialog({
  required BuildContext context,
  required FirebaseFirestore firestore,
  required List<AttendanceExportActivity> activities,
  required AttendanceExportUser user,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AttendanceExportDialog(
      firestore: firestore,
      activities: activities,
      user: user,
    ),
  );
}

enum _ExportScope { specificActivity, repeatedActivity, month, year }

class _LeaderOption {
  final String id;
  final String name;
  final String zone;

  const _LeaderOption({
    required this.id,
    required this.name,
    required this.zone,
  });
}

class _AttendanceExportDialog extends StatefulWidget {
  final FirebaseFirestore firestore;
  final List<AttendanceExportActivity> activities;
  final AttendanceExportUser user;

  const _AttendanceExportDialog({
    required this.firestore,
    required this.activities,
    required this.user,
  });

  @override
  State<_AttendanceExportDialog> createState() =>
      _AttendanceExportDialogState();
}

class _AttendanceExportDialogState extends State<_AttendanceExportDialog> {
  static const _monthNames = [
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

  late final List<AttendanceExportActivity> _datedActivities;
  late final List<int> _years;
  late final List<String> _activityNames;
  late final Future<List<_LeaderOption>> _leadersFuture;
  _ExportScope _scope = _ExportScope.specificActivity;
  String? _activityId;
  String? _activityName;
  String? _yearActivityName;
  late int _month;
  late int _year;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  String _attendanceStatus = 'presentes';
  String _activityStatus = 'todos';
  String? _leaderId;
  String? _zone;
  bool _includeContactData = false;
  bool _includeIdentifiers = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _datedActivities = widget.activities
        .where((activity) => _exportDate(activity.data['fecha']) != null)
        .toList()
      ..sort((a, b) => _exportDate(b.data['fecha'])!
          .compareTo(_exportDate(a.data['fecha'])!));
    final now = DateTime.now();
    final availableYears = _datedActivities
        .map((activity) => _exportDate(activity.data['fecha'])!.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    _years = availableYears.isEmpty ? [now.year] : availableYears;
    _year = _years.contains(now.year) ? now.year : _years.first;
    _month = now.month;
    _activityId = _datedActivities.isEmpty ? null : _datedActivities.first.id;
    _activityNames = _datedActivities
        .map((activity) => _text(activity.data, 'nombre', 'Actividad').trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _activityName = _activityNames.isEmpty ? null : _activityNames.first;
    _rangeStart = DateTime(now.year, now.month, 1);
    _rangeEnd = DateTime(now.year, now.month + 1, 0);
    if (_activityName != null) {
      final matchingDates = _datedActivities
          .where(
            (activity) =>
                _normalizeName(_text(activity.data, 'nombre')) ==
                _normalizeName(_activityName!),
          )
          .map((activity) => _exportDate(activity.data['fecha'])!)
          .toList()
        ..sort();
      if (matchingDates.isNotEmpty) {
        _rangeStart = matchingDates.first;
        _rangeEnd = matchingDates.last;
      }
    }
    _leadersFuture = _loadLeaders();
  }

  Future<List<_LeaderOption>> _loadLeaders() async {
    if (!widget.user.isAdmin) {
      return [
        _LeaderOption(
          id: widget.user.uid,
          name: widget.user.name,
          zone: _normalizeZone(widget.user.zone),
        ),
      ];
    }

    final snapshot = await widget.firestore.collection('leaders').get();
    final leaders = snapshot.docs
        .map(
          (doc) => _LeaderOption(
            id: doc.id,
            name: _text(doc.data(), 'name', 'Sin nombre'),
            zone: _normalizeZone(_text(doc.data(), 'zone')),
          ),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return leaders;
  }

  String get _scopeTitle {
    switch (_scope) {
      case _ExportScope.specificActivity:
        return 'Actividad puntual';
      case _ExportScope.repeatedActivity:
        return 'Mismas actividades';
      case _ExportScope.month:
        return 'Por mes';
      case _ExportScope.year:
        return 'Por año';
    }
  }

  String get _scopeDescription {
    switch (_scope) {
      case _ExportScope.specificActivity:
        return 'Una actividad exacta, identificada por nombre y fecha.';
      case _ExportScope.repeatedActivity:
        return 'Todas las actividades con el mismo nombre dentro de un rango.';
      case _ExportScope.month:
        return 'Todas las actividades del mes y año seleccionados.';
      case _ExportScope.year:
        return 'Todo el año o solamente un tipo de actividad de ese año.';
    }
  }

  List<AttendanceExportActivity> _selectedActivities() {
    Iterable<AttendanceExportActivity> selected = _datedActivities;

    switch (_scope) {
      case _ExportScope.specificActivity:
        selected = selected.where((activity) => activity.id == _activityId);
      case _ExportScope.repeatedActivity:
        final normalizedName = _normalizeName(_activityName ?? '');
        final start = DateTime(
          _rangeStart.year,
          _rangeStart.month,
          _rangeStart.day,
        );
        final endExclusive = DateTime(
          _rangeEnd.year,
          _rangeEnd.month,
          _rangeEnd.day + 1,
        );
        selected = selected.where((activity) {
          final date = _exportDate(activity.data['fecha'])!;
          return _normalizeName(_text(activity.data, 'nombre')) ==
                  normalizedName &&
              !date.isBefore(start) &&
              date.isBefore(endExclusive);
        });
      case _ExportScope.month:
        selected = selected.where((activity) {
          final date = _exportDate(activity.data['fecha'])!;
          return date.year == _year && date.month == _month;
        });
      case _ExportScope.year:
        selected = selected.where((activity) {
          final date = _exportDate(activity.data['fecha'])!;
          final matchesName = _yearActivityName == null ||
              _normalizeName(_text(activity.data, 'nombre')) ==
                  _normalizeName(_yearActivityName!);
          return date.year == _year && matchesName;
        });
    }

    if (_activityStatus != 'todos') {
      selected = selected.where(
        (activity) =>
            _text(activity.data, 'estado', 'programada') == _activityStatus,
      );
    }

    return selected.toList()
      ..sort((a, b) => _exportDate(a.data['fecha'])!
          .compareTo(_exportDate(b.data['fecha'])!));
  }

  Future<void> _pickRangeDate({required bool start}) async {
    final initial = start ? _rangeStart : _rangeEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _rangeStart = picked;
        if (_rangeEnd.isBefore(picked)) _rangeEnd = picked;
      } else {
        _rangeEnd = picked;
        if (_rangeStart.isAfter(picked)) _rangeStart = picked;
      }
    });
  }

  void _useFullRangeForActivity(String? name) {
    if (name == null) return;
    final matches = _datedActivities.where(
      (activity) =>
          _normalizeName(_text(activity.data, 'nombre')) ==
          _normalizeName(name),
    );
    if (matches.isEmpty) return;
    final dates = matches
        .map((activity) => _exportDate(activity.data['fecha'])!)
        .toList()
      ..sort();
    setState(() {
      _rangeStart = dates.first;
      _rangeEnd = dates.last;
    });
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _selectedActivities();

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 16),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEDEBFF),
                    child: Icon(
                      Icons.table_view_outlined,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Descargar asistencia en Excel',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'El archivo incluye resumen ejecutivo y detalle analítico.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed:
                        _exporting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<_ExportScope>(
                      key: ValueKey('export-scope-${_scope.name}'),
                      initialValue: _scope,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de descarga',
                        prefixIcon: Icon(Icons.filter_alt_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _ExportScope.specificActivity,
                          child: Text('Por actividad puntual'),
                        ),
                        DropdownMenuItem(
                          value: _ExportScope.repeatedActivity,
                          child: Text('Por mismas actividades'),
                        ),
                        DropdownMenuItem(
                          value: _ExportScope.month,
                          child: Text('Por mes'),
                        ),
                        DropdownMenuItem(
                          value: _ExportScope.year,
                          child: Text('Por año'),
                        ),
                      ],
                      onChanged: _exporting
                          ? null
                          : (value) => setState(
                                () => _scope =
                                    value ?? _ExportScope.specificActivity,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _scopeDescription,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 18),
                    _buildScopeFields(),
                    const SizedBox(height: 18),
                    FutureBuilder<List<_LeaderOption>>(
                      future: _leadersFuture,
                      builder: (context, snapshot) =>
                          _buildAnalysisFilters(snapshot.data ?? const []),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: candidates.isEmpty
                            ? const Color(0xFFFFF7ED)
                            : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: candidates.isEmpty
                              ? const Color(0xFFFDBA74)
                              : const Color(0xFFC7D2FE),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            candidates.isEmpty
                                ? Icons.info_outline
                                : Icons.analytics_outlined,
                            color: candidates.isEmpty
                                ? const Color(0xFFC2410C)
                                : const Color(0xFF4338CA),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              candidates.isEmpty
                                  ? 'No hay actividades que coincidan con estos filtros.'
                                  : '${candidates.length} ${candidates.length == 1 ? "actividad incluida" : "actividades incluidas"} antes de filtrar la asistencia.',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _exporting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _exporting || candidates.isEmpty
                        ? null
                        : () => _export(candidates),
                    icon: _exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download),
                    label:
                        Text(_exporting ? 'Generando...' : 'Descargar Excel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeFields() {
    switch (_scope) {
      case _ExportScope.specificActivity:
        return DropdownButtonFormField<String>(
          key: ValueKey('specific-activity-$_activityId'),
          initialValue: _activityId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Actividad y fecha',
            prefixIcon: Icon(Icons.event_available_outlined),
          ),
          items: _datedActivities
              .map(
                (activity) => DropdownMenuItem(
                  value: activity.id,
                  child: Text(
                    '${_text(activity.data, "nombre", "Actividad")} · ${_formatDate(activity.data["fecha"])}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _exporting
              ? null
              : (value) => setState(() => _activityId = value),
        );
      case _ExportScope.repeatedActivity:
        return Column(
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('repeated-activity-$_activityName'),
              initialValue: _activityName,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Nombre de la actividad',
                prefixIcon: Icon(Icons.repeat_outlined),
              ),
              items: _activityNames
                  .map(
                    (name) => DropdownMenuItem(value: name, child: Text(name)),
                  )
                  .toList(),
              onChanged: _exporting
                  ? null
                  : (value) {
                      setState(() => _activityName = value);
                      _useFullRangeForActivity(value);
                    },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DateFilterButton(
                  label: 'Desde',
                  date: _rangeStart,
                  onTap: _exporting ? null : () => _pickRangeDate(start: true),
                ),
                _DateFilterButton(
                  label: 'Hasta',
                  date: _rangeEnd,
                  onTap: _exporting ? null : () => _pickRangeDate(start: false),
                ),
              ],
            ),
          ],
        );
      case _ExportScope.month:
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<int>(
                key: ValueKey('export-month-$_month'),
                initialValue: _month,
                decoration: const InputDecoration(labelText: 'Mes'),
                items: List.generate(
                  12,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text(_monthNames[index]),
                  ),
                ),
                onChanged: _exporting
                    ? null
                    : (value) => setState(() => _month = value ?? _month),
              ),
            ),
            _yearDropdown(),
          ],
        );
      case _ExportScope.year:
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _yearDropdown(),
            SizedBox(
              width: 340,
              child: DropdownButtonFormField<String?>(
                key: ValueKey('year-activity-$_yearActivityName'),
                initialValue: _yearActivityName,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Bloque de actividades',
                  helperText: 'Opcional',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas las actividades'),
                  ),
                  ..._activityNames.map(
                    (name) => DropdownMenuItem<String?>(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: _exporting
                    ? null
                    : (value) => setState(() => _yearActivityName = value),
              ),
            ),
          ],
        );
    }
  }

  Widget _yearDropdown() {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<int>(
        key: ValueKey('export-year-$_year'),
        initialValue: _year,
        decoration: const InputDecoration(labelText: 'Año'),
        items: _years
            .map(
              (year) => DropdownMenuItem(value: year, child: Text('$year')),
            )
            .toList(),
        onChanged: _exporting
            ? null
            : (value) => setState(() => _year = value ?? _year),
      ),
    );
  }

  Widget _buildAnalysisFilters(List<_LeaderOption> leaders) {
    final zones = leaders
        .map((leader) => leader.zone)
        .where((zone) => zone.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      initiallyExpanded: true,
      title: const Text(
        'Filtros para análisis',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: const Text(
        'Refina el archivo sin alterar los registros originales.',
      ),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<String>(
                key: ValueKey('attendance-status-$_attendanceStatus'),
                initialValue: _attendanceStatus,
                decoration: const InputDecoration(
                  labelText: 'Estado de asistencia',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'presentes',
                    child: Text('Solo presentes'),
                  ),
                  DropdownMenuItem(
                    value: 'todos',
                    child: Text('Todos los registros'),
                  ),
                  DropdownMenuItem(
                    value: 'no_asistio',
                    child: Text('No asistió (registrado)'),
                  ),
                ],
                onChanged: _exporting
                    ? null
                    : (value) => setState(
                          () => _attendanceStatus = value ?? 'presentes',
                        ),
              ),
            ),
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<String>(
                key: ValueKey('activity-status-$_activityStatus'),
                initialValue: _activityStatus,
                decoration: const InputDecoration(
                  labelText: 'Estado de actividad',
                ),
                items: const [
                  DropdownMenuItem(value: 'todos', child: Text('Todos')),
                  DropdownMenuItem(
                    value: 'programada',
                    child: Text('Programada'),
                  ),
                  DropdownMenuItem(value: 'activa', child: Text('Activa')),
                  DropdownMenuItem(value: 'cerrada', child: Text('Cerrada')),
                ],
                onChanged: _exporting
                    ? null
                    : (value) => setState(
                          () => _activityStatus = value ?? 'todos',
                        ),
              ),
            ),
            if (widget.user.isAdmin)
              SizedBox(
                width: 250,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('export-leader-$_leaderId'),
                  initialValue: _leaderId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Líder'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos los líderes'),
                    ),
                    ...leaders.map(
                      (leader) => DropdownMenuItem<String?>(
                        value: leader.id,
                        child: Text(
                          leader.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: _exporting
                      ? null
                      : (value) => setState(() => _leaderId = value),
                ),
              ),
            if (widget.user.isAdmin)
              SizedBox(
                width: 250,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('export-zone-$_zone'),
                  initialValue: _zone,
                  decoration: const InputDecoration(labelText: 'Zona'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todas las zonas'),
                    ),
                    ...zones.map(
                      (zone) => DropdownMenuItem<String?>(
                        value: zone,
                        child: Text(zone),
                      ),
                    ),
                  ],
                  onChanged: _exporting
                      ? null
                      : (value) => setState(() => _zone = value),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _includeContactData,
          onChanged: _exporting
              ? null
              : (value) => setState(() => _includeContactData = value),
          title: const Text('Incluir edad y teléfono'),
          subtitle: const Text(
            'Útil para segmentación; desactivado por privacidad.',
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _includeIdentifiers,
          onChanged: _exporting
              ? null
              : (value) => setState(() => _includeIdentifiers = value),
          title: const Text('Incluir identificadores técnicos'),
          subtitle: const Text(
            'Agrega los IDs de actividad, persona y líder para cruces de datos.',
          ),
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Nota: “No asistió” solo cuenta registros guardados con ese estado; no equivale automáticamente a todo el padrón ausente.',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _export(List<AttendanceExportActivity> activities) async {
    setState(() {
      _exporting = true;
      _error = null;
    });

    try {
      final leaders = await _leadersFuture;
      final result = await _buildExportRows(
        firestore: widget.firestore,
        user: widget.user,
        activities: activities,
        leaders: leaders,
        attendanceStatus: _attendanceStatus,
        leaderId: _leaderId,
        zone: _zone,
      );
      if (result.rows.isEmpty) {
        throw StateError(
          'No hay registros de asistencia que coincidan con los filtros seleccionados.',
        );
      }

      final bytes = createAttendanceWorkbook(
        rows: result.rows,
        scopeTitle: _scopeTitle,
        filterDescription: _filterDescription(leaders),
        includeContactData: _includeContactData,
        includeIdentifiers: _includeIdentifiers,
      );
      final filename = _buildFilename();
      _downloadXlsx(bytes, filename);

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Excel generado: ${result.rows.length} registros en $filename',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError
            ? error.message
            : 'No se pudo generar el Excel. Verifica tu conexión e inténtalo nuevamente.';
      });
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _filterDescription(List<_LeaderOption> leaders) {
    final parts = <String>[_scopeTitle];
    switch (_scope) {
      case _ExportScope.specificActivity:
        final activity = _datedActivities
            .where((item) => item.id == _activityId)
            .firstOrNull;
        if (activity != null) {
          parts.add(
            '${_text(activity.data, "nombre", "Actividad")} (${_formatDate(activity.data["fecha"])})',
          );
        }
      case _ExportScope.repeatedActivity:
        parts.add(_activityName ?? 'Sin actividad');
        parts.add(
          '${DateFormat('yyyy-MM-dd').format(_rangeStart)} a ${DateFormat('yyyy-MM-dd').format(_rangeEnd)}',
        );
      case _ExportScope.month:
        parts.add('${_monthNames[_month - 1]} $_year');
      case _ExportScope.year:
        parts.add('$_year');
        if (_yearActivityName != null) parts.add(_yearActivityName!);
    }
    parts.add(
      switch (_attendanceStatus) {
        'todos' => 'todos los estados de asistencia',
        'no_asistio' => 'no asistió (registrado)',
        _ => 'solo presentes',
      },
    );
    if (_activityStatus != 'todos') {
      parts.add('actividad: $_activityStatus');
    }
    if (_leaderId != null) {
      final leader = leaders.where((item) => item.id == _leaderId).firstOrNull;
      parts.add('líder: ${leader?.name ?? _leaderId}');
    }
    if (_zone != null) parts.add('zona: $_zone');
    return parts.join(' · ');
  }

  String _buildFilename() {
    final suffix = switch (_scope) {
      _ExportScope.specificActivity => 'actividad',
      _ExportScope.repeatedActivity => 'mismas_actividades',
      _ExportScope.month => '${_year}_${_month.toString().padLeft(2, '0')}',
      _ExportScope.year => 'anio_$_year',
    };
    return 'asistencia_$suffix.xlsx';
  }
}

class _DateFilterButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback? onTap;

  const _DateFilterButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.calendar_today_outlined),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text('$label: ${DateFormat('yyyy-MM-dd').format(date)}'),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

class AttendanceExportRow {
  final String activityId;
  final String activityName;
  final DateTime activityDate;
  final String activityStatus;
  final String jovenId;
  final String jovenName;
  final bool attended;
  final String leaderId;
  final String leaderName;
  final String zone;
  final int? age;
  final String phone;
  final DateTime? updatedAt;

  const AttendanceExportRow({
    required this.activityId,
    required this.activityName,
    required this.activityDate,
    required this.activityStatus,
    required this.jovenId,
    required this.jovenName,
    required this.attended,
    required this.leaderId,
    required this.leaderName,
    required this.zone,
    required this.age,
    required this.phone,
    required this.updatedAt,
  });
}

class _ExportBuildResult {
  final List<AttendanceExportRow> rows;

  const _ExportBuildResult(this.rows);
}

Future<_ExportBuildResult> _buildExportRows({
  required FirebaseFirestore firestore,
  required AttendanceExportUser user,
  required List<AttendanceExportActivity> activities,
  required List<_LeaderOption> leaders,
  required String attendanceStatus,
  required String? leaderId,
  required String? zone,
}) async {
  final activityById = {
    for (final activity in activities) activity.id: activity
  };
  final attendanceDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  if (user.isAdmin) {
    for (final ids in _chunks(activityById.keys.toList(), 10)) {
      final snapshot = await firestore
          .collection('asistencias')
          .where('activityId', whereIn: ids)
          .get();
      attendanceDocs.addAll(snapshot.docs);
    }
  } else {
    final snapshot = await firestore
        .collection('asistencias')
        .where('leaderId', isEqualTo: user.uid)
        .get();
    attendanceDocs.addAll(
      snapshot.docs.where(
        (doc) => activityById.containsKey(_text(doc.data(), 'activityId')),
      ),
    );
  }

  final statusFiltered = attendanceDocs.where((doc) {
    final data = doc.data();
    final attended = data['attended'] == true;
    if (attendanceStatus == 'presentes' && !attended) return false;
    if (attendanceStatus == 'no_asistio' && attended) return false;
    return activityById.containsKey(_text(data, 'activityId'));
  }).toList();

  final jovenIds = statusFiltered
      .map((doc) => _text(doc.data(), 'jovenId'))
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();
  final jovenesById = <String, Map<String, dynamic>>{};

  if (user.isAdmin) {
    for (final ids in _chunks(jovenIds, 10)) {
      final snapshot = await firestore
          .collection('jovenes')
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      for (final doc in snapshot.docs) {
        jovenesById[doc.id] = doc.data();
      }
    }
  } else {
    final snapshot = await firestore
        .collection('jovenes')
        .where('leaderId', isEqualTo: user.uid)
        .get();
    for (final doc in snapshot.docs) {
      if (jovenIds.contains(doc.id)) jovenesById[doc.id] = doc.data();
    }
  }

  final leaderById = {for (final leader in leaders) leader.id: leader};
  final rows = <AttendanceExportRow>[];
  for (final attendanceDoc in statusFiltered) {
    final attendance = attendanceDoc.data();
    final activityId = _text(attendance, 'activityId');
    final activity = activityById[activityId];
    if (activity == null) continue;
    final activityDate = _exportDate(activity.data['fecha']);
    if (activityDate == null) continue;

    final jovenId = _text(attendance, 'jovenId');
    final joven = jovenesById[jovenId] ?? const <String, dynamic>{};
    final ownerId = _text(
      attendance,
      'leaderId',
      _text(joven, 'leaderId'),
    );
    if (!user.isAdmin && ownerId != user.uid) continue;
    if (leaderId != null && ownerId != leaderId) continue;

    final leader = leaderById[ownerId];
    final leaderName = leader?.name.trim().isNotEmpty == true
        ? leader!.name.trim()
        : _text(
            attendance,
            'leaderName',
            _text(joven, 'leaderName', 'Líder no disponible'),
          );
    final leaderZone = _normalizeZone(
      leader?.zone ?? _text(attendance, 'leaderZone'),
    );
    if (zone != null && leaderZone != _normalizeZone(zone)) continue;

    final jovenName = _text(
      joven,
      'nombre',
      _text(attendance, 'jovenNombre', 'Persona no disponible'),
    );
    final rawAge = joven['edad'];
    final age = rawAge is int ? rawAge : int.tryParse(rawAge?.toString() ?? '');

    rows.add(
      AttendanceExportRow(
        activityId: activityId,
        activityName: _text(
          activity.data,
          'nombre',
          _text(attendance, 'activityName', 'Actividad'),
        ),
        activityDate: activityDate,
        activityStatus: _activityStatusLabel(
          _text(activity.data, 'estado', 'programada'),
        ),
        jovenId: jovenId,
        jovenName: jovenName,
        attended: attendance['attended'] == true,
        leaderId: ownerId,
        leaderName: leaderName,
        zone: leaderZone.isEmpty ? 'Sin zona' : leaderZone,
        age: age,
        phone: _text(joven, 'telefono', _text(attendance, 'telefono')),
        updatedAt: _exportDate(attendance['updatedAt']) ??
            _exportDate(attendance['createdAt']),
      ),
    );
  }

  rows.sort((a, b) {
    final date = a.activityDate.compareTo(b.activityDate);
    if (date != 0) return date;
    final activity =
        a.activityName.toLowerCase().compareTo(b.activityName.toLowerCase());
    if (activity != 0) return activity;
    final owner =
        a.leaderName.toLowerCase().compareTo(b.leaderName.toLowerCase());
    if (owner != 0) return owner;
    return a.jovenName.toLowerCase().compareTo(b.jovenName.toLowerCase());
  });
  return _ExportBuildResult(rows);
}

Uint8List createAttendanceWorkbook({
  required List<AttendanceExportRow> rows,
  required String scopeTitle,
  required String filterDescription,
  required bool includeContactData,
  required bool includeIdentifiers,
}) {
  final excel = Excel.createExcel();
  final summary = excel['Resumen'];
  final detail = excel['Asistencia'];
  excel.delete('Sheet1');
  excel.setDefaultSheet('Resumen');

  final titleStyle = CellStyle(
    backgroundColorHex: 'FF4338CA'.excelColor,
    fontColorHex: ExcelColor.white,
    fontSize: 18,
    bold: true,
    verticalAlign: VerticalAlign.Center,
  );
  final sectionStyle = CellStyle(
    backgroundColorHex: 'FFE0E7FF'.excelColor,
    fontColorHex: 'FF312E81'.excelColor,
    bold: true,
    verticalAlign: VerticalAlign.Center,
  );
  final headerStyle = CellStyle(
    backgroundColorHex: 'FF4F46E5'.excelColor,
    fontColorHex: ExcelColor.white,
    bold: true,
    textWrapping: TextWrapping.WrapText,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinExcelBorder(),
    rightBorder: _thinExcelBorder(),
    topBorder: _thinExcelBorder(),
    bottomBorder: _thinExcelBorder(),
  );
  final bodyStyle = CellStyle(
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thinExcelBorder(),
    rightBorder: _thinExcelBorder(),
    topBorder: _thinExcelBorder(),
    bottomBorder: _thinExcelBorder(),
  );
  final alternateBodyStyle = bodyStyle.copyWith(
    backgroundColorHexVal: 'FFF8FAFC'.excelColor,
  );
  final noteStyle = CellStyle(
    backgroundColorHex: 'FFFFF7ED'.excelColor,
    fontColorHex: 'FF9A3412'.excelColor,
    italic: true,
    textWrapping: TextWrapping.WrapText,
    verticalAlign: VerticalAlign.Center,
  );
  final dateStyle = bodyStyle.copyWith(
    numberFormat: CustomDateTimeNumFormat(formatCode: 'yyyy-mm-dd'),
  );
  final alternateDateStyle = alternateBodyStyle.copyWith(
    numberFormat: CustomDateTimeNumFormat(formatCode: 'yyyy-mm-dd'),
  );
  final dateTimeStyle = bodyStyle.copyWith(
    numberFormat: CustomDateTimeNumFormat(formatCode: 'yyyy-mm-dd hh:mm'),
  );
  final alternateDateTimeStyle = alternateBodyStyle.copyWith(
    numberFormat: CustomDateTimeNumFormat(formatCode: 'yyyy-mm-dd hh:mm'),
  );

  summary.merge(
    CellIndex.indexByString('A1'),
    CellIndex.indexByString('F1'),
    customValue: TextCellValue('Reporte de asistencia'),
  );
  summary.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
  summary.setRowHeight(0, 30);
  _writeExcelRow(
    summary,
    2,
    ['Tipo de reporte', scopeTitle],
    labelStyle: sectionStyle,
  );
  _writeExcelRow(
    summary,
    3,
    ['Filtros aplicados', filterDescription],
    labelStyle: sectionStyle,
  );
  _writeExcelRow(
    summary,
    4,
    [
      'Generado',
      DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
    ],
    labelStyle: sectionStyle,
  );

  final includedActivityIds = rows.map((row) => row.activityId).toSet();
  final presentCount = rows.where((row) => row.attended).length;
  final absentRecordedCount = rows.length - presentCount;
  const kpiHeaders = ['Métrica', 'Valor'];
  _writeStyledExcelRow(summary, 6, kpiHeaders, headerStyle);
  final kpis = <List<CellValue?>>[
    [
      TextCellValue('Actividades con registros'),
      IntCellValue(includedActivityIds.length)
    ],
    [TextCellValue('Registros exportados'), IntCellValue(rows.length)],
    [TextCellValue('Presentes'), IntCellValue(presentCount)],
    [
      TextCellValue('No asistió (registrado)'),
      IntCellValue(absentRecordedCount)
    ],
    [
      TextCellValue('Personas únicas'),
      IntCellValue(rows
          .map((row) => row.jovenId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .length),
    ],
  ];
  for (var index = 0; index < kpis.length; index++) {
    _writeStyledCellValues(
      summary,
      index + 7,
      kpis[index],
      index.isEven ? bodyStyle : alternateBodyStyle,
    );
  }

  final activitySummary = <String, List<AttendanceExportRow>>{};
  for (final row in rows) {
    activitySummary.putIfAbsent(row.activityId, () => []).add(row);
  }
  _writeStyledExcelRow(
    summary,
    13,
    [
      'Actividad',
      'Fecha',
      'Estado',
      'Presentes',
      'No asistió\n(registrado)',
      'Total exportado',
    ],
    headerStyle,
  );
  final summaries = activitySummary.values.toList()
    ..sort((a, b) => a.first.activityDate.compareTo(b.first.activityDate));
  for (var index = 0; index < summaries.length; index++) {
    final group = summaries[index];
    final first = group.first;
    final rowIndex = 14 + index;
    final style = index.isEven ? bodyStyle : alternateBodyStyle;
    _writeStyledCellValues(
      summary,
      rowIndex,
      [
        TextCellValue(first.activityName),
        DateCellValue(
          year: first.activityDate.year,
          month: first.activityDate.month,
          day: first.activityDate.day,
        ),
        TextCellValue(first.activityStatus),
        IntCellValue(group.where((item) => item.attended).length),
        IntCellValue(group.where((item) => !item.attended).length),
        IntCellValue(group.length),
      ],
      style,
    );
    summary
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
        .cellStyle = index.isEven ? dateStyle : alternateDateStyle;
  }
  final noteRow = 15 + summaries.length;
  summary.merge(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: noteRow),
    CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: noteRow),
    customValue: TextCellValue(
      'Nota metodológica: “No asistió” corresponde únicamente a registros guardados con attended=false. No representa personas sin registro de asistencia.',
    ),
  );
  summary
      .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: noteRow))
      .cellStyle = noteStyle;
  summary.setRowHeight(noteRow, 34);
  for (var column = 0; column < 6; column++) {
    summary.setColumnWidth(
        column, [30.0, 14.0, 15.0, 13.0, 17.0, 15.0][column]);
  }

  final headers = <String>[
    'Fecha',
    'Año',
    'Mes',
    'Día de semana',
    'Actividad',
    'Estado de actividad',
    'Persona',
    'Asistencia',
    'Líder',
    'Zona',
    if (includeContactData) ...['Edad', 'Teléfono'],
    'Registro actualizado',
    if (includeIdentifiers) ...['ActivityId', 'JovenId', 'LeaderId'],
  ];
  detail.merge(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    CellIndex.indexByColumnRow(columnIndex: headers.length - 1, rowIndex: 0),
    customValue: TextCellValue('Detalle de asistencia'),
  );
  detail.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
  detail.setRowHeight(0, 30);
  detail.merge(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
    CellIndex.indexByColumnRow(columnIndex: headers.length - 1, rowIndex: 1),
    customValue: TextCellValue(filterDescription),
  );
  detail.cell(CellIndex.indexByString('A2')).cellStyle = noteStyle.copyWith(
    backgroundColorHexVal: 'FFEEF2FF'.excelColor,
    fontColorHexVal: 'FF3730A3'.excelColor,
  );
  detail.setRowHeight(1, 28);
  _writeStyledExcelRow(detail, 3, headers, headerStyle);
  detail.setRowHeight(3, 30);

  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final rowIndex = index + 4;
    final alternate = index.isOdd;
    final values = <CellValue?>[
      DateCellValue(
        year: row.activityDate.year,
        month: row.activityDate.month,
        day: row.activityDate.day,
      ),
      IntCellValue(row.activityDate.year),
      TextCellValue(_spanishMonth(row.activityDate.month)),
      TextCellValue(_spanishWeekday(row.activityDate.weekday)),
      TextCellValue(row.activityName),
      TextCellValue(row.activityStatus),
      TextCellValue(row.jovenName),
      TextCellValue(row.attended ? 'Presente' : 'No asistió'),
      TextCellValue(row.leaderName),
      TextCellValue(row.zone),
      if (includeContactData) ...[
        row.age == null ? null : IntCellValue(row.age!),
        TextCellValue(row.phone),
      ],
      row.updatedAt == null
          ? null
          : DateTimeCellValue(
              year: row.updatedAt!.year,
              month: row.updatedAt!.month,
              day: row.updatedAt!.day,
              hour: row.updatedAt!.hour,
              minute: row.updatedAt!.minute,
              second: row.updatedAt!.second,
            ),
      if (includeIdentifiers) ...[
        TextCellValue(row.activityId),
        TextCellValue(row.jovenId),
        TextCellValue(row.leaderId),
      ],
    ];
    _writeStyledCellValues(
      detail,
      rowIndex,
      values,
      alternate ? alternateBodyStyle : bodyStyle,
    );
    detail
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
        .cellStyle = alternate ? alternateDateStyle : dateStyle;
    final updatedColumn = includeContactData ? 12 : 10;
    detail
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: updatedColumn,
            rowIndex: rowIndex,
          ),
        )
        .cellStyle = alternate ? alternateDateTimeStyle : dateTimeStyle;
  }

  final widths = <double>[
    13,
    9,
    13,
    16,
    30,
    20,
    28,
    16,
    25,
    14,
    if (includeContactData) ...[9, 18],
    21,
    if (includeIdentifiers) ...[27, 27, 27],
  ];
  for (var column = 0; column < widths.length; column++) {
    detail.setColumnWidth(column, widths[column]);
  }

  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('No se pudo codificar el archivo de Excel.');
  }
  return Uint8List.fromList(bytes);
}

xlsx.Border _thinExcelBorder() => xlsx.Border(
      borderStyle: xlsx.BorderStyle.Thin,
      borderColorHex: 'FFD7DCE5'.excelColor,
    );

void _writeExcelRow(
  Sheet sheet,
  int rowIndex,
  List<String> values, {
  required CellStyle labelStyle,
}) {
  for (var column = 0; column < values.length; column++) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: rowIndex),
    );
    cell.value = TextCellValue(values[column]);
    if (column == 0) cell.cellStyle = labelStyle;
  }
}

void _writeStyledExcelRow(
  Sheet sheet,
  int rowIndex,
  List<String> values,
  CellStyle style,
) {
  _writeStyledCellValues(
    sheet,
    rowIndex,
    values.map<CellValue?>((value) => TextCellValue(value)).toList(),
    style,
  );
}

void _writeStyledCellValues(
  Sheet sheet,
  int rowIndex,
  List<CellValue?> values,
  CellStyle style,
) {
  for (var column = 0; column < values.length; column++) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: rowIndex),
    );
    cell.value = values[column];
    cell.cellStyle = style;
  }
}

List<List<T>> _chunks<T>(List<T> items, int size) {
  final result = <List<T>>[];
  for (var index = 0; index < items.length; index += size) {
    final end = (index + size).clamp(0, items.length);
    result.add(items.sublist(index, end));
  }
  return result;
}

String _text(
  Map<String, dynamic> data,
  String key, [
  String fallback = '',
]) {
  final value = data[key];
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

DateTime? _exportDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value == null) return null;
  return DateTime.tryParse(value.toString().trim());
}

String _formatDate(dynamic value) {
  final date = _exportDate(value);
  return date == null ? 'Sin fecha' : DateFormat('yyyy-MM-dd').format(date);
}

String _normalizeName(String value) => value.trim().toLowerCase();

String _normalizeZone(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return '';
  final match =
      RegExp(r'^(?:zona\s*)?([0-9]+)$', caseSensitive: false).firstMatch(clean);
  return match == null ? clean : 'Zona ${match.group(1)}';
}

String _activityStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'activa':
      return 'Activa';
    case 'cerrada':
      return 'Cerrada';
    default:
      return 'Programada';
  }
}

String _spanishMonth(int month) => const [
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
    ][month - 1];

String _spanishWeekday(int weekday) => const [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ][weekday - 1];

void _downloadXlsx(Uint8List bytes, String filename) {
  if (!kIsWeb) {
    throw StateError('La descarga directa está disponible en la versión web.');
  }
  final blob = html.Blob([
    bytes,
  ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}
