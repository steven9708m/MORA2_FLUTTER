part of '../../app.dart';

class LeadersPage extends StatelessWidget {
  final User currentUser;
  final LeaderProfile leader;

  const LeadersPage({
    super.key,
    required this.currentUser,
    required this.leader,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAdmin(leader.role)) {
      return const _RoleLockedCard(
        message: 'Solo el administrador puede gestionar líderes.',
      );
    }
    final mobile = MediaQuery.of(context).size.width < 900;

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _showLeaderDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo líder'),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Card(
            child: PagedQuery(
              query: db.collection('leaders').orderBy('name'),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _ErrorState(_errorMessage(snap.error!));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs
                    .where((doc) => doc.data()['archived'] != true)
                    .toList();
                docs.sort((a, b) {
                  final aTs = a.data()['createdAt'];
                  final bTs = b.data()['createdAt'];
                  if (aTs is Timestamp && bTs is Timestamp) {
                    return bTs.compareTo(aTs);
                  }
                  return 0;
                });

                if (docs.isEmpty) {
                  return const Center(child: Text('No hay líderes.'));
                }

                if (!mobile) {
                  return _LeadersDataTable(docs: docs);
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(safeString(data, 'name', 'Sin nombre')),
                      subtitle: Text(
                        '${safeString(data, "email")} · Zona: ${_displayLeaderZone(safeString(data, "zone"))}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text(safeString(data, 'role', 'leader'))),
                          IconButton(
                            onPressed: () => _showLeaderDialog(
                              context,
                              docId: d.id,
                              initial: data,
                            ),
                            tooltip: 'Editar líder',
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () =>
                                _sendLeaderAccess(context, d.id, data),
                            tooltip: 'Enviar acceso',
                            icon: const Icon(Icons.mark_email_unread_outlined),
                          ),
                          IconButton(
                            onPressed: () =>
                                _deleteDoc('leaders', d.id, context),
                            tooltip: 'Archivar líder',
                            icon: const Icon(Icons.archive_outlined),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TableText extends StatelessWidget {
  final String value;
  final double width;
  final bool strong;

  const _TableText(this.value, {required this.width, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final text = value.trim().isEmpty ? '-' : value.trim();

    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: strong ? FontWeight.w800 : null),
      ),
    );
  }
}

class _LeadersDataTable extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const _LeadersDataTable({required this.docs});

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
              DataColumn(label: Text('Correo')),
              DataColumn(label: Text('Zona')),
              DataColumn(label: Text('Rol')),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: docs.map((d) {
              final data = d.data();
              return DataRow(
                cells: [
                  DataCell(
                    _TableText(
                      safeString(data, 'name', 'Sin nombre'),
                      width: 220,
                      strong: true,
                    ),
                  ),
                  DataCell(_TableText(safeString(data, 'email'), width: 260)),
                  DataCell(
                    _TableText(
                      _displayLeaderZone(safeString(data, 'zone')),
                      width: 140,
                    ),
                  ),
                  DataCell(
                    Chip(label: Text(safeString(data, 'role', 'leader'))),
                  ),
                  DataCell(
                    Chip(label: Text(safeString(data, 'status', 'activo'))),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Editar líder',
                          onPressed: () => _showLeaderDialog(
                            context,
                            docId: d.id,
                            initial: data,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Enviar acceso',
                          onPressed: () =>
                              _sendLeaderAccess(context, d.id, data),
                          icon: const Icon(Icons.mark_email_unread_outlined),
                        ),
                        IconButton(
                          tooltip: 'Archivar líder',
                          onPressed: () => _deleteDoc('leaders', d.id, context),
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
}

const List<String> _leaderZones = ['Zona 1', 'Zona 2', 'Zona 3'];

String _normalizeLeaderZone(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return '';

  final numericZone = RegExp(
    r'^(zona\s*)?([0-9]+)$',
    caseSensitive: false,
  ).firstMatch(clean);
  if (numericZone != null) {
    return 'Zona ${numericZone.group(2)}';
  }

  for (final zone in _leaderZones) {
    if (zone.toLowerCase() == clean.toLowerCase()) return zone;
  }
  return clean;
}

String _displayLeaderZone(String value) {
  final zone = _normalizeLeaderZone(value);
  return zone.isEmpty ? 'Sin zona' : zone;
}

List<String> _leaderZoneQueryValues(String value) {
  final normalized = _normalizeLeaderZone(value);
  final values = <String>{normalized};
  final numericZone = RegExp(
    r'^Zona\s+([0-9]+)$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (numericZone != null) values.add(numericZone.group(1)!);
  return values.toList();
}

final Set<String> _accessRequests = {};
Future<void> _sendLeaderAccess(
  BuildContext context,
  String docId,
  Map<String, dynamic> data,
) async {
  if (!_accessRequests.add(docId)) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await appServices.leaders.sendAccess(docId);
    messenger.showSnackBar(
      const SnackBar(content: Text('Correo de acceso enviado.')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(_errorMessage(e))));
  } finally {
    _accessRequests.remove(docId);
  }
}

Future<void> _showLeaderDialog(
  BuildContext context, {
  String? docId,
  Map<String, dynamic>? initial,
}) async {
  final formKey = GlobalKey<FormState>();
  final data = initial ?? {};
  final name = TextEditingController(text: safeString(data, 'name'));
  final email = TextEditingController(text: safeString(data, 'email'));
  var zone = _normalizeLeaderZone(safeString(data, 'zone', _leaderZones.first));
  var status = safeString(data, 'status', 'activo');
  var role = safeString(data, 'role', 'leader');
  try {
    await _showEditor(
      context,
      title: docId == null ? 'Nuevo líder' : 'Editar líder',
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
            controller: email,
            enabled: docId == null,
            maxLength: 254,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo'),
            validator: validateEmail,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: zone,
            decoration: const InputDecoration(labelText: 'Zona'),
            items: {
              ..._leaderZones,
              zone,
            }.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => zone = v!,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: const [
              DropdownMenuItem(value: 'activo', child: Text('Activo')),
              DropdownMenuItem(value: 'inactivo', child: Text('Inactivo')),
            ],
            onChanged: (v) => status = v!,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Rol'),
            items: const [
              DropdownMenuItem(value: 'leader', child: Text('Líder')),
              DropdownMenuItem(value: 'admin', child: Text('Administrador')),
            ],
            onChanged: (v) => role = v!,
          ),
          if (docId == null)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Recibirá un correo para establecer su contraseña.'),
            ),
        ],
      ),
      onSave: () async {
        final uid = await appServices.leaders.save({
          'name': name.text.trim(),
          'email': email.text.trim(),
          'zone': zone,
          'status': status,
          'role': role,
        }, id: docId);
        if (docId == null && status == 'activo') {
          try {
            await appServices.leaders.sendAccess(uid);
          } catch (_) {
            return 'Perfil guardado. No se pudo enviar el correo; utiliza Enviar acceso para reintentarlo.';
          }
          return 'Líder guardado y correo de acceso enviado.';
        }
        return 'Líder guardado.';
      },
    );
  } finally {
    name.dispose();
    email.dispose();
  }
}
