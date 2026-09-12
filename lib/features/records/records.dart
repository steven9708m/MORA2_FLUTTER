part of '../../app.dart';

class RegistrosPage extends StatelessWidget {
  final User currentUser;
  final LeaderProfile leader;

  const RegistrosPage({
    super.key,
    required this.currentUser,
    required this.leader,
  });

  Query<Map<String, dynamic>> _query() {
    final base = db.collection('registros').where('archived', isEqualTo: false);
    if (isAdmin(leader.role)) {
      return base.orderBy('createdAt', descending: true);
    }
    // Puede requerir indice compuesto en Firestore.
    return base
        .where('leaderId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return CrudCollectionPage(
      title: 'Registros',
      collection: 'registros',
      query: _query(),
      fields: const [
        CrudField('titulo', 'Título'),
        CrudField('descripcion', 'Descripción', maxLines: 3),
      ],
      currentUser: currentUser,
    );
  }
}

class ReportesPage extends StatelessWidget {
  final User currentUser;
  final LeaderProfile leader;

  const ReportesPage({
    super.key,
    required this.currentUser,
    required this.leader,
  });

  Query<Map<String, dynamic>> _query() {
    final base = db.collection('reportes').where('archived', isEqualTo: false);
    if (isAdmin(leader.role)) {
      return base.orderBy('createdAt', descending: true);
    }
    // Puede requerir indice compuesto en Firestore.
    return base
        .where('leaderId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return CrudCollectionPage(
      title: 'Reportes',
      collection: 'reportes',
      query: _query(),
      fields: const [
        CrudField('fecha', 'Fecha del reporte', isDate: true),
        CrudField('semana', 'Semana'),
        CrudField(
          'asistencia',
          'Asistencia',
          keyboardType: TextInputType.number,
        ),
        CrudField('observaciones', 'Observaciones', maxLines: 3),
      ],
      currentUser: currentUser,
    );
  }
}

class CrudField {
  final String key;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool isDate;

  const CrudField(
    this.key,
    this.label, {
    this.maxLines = 1,
    this.keyboardType,
    this.isDate = false,
  });
}

class CrudCollectionPage extends StatelessWidget {
  final String title;
  final String collection;
  final Query<Map<String, dynamic>> query;
  final List<CrudField> fields;
  final User currentUser;

  const CrudCollectionPage({
    super.key,
    required this.title,
    required this.collection,
    required this.query,
    required this.fields,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 900;

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _showCrudDialog(
              context,
              collection: collection,
              fields: fields,
              currentUser: currentUser,
            ),
            icon: const Icon(Icons.add),
            label: Text('Nuevo $title'),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Card(
            child: PagedQuery(
              query: query,
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
                if (docs.isEmpty) {
                  return Center(child: Text('No hay $title.'));
                }

                if (!mobile) {
                  return _CrudDataTable(
                    docs: docs,
                    fields: fields,
                    collection: collection,
                    currentUser: currentUser,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();
                    return ListTile(
                      title: Text(
                        safeString(data, fields.first.key, 'Sin título'),
                      ),
                      subtitle: Text(
                        fields
                            .skip(1)
                            .map(
                              (f) =>
                                  '${f.label}: ${f.isDate ? _formatAnyDate(data[f.key]) : safeString(data, f.key)}',
                            )
                            .join(' · '),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            onPressed: () => _showCrudDialog(
                              context,
                              collection: collection,
                              fields: fields,
                              currentUser: currentUser,
                              docId: d.id,
                              initial: data,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () =>
                                _deleteDoc(collection, d.id, context),
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

class _CrudDataTable extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final List<CrudField> fields;
  final String collection;
  final User currentUser;

  const _CrudDataTable({
    required this.docs,
    required this.fields,
    required this.collection,
    required this.currentUser,
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
            columns: [
              ...fields.map((field) => DataColumn(label: Text(field.label))),
              const DataColumn(label: Text('Acciones')),
            ],
            rows: docs.map((d) {
              final data = d.data();
              return DataRow(
                cells: [
                  ...fields.map((field) {
                    final width = field.keyboardType == TextInputType.number
                        ? 110.0
                        : (field.maxLines > 1 ? 360.0 : 220.0);
                    return DataCell(
                      _TableText(
                        field.isDate
                            ? _formatAnyDate(data[field.key])
                            : safeString(data, field.key),
                        width: width,
                        strong: field == fields.first,
                      ),
                    );
                  }),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Editar',
                          onPressed: () => _showCrudDialog(
                            context,
                            collection: collection,
                            fields: fields,
                            currentUser: currentUser,
                            docId: d.id,
                            initial: data,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Archivar',
                          onPressed: () =>
                              _deleteDoc(collection, d.id, context),
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

Future<void> _showCrudDialog(
  BuildContext context, {
  required String collection,
  required List<CrudField> fields,
  required User currentUser,
  String? docId,
  Map<String, dynamic>? initial,
}) async {
  final formKey = GlobalKey<FormState>();
  final ctrls = {
    for (final field in fields)
      field.key: TextEditingController(
        text: field.isDate
            ? _formatAnyDate(
                initial?[field.key] ?? initial?['createdAt'] ?? Timestamp.now(),
              )
            : safeString(initial ?? {}, field.key),
      ),
  };
  try {
    await _showEditor(
      context,
      title:
          '${docId == null ? 'Nuevo' : 'Editar'} ${collection == 'reportes' ? 'reporte' : 'registro'}',
      formKey: formKey,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: fields
            .map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: ctrls[field.key],
                  readOnly: field.isDate,
                  onTap: field.isDate
                      ? () =>
                            _pickDateIntoController(context, ctrls[field.key]!)
                      : null,
                  maxLines: field.maxLines,
                  maxLength: field.maxLines > 1 ? 3000 : 150,
                  keyboardType: field.keyboardType,
                  decoration: InputDecoration(
                    labelText: field.label,
                    suffixIcon: field.isDate
                        ? const Icon(Icons.calendar_today_outlined)
                        : null,
                  ),
                  validator: (value) {
                    if (_required(value) != null) return _required(value);
                    if (field.isDate && parseDate(value) == null) {
                      return 'Selecciona una fecha válida.';
                    }
                    if (field.keyboardType == TextInputType.number) {
                      final number = int.tryParse(value!.trim());
                      if (number == null || number < 0 || number > 100000) {
                        return 'Ingresa un entero entre 0 y 100000.';
                      }
                    }
                    return null;
                  },
                ),
              ),
            )
            .toList(),
      ),
      onSave: () async {
        final payload = <String, dynamic>{
          for (final field in fields)
            field.key: field.isDate
                ? dateTimestamp(ctrls[field.key]!.text)
                : field.keyboardType == TextInputType.number
                ? int.parse(ctrls[field.key]!.text.trim())
                : ctrls[field.key]!.text.trim(),
          if (docId == null) 'archived': false,
          'leaderId': initial?['leaderId'] ?? currentUser.uid,
          'createdAt': initial?['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        final reference = docId == null
            ? db.collection(collection).doc()
            : db.collection(collection).doc(docId);
        await reference.set(payload, SetOptions(merge: true));
        return 'Registro guardado.';
      },
    );
  } finally {
    for (final controller in ctrls.values) {
      controller.dispose();
    }
  }
}
