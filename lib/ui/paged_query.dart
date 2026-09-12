import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Cursor pagination with one listener for the current page. Uses one extra
/// result as a sentinel, avoiding a separate count request for each navigation.
class PagedQuery extends StatefulWidget {
  final Query<Map<String, dynamic>> query;
  final Widget Function(
    BuildContext,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>,
  )
  builder;
  const PagedQuery({super.key, required this.query, required this.builder});
  @override
  State<PagedQuery> createState() => _PagedQueryState();
}

class _PagedQueryState extends State<PagedQuery> {
  static const pageSize = 25;
  final List<DocumentSnapshot<Map<String, dynamic>>?> _cursors = [null];
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  int _page = 0;
  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(PagedQuery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _page = 0;
      _cursors.clear();
      _cursors.add(null);
      _subscribe();
    }
  }

  void _subscribe() {
    var query = widget.query;
    if (_cursors[_page] != null) {
      query = query.startAfterDocument(_cursors[_page]!);
    }
    _stream = query.limit(pageSize + 1).snapshots();
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) => Column(
          children: [
            Expanded(
              child: widget.builder(
                context,
                snapshot.hasData
                    ? AsyncSnapshot.withData(
                        snapshot.connectionState,
                        _PageSnapshot(snapshot.data!, pageSize),
                      )
                    : snapshot,
              ),
            ),
            if (snapshot.hasData)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text('Página ${_page + 1} · hasta $pageSize registros'),
                    IconButton(
                      tooltip: 'Página anterior',
                      icon: const Icon(Icons.chevron_left),
                      onPressed:
                          _page == 0 ||
                              snapshot.connectionState != ConnectionState.active
                          ? null
                          : () => setState(() {
                              _page--;
                              _subscribe();
                            }),
                    ),
                    IconButton(
                      tooltip: 'Página siguiente',
                      icon: const Icon(Icons.chevron_right),
                      onPressed:
                          snapshot.data!.docs.length <= pageSize ||
                              snapshot.connectionState != ConnectionState.active
                          ? null
                          : () => setState(() {
                              final last = snapshot.data!.docs[pageSize - 1];
                              if (_cursors.length > _page + 1) {
                                _cursors.removeRange(
                                  _page + 1,
                                  _cursors.length,
                                );
                              }
                              _cursors.add(last);
                              _page++;
                              _subscribe();
                            }),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _PageSnapshot implements QuerySnapshot<Map<String, dynamic>> {
  final QuerySnapshot<Map<String, dynamic>> source;
  final int limit;
  _PageSnapshot(this.source, this.limit);
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs =>
      source.docs.take(limit).toList();
  @override
  int get size => docs.length;
  @override
  SnapshotMetadata get metadata => source.metadata;
  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => source.docChanges
      .where((change) => docs.any((doc) => doc.id == change.doc.id))
      .toList();
}
