part of '../../app.dart';

class LeaderProfile {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String zone;
  final String status;

  const LeaderProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.zone,
    required this.status,
  });

  factory LeaderProfile.fromDoc(String uid, Map<String, dynamic> data) {
    return LeaderProfile(
      uid: uid,
      name: safeString(data, 'name', 'Usuario'),
      email: safeString(data, 'email'),
      role: safeString(data, 'role', 'leader'),
      zone: _normalizeLeaderZone(safeString(data, 'zone')),
      status: safeString(data, 'status', 'inactivo'),
    );
  }
}

class AuthGate extends StatelessWidget {
  final String section;
  final String? activityId, jovenId, selectedLeaderId, selectedZone;
  const AuthGate({
    super.key,
    this.section = 'dashboard',
    this.activityId,
    this.jovenId,
    this.selectedLeaderId,
    this.selectedZone,
  });
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: auth.authStateChanges(),
    builder: (context, session) {
      if (session.hasError) {
        return const Scaffold(
          body: _ErrorState('No se pudo comprobar la sesión.'),
        );
      }
      if (session.connectionState == ConnectionState.waiting) {
        return const SplashLoading();
      }
      final user = session.data;
      if (user == null) return const LoginPage();
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        key: ValueKey(user.uid),
        stream: db.collection('leaders').doc(user.uid).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(
              body: _ErrorState(
                _errorMessage(snap.error!),
                onRetry: () => auth.signOut(),
              ),
            );
          }
          if (!snap.hasData) return const SplashLoading();
          final data = snap.data!.data();
          if (data == null) {
            return const AccessDeniedPage(
              message:
                  'Tu cuenta todavía no tiene un perfil. Contacta al administrador.',
            );
          }
          final leader = LeaderProfile.fromDoc(user.uid, data);
          if (leader.status != 'activo' ||
              !['admin', 'leader'].contains(leader.role)) {
            return const AccessDeniedPage(
              message: 'Tu cuenta está inactiva. Contacta al administrador.',
            );
          }
          if (activityId != null) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: db.collection('actividades').doc(activityId).snapshots(),
              builder: (context, activity) {
                if (activity.hasError) {
                  return Scaffold(
                    body: _ErrorState(_errorMessage(activity.error!)),
                  );
                }
                if (!activity.hasData) return const SplashLoading();
                final activityData = activity.data!.data();
                if (activityData == null) {
                  return const Scaffold(
                    body: _ErrorState('Actividad no encontrada.'),
                  );
                }
                return AsistenciaPage(
                  key: ValueKey(
                    '$activityId:${user.uid}:${leader.role}:$selectedLeaderId:$selectedZone',
                  ),
                  activityId: activityId!,
                  activityData: activityData,
                  currentUser: user,
                  leader: leader,
                  selectedLeaderId: isAdmin(leader.role)
                      ? selectedLeaderId
                      : null,
                  selectedZone: isAdmin(leader.role) ? selectedZone : null,
                );
              },
            );
          }
          if (jovenId != null) {
            return HistorialJovenPage(
              jovenId: jovenId!,
              jovenNombre: 'Joven',
              currentUser: user,
              leader: leader,
            );
          }
          return HomeShell(
            key: ValueKey('${user.uid}:${leader.role}'),
            currentUser: user,
            leader: leader,
            section: section,
          );
        },
      );
    },
  );
}

class SplashLoading extends StatelessWidget {
  const SplashLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class AccessDeniedPage extends StatelessWidget {
  final String message;
  const AccessDeniedPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 34,
                    child: Icon(Icons.lock_outline, size: 34),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Acceso restringido',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => auth.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final Future<void> Function(String email, String password)? signIn;
  final Future<void> Function(String email)? resetPassword;
  const LoginPage({super.key, this.signIn, this.resetPassword});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String _backgroundAsset = 'assets/images/login_background.jpeg';

  final formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  bool obscure = true;
  String? error;

  Future<void> _login() async {
    if (loading || !(formKey.currentState?.validate() ?? false)) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      if (widget.signIn != null) {
        await widget.signIn!(emailCtrl.text.trim(), passCtrl.text);
      } else {
        await auth.signInWithEmailAndPassword(
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = _errorMessage(e));
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Ocurrió un error inesperado. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (loading) return;
    final email = emailCtrl.text.trim();
    final validation = validateEmail(email);
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (widget.resetPassword != null) {
        await widget.resetPassword!(email);
      } else {
        await auth.sendPasswordResetEmail(email: email);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Si el correo tiene una cuenta, recibirás instrucciones para recuperar el acceso.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = _errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 820;
          final horizontalPadding = mobile ? 20.0 : 36.0;
          final verticalPadding = mobile ? 20.0 : 30.0;

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  _backgroundAsset,
                  fit: BoxFit.cover,
                  alignment: mobile ? Alignment.center : Alignment.center,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: mobile ? .64 : .58),
                        const Color(
                          0xFF2B175F,
                        ).withValues(alpha: mobile ? .52 : .42),
                        Colors.black.withValues(alpha: mobile ? .70 : .50),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: mobile ? 520 : 1120,
                        minHeight: constraints.maxHeight - verticalPadding * 2,
                      ),
                      child: mobile
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const _LoginHero(compact: true),
                                const SizedBox(height: 22),
                                _loginCard(context, mobile: true),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Expanded(child: _LoginHero()),
                                const SizedBox(width: 44),
                                SizedBox(
                                  width: 430,
                                  child: _loginCard(context),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _loginCard(BuildContext context, {bool mobile = false}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mobile) ...[
                const Center(
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF4F46E5),
                    child: Icon(
                      Icons.groups_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Bienvenido de vuelta',
                style: TextStyle(
                  color: JVTheme.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa para gestionar líderes, jóvenes, actividades y asistencias.',
                style: TextStyle(color: JVTheme.muted, height: 1.45),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: emailCtrl,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Ingresa tu correo.';
                  if (validateEmail(value) != null) {
                    return 'Ingresa un correo válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: passCtrl,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _login(),
                textInputAction: TextInputAction.done,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: obscure
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Ingresa tu contraseña.';
                  if ((v ?? '').length < 6) {
                    return 'Debe tener al menos 6 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: loading ? null : _resetPassword,
                  child: const Text('Olvidé mi contraseña'),
                ),
              ),
              if (error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: .16),
                    ),
                  ),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loading ? null : _login,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(loading ? 'Ingresando...' : 'Entrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  final bool compact;

  const _LoginHero({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final alignment = compact
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = compact ? TextAlign.center : TextAlign.start;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Container(
          width: compact ? 58 : 68,
          height: compact ? 58 : 68,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .32)),
          ),
          child: const Icon(
            Icons.groups_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'JV Líderes',
          textAlign: textAlign,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 34 : 52,
            fontWeight: FontWeight.w900,
            height: 1.02,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: .32),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 420 : 580),
          child: Text(
            'Una plataforma para cuidar mejor cada registro, actividad y asistencia del grupo juvenil.',
            textAlign: textAlign,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .88),
              fontSize: compact ? 16 : 19,
              height: 1.45,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 28),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FeaturePill(icon: Icons.phone_iphone, text: 'Móvil y PC'),
              _FeaturePill(icon: Icons.security, text: 'Roles seguros'),
              _FeaturePill(
                icon: Icons.analytics_outlined,
                text: 'Seguimiento en vivo',
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeaturePill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: .24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
