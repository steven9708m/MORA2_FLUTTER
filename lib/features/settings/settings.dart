part of '../../app.dart';

class ConfiguracionPage extends StatelessWidget {
  final User currentUser;
  final LeaderProfile leader;

  const ConfiguracionPage({
    super.key,
    required this.currentUser,
    required this.leader,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Panel(
          title: 'Perfil',
          eyebrow: 'CUENTA ACTIVA',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFEDEBFF),
                child: Text(
                  leader.name.trim().isEmpty
                      ? 'JV'
                      : leader.name.trim().characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leader.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser.email ?? leader.email,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.verified_user, size: 18),
                          label: Text(
                            isAdmin(leader.role) ? 'Administrador' : 'Líder',
                          ),
                        ),
                        Chip(
                          avatar: const Icon(Icons.place_outlined, size: 18),
                          label: Text(
                            leader.zone.isEmpty ? 'Sin zona' : leader.zone,
                          ),
                        ),
                        Chip(
                          avatar: const Icon(Icons.shield_outlined, size: 18),
                          label: Text(
                            leader.status.isEmpty
                                ? 'Sin estado'
                                : leader.status,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Permisos',
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Nivel de acceso',
                value: isAdmin(leader.role)
                    ? 'Acceso completo al sistema'
                    : 'Gestión limitada a tus registros',
              ),
              const Divider(height: 24),
              _SettingsRow(
                icon: Icons.groups_outlined,
                title: 'Jóvenes y reportes',
                value: isAdmin(leader.role)
                    ? 'Puede consultar registros de todos los líderes'
                    : 'Solo puede consultar sus jóvenes y reportes',
              ),
              const Divider(height: 24),
              _SettingsRow(
                icon: Icons.event_available_outlined,
                title: 'Asistencia',
                value: isAdmin(leader.role)
                    ? 'Puede filtrar asistencia por líder o zona'
                    : 'Puede marcar asistencia de sus jóvenes',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Sesión',
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Cierra sesión al terminar de trabajar en un equipo compartido.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () => auth.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF4F46E5)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        ),
      ],
    );
  }
}
