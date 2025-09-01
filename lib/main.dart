import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/imoveis_page.dart';
import 'pages/clientes_page.dart';
import 'pages/contratos_page.dart';
import 'pages/despesas_page.dart';
import 'pages/relatorios_page.dart';
import 'pages/share_page.dart';
import 'pages/imovel_detalhes_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa Supabase (logs no console para acompanhar)
  debugPrint('[init] Iniciando Supabase...');
  await Supabase.initialize(
    url: 'https://cnmdhsjmmbibkywuvatm.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNubWRoc2ptbWJpYmt5d3V2YXRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU5MTA0MjUsImV4cCI6MjA3MTQ4NjQyNX0.pVZJrf5Hv24yUHEfroURqugIhSNbh21GfczW00Y2SFk',
    debug: true,
  );
  debugPrint('[init] Supabase inicializado');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _mode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final m = prefs.getString('theme_mode') ?? 'system';
    setState(() {
      _mode = _stringToMode(m);
    });
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _modeToString(mode));
  }

  String _modeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  ThemeMode _stringToMode(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void _cycleTheme() {
    setState(() {
      if (_mode == ThemeMode.light) {
        _mode = ThemeMode.dark;
      } else if (_mode == ThemeMode.dark) {
        _mode = ThemeMode.system;
      } else {
        _mode = ThemeMode.light;
      }
    });
    _saveTheme(_mode);
  }

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFFA4D65E); // verde lima do visual.md
    final lightScheme = ColorScheme.fromSeed(seedColor: kPrimary);
    final darkScheme = ColorScheme.fromSeed(seedColor: kPrimary, brightness: Brightness.dark);

    return MaterialApp(
      title: 'Gestão de Aluguel de Imóveis',
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFAF8),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          margin: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: lightScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: lightScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kPrimary, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.black,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: lightScheme.surface,
          selectedColor: kPrimary.withOpacity(0.2),
          showCheckmark: false,
          labelStyle: TextStyle(color: lightScheme.onSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: kPrimary,
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          elevation: 8,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: darkScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: darkScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kPrimary, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.black,
            shape: const StadiumBorder(),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: darkScheme.surface,
          selectedColor: kPrimary.withOpacity(0.25),
          showCheckmark: false,
          labelStyle: TextStyle(color: darkScheme.onSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: kPrimary,
          unselectedItemColor: Colors.white70,
          showUnselectedLabels: true,
        ),
      ),
      themeMode: _mode,
      debugShowCheckedModeBanner: false,
      // Rota pública de compartilhamento: /#/share?i=<imovel_id>
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');
        if (uri.path == '/share') {
          return MaterialPageRoute(builder: (_) => const SharePage());
        }
        if (uri.path == '/imovel/detalhes') {
          final args = settings.arguments;
          if (args is Map<String, dynamic>) {
            return MaterialPageRoute(builder: (_) => ImovelDetalhesPage(item: args));
          }
          // Fallback se argumentos não vierem no formato esperado
          return MaterialPageRoute(builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Detalhes do imóvel')),
            body: const Center(child: Text('Dados do imóvel não informados')), 
          ));
        }
        return MaterialPageRoute(builder: (_) => AuthGate(onToggleTheme: _cycleTheme, mode: _mode));
      },
      home: AuthGate(onToggleTheme: _cycleTheme, mode: _mode),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.onToggleTheme, required this.mode});

  final VoidCallback onToggleTheme;
  final ThemeMode mode;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStream;
  bool _finalized = false;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
    debugPrint('[AuthGate] init, sessão? ${Supabase.instance.client.auth.currentSession != null}');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginPage();
        }
        // Finaliza cadastro pendente uma única vez
        if (!_finalized) {
          _finalized = true;
          Future.microtask(_finalizePendingSignupIfAny);
        }
        return AppShell(onToggleTheme: widget.onToggleTheme, mode: widget.mode);
      },
    );
  }

  Future<void> _finalizePendingSignupIfAny() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingEmail = prefs.getString('pending_email');
      final pendingNome = prefs.getString('pending_nome');
      final pendingPerfil = prefs.getString('pending_perfil');
      if (pendingEmail == null || pendingNome == null || pendingPerfil == null) {
        debugPrint('[AuthGate] Sem dados pendentes de cadastro');
        return;
      }
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      debugPrint('[AuthGate] Finalizando cadastro: user=${user.id}');
      // Metadados no auth
      await SupabaseService().setAuthUserMetadata(nome: pendingNome, perfil: pendingPerfil);
      // Linha em public.usuarios (ignora erros de tabela/colunas divergentes)
      await SupabaseService().upsertUsuarioRow(userId: user.id, nome: pendingNome, email: pendingEmail);
      // Limpa pendências
      await prefs.remove('pending_email');
      await prefs.remove('pending_nome');
      await prefs.remove('pending_perfil');
      debugPrint('[AuthGate] Cadastro finalizado');
    } catch (e) {
      debugPrint('[AuthGate][WARN] finalize signup failed: $e');
    }
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.onToggleTheme, required this.mode});

  final VoidCallback onToggleTheme;
  final ThemeMode mode;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final _pages = const [
    // Páginas base; implementações com logs
    DashboardPage(),
    ImoveisPage(),
    ClientesPage(),
    ContratosPage(),
    DespesasPage(),
    RelatoriosPage(),
  ];

  final _labels = const [
    'Dashboard',
    'Imóveis',
    'Clientes',
    'Contratos',
    'Despesas',
    'Relatórios',
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('[AppShell] iniciado, sessão atual: '
        '${Supabase.instance.client.auth.currentSession != null}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestão de Aluguel • ${_labels[_index]}'),
        actions: [
          IconButton(
            tooltip: 'Alternar tema (atual: ' + widget.mode.name + ')',
            icon: Icon(
              widget.mode == ThemeMode.dark
                  ? Icons.dark_mode
                  : (widget.mode == ThemeMode.light
                      ? Icons.light_mode
                      : Icons.brightness_auto),
            ),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          debugPrint('[Nav] mudou para ${_labels[i]}');
          setState(() => _index = i);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Imóveis',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Clientes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            activeIcon: Icon(Icons.article),
            label: 'Contratos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payments_outlined),
            activeIcon: Icon(Icons.payments),
            label: 'Despesas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.picture_as_pdf_outlined),
            activeIcon: Icon(Icons.picture_as_pdf),
            label: 'Relatórios',
          ),
        ],
      ),
    );
  }
}
