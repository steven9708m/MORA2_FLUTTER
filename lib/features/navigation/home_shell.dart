part of '../../app.dart';

class HomeShell extends StatefulWidget {
  final User currentUser;
  final LeaderProfile leader;
  final String section;

  const HomeShell({
    super.key,
    required this.currentUser,
    required this.leader,
    this.section = 'dashboard',
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _paths = {
    'Dashboard': 'dashboard',
    'Líderes': 'lideres',
    'Registros': 'registros',
    'Reportes': 'reportes',
    'Jóvenes': 'jovenes',
    'Actividades': 'actividades',
    'Configuración': 'configuracion',
  };
  int get selectedIndex {
    final index = _items.indexWhere(
      (item) => _paths[item.title] == widget.section,
    );
    return index < 0 ? 0 : index;
  }

  void _navigate(int index) => context.go('/${_paths[_items[index].title]}');

  void _selectSection(String title) {
    final index = _items.indexWhere((item) => item.title == title);
    if (index == -1) return;
    _navigate(index);
  }

  List<_MenuItem> get _items {
    final all = [
      const _MenuItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
      const _MenuItem(
        'Líderes',
        Icons.manage_accounts_outlined,
        Icons.manage_accounts,
      ),
      const _MenuItem('Registros', Icons.list_alt_outlined, Icons.list_alt),
      const _MenuItem('Reportes', Icons.bar_chart_outlined, Icons.bar_chart),
      const _MenuItem('Jóvenes', Icons.groups_outlined, Icons.groups),
      const _MenuItem(
        'Actividades',
        Icons.event_note_outlined,
        Icons.event_note,
      ),
      const _MenuItem('Configuración', Icons.settings_outlined, Icons.settings),
    ];

    if (isAdmin(widget.leader.role)) return all;

    return [all[0], all[2], all[3], all[4], all[5], all[6]];
  }

  List<Widget> _pages() {
    final all = [
      DashboardPage(
        currentUser: widget.currentUser,
        leader: widget.leader,
        onSelectSection: _selectSection,
      ),
      LeadersPage(currentUser: widget.currentUser, leader: widget.leader),
      RegistrosPage(currentUser: widget.currentUser, leader: widget.leader),
      ReportesPage(currentUser: widget.currentUser, leader: widget.leader),
      JovenesPage(currentUser: widget.currentUser, leader: widget.leader),
      ActividadesPage(currentUser: widget.currentUser, leader: widget.leader),
      ConfiguracionPage(currentUser: widget.currentUser, leader: widget.leader),
    ];

    if (isAdmin(widget.leader.role)) return all;

    return [all[0], all[2], all[3], all[4], all[5], all[6]];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final mobile = width < 760;
    final useRail = !mobile;
    final railExtended = width >= 1320;
    final pages = _pages();
    final currentItem = _items[selectedIndex];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: mobile ? 16 : 24,
        title: Text(
          currentItem.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (!mobile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Chip(
                  avatar: const Icon(Icons.verified_user, size: 18),
                  label: Text(
                    isAdmin(widget.leader.role) ? 'Administrador' : 'Líder',
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: useRail
          ? null
          : Drawer(
              child: _MobileDrawer(
                items: _items,
                currentIndex: selectedIndex,
                leader: widget.leader,
                onSelect: (i) {
                  Navigator.pop(context);
                  _navigate(i);
                },
              ),
            ),
      bottomNavigationBar: null,
      body: Row(
        children: [
          if (useRail)
            Container(
              width: railExtended ? 280 : 96,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _SidebarBrand(
                        extended: railExtended,
                        leader: widget.leader,
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: NavigationRail(
                          selectedIndex: selectedIndex,
                          onDestinationSelected: (i) {
                            _navigate(i);
                          },
                          extended: railExtended,
                          minWidth: 72,
                          minExtendedWidth: 252,
                          labelType: NavigationRailLabelType.none,
                          leading: const SizedBox.shrink(),
                          destinations: _items
                              .map(
                                (e) => NavigationRailDestination(
                                  icon: Tooltip(
                                    message: e.title,
                                    child: Icon(e.icon),
                                  ),
                                  selectedIcon: Tooltip(
                                    message: e.title,
                                    child: Icon(e.selectedIcon),
                                  ),
                                  label: Text(e.title),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(mobile ? 12 : 18),
                child: _PageFrame(child: pages[selectedIndex]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  final Widget child;

  const _PageFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth > 1440
            ? 1440.0
            : constraints.maxWidth;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: maxWidth,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  final List<_MenuItem> items;
  final int currentIndex;
  final LeaderProfile leader;
  final void Function(int index) onSelect;

  const _MobileDrawer({
    required this.items,
    required this.currentIndex,
    required this.leader,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFF6A3EC5),
                    child: Icon(Icons.groups, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'JV Líderes',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        Text(leader.name, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < items.length; i++)
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              selected: currentIndex == i,
              leading: Icon(
                currentIndex == i ? items[i].selectedIcon : items[i].icon,
              ),
              title: Text(items[i].title),
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  final bool extended;
  final LeaderProfile leader;

  const _SidebarBrand({required this.extended, required this.leader});

  @override
  Widget build(BuildContext context) {
    if (!extended) {
      return const Center(
        child: CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFF4F46E5),
          child: Icon(Icons.groups, color: Colors.white),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF4F46E5),
            child: Icon(Icons.groups, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JV Líderes',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                Text(
                  leader.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final IconData selectedIcon;

  const _MenuItem(this.title, this.icon, this.selectedIcon);
}
