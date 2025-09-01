import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;
  int _imoveisDisponiveis = 0;
  int _imoveisAlugados = 0;
  int _contratosAtivos = 0;
  double _despesasTotal = 0;
  double _despesasMes = 0;
  final Map<String, double> _despesasPorTipo = {};
  // Séries por mês (últimos 12 meses)
  final List<String> _ultimos12Meses = [];
  final Map<String, double> _despesaPorMes = {}; // key: yyyy-MM
  final Map<String, double> _receitaPorMes = {}; // key: yyyy-MM

  @override
  void initState() {
    super.initState();
    debugPrint('[Dashboard] initState');
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Reset counters to avoid accumulation between reloads
      _imoveisDisponiveis = 0;
      _imoveisAlugados = 0;
      _contratosAtivos = 0;
      _despesasTotal = 0;
      _despesasMes = 0;
      _despesasPorTipo.clear();
      _ultimos12Meses
        ..clear()
        ..addAll(_buildUltimos12Meses());
      _despesaPorMes
        ..clear()
        ..addEntries(_ultimos12Meses.map((k) => MapEntry(k, 0.0)));
      _receitaPorMes
        ..clear()
        ..addEntries(_ultimos12Meses.map((k) => MapEntry(k, 0.0)));
      final client = Supabase.instance.client;
      // Imóveis
      final imoveis = await client.from('imoveis').select();
      for (final m in (imoveis as List)) {
        final status = ((m as Map)['status']?.toString() ?? '').toLowerCase();
        if (status == 'disponivel') _imoveisDisponiveis++;
        if (status == 'alugado') _imoveisAlugados++;
      }
      // Contratos
      final contratos = await client.from('contratos').select();
      for (final c in (contratos as List)) {
        final status = ((c as Map)['status']?.toString() ?? '').toLowerCase();
        if (status == 'ativo') _contratosAtivos++;
      }
      // Despesas
      final despesas = await client.from('despesas').select();
      final now = DateTime.now();
      for (final d in (despesas as List)) {
        final map = d as Map;
        final valor = (map['valor'] as num?)?.toDouble() ?? 0.0;
        _despesasTotal += valor;
        final dataIso = map['data'] as String?;
        if (dataIso != null) {
          final dt = DateTime.tryParse(dataIso);
          if (dt != null && dt.year == now.year && dt.month == now.month) {
            _despesasMes += valor;
          }
          if (dt != null) {
            final key = _key(dt);
            if (_despesaPorMes.containsKey(key)) {
              _despesaPorMes[key] = (_despesaPorMes[key] ?? 0) + valor;
            }
          }
        }
        final tipo = (map['tipo_despesa']?.toString() ?? 'outros').toLowerCase();
        _despesasPorTipo[tipo] = (_despesasPorTipo[tipo] ?? 0) + valor;
      }

      // Receita mensal estimada: soma de valor_aluguel dos contratos ativos em cada mês
      for (final c in (contratos as List)) {
        final m = c as Map;
        final status = (m['status']?.toString() ?? '').toLowerCase();
        final inicio = DateTime.tryParse('${m['inicio'] ?? ''}');
        final fim = m['fim'] == null || '${m['fim']}'.isEmpty
            ? null
            : DateTime.tryParse('${m['fim']}');
        final aluguel = (m['valor_aluguel'] as num?)?.toDouble() ?? 0.0;
        if (aluguel <= 0) continue;

        for (final ym in _ultimos12Meses) {
          final parts = ym.split('-');
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final start = DateTime(year, month, 1);
          final end = DateTime(year, month + 1, 0, 23, 59, 59);
          final ativoNoMes = status == 'ativo' &&
              (inicio == null || !start.isAfter(inicio)) &&
              (fim == null || !end.isBefore(fim));
          if (ativoNoMes) {
            _receitaPorMes[ym] = (_receitaPorMes[ym] ?? 0) + aluguel;
          }
        }
      }
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Dashboard] build');
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Erro: $_error'));
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        int cols;
        if (maxW >= 1200) cols = 4; else if (maxW >= 900) cols = 3; else if (maxW >= 600) cols = 2; else cols = 1;
        final spacing = 12.0;
        final cardWidth = cols == 1 ? maxW : (maxW - spacing * (cols - 1)) / cols;
        final pieSize = maxW < 600 ? 200.0 : (maxW < 900 ? 260.0 : 320.0);
        final legendWidth = maxW < 480 ? (maxW - 32) : (maxW < 900 ? 320.0 : 420.0);

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Row(
                children: [
                  Text(
                    'Dashboard',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Atualizar',
                    onPressed: _load,
                    icon: Icon(Icons.refresh, color: scheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _card('Imóveis disponíveis', _imoveisDisponiveis.toString(), Icons.home_outlined, scheme.primary, width: cardWidth),
                  _card('Imóveis alugados', _imoveisAlugados.toString(), Icons.meeting_room_outlined, scheme.secondary, width: cardWidth),
                  _card('Contratos ativos', _contratosAtivos.toString(), Icons.article_outlined, scheme.tertiary, width: cardWidth),
                  _card('Despesas total', _formatCurrency(_despesasTotal), Icons.payments_outlined, scheme.error, width: cardWidth),
                  _card('Despesas no mês', _formatCurrency(_despesasMes), Icons.calendar_month_outlined, scheme.primary, width: cardWidth),
                ],
              ),
              const SizedBox(height: 16),
              _pieCardDespesas(pieSize: pieSize, legendWidth: legendWidth),
              const SizedBox(height: 16),
              _netPieCard(pieSize: pieSize, legendWidth: legendWidth),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card(String title, String value, IconData icon, Color color, {double? width}) {
    return SizedBox(
      width: width ?? 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pieCardDespesas({required double pieSize, required double legendWidth}) {
    if (_despesasPorTipo.isEmpty || _despesasTotal <= 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Sem dados de despesas para exibir gráfico.'),
        ),
      );
    }

    final colors = <Color>[
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.brown,
      Colors.indigo,
    ];
    final entries = _despesasPorTipo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: pieSize,
              height: pieSize * 0.75,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 32,
                  sections: [
                    for (int i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value,
                        color: colors[i % colors.length],
                        title: ((entries[i].value / _despesasTotal) * 100)
                                .toStringAsFixed(0) +
                            '%',
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: legendWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Despesas por tipo',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (int i = 0; i < entries.length; i++)
                        _legendItem(
                          label: _labelTipo(entries[i].key),
                          color: colors[i % colors.length],
                          valor: entries[i].value,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem({required String label, required Color color, required double valor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Text('$label: ' + _formatCurrency(valor)),
      ],
    );
  }

  String _labelTipo(String key) {
    switch (key) {
      case 'condominio':
        return 'Condomínio';
      case 'iptu':
        return 'IPTU';
      case 'manutencao':
        return 'Manutenção';
      default:
        return 'Outros';
    }
  }

  String _formatCurrency(double v) {
    final s = v.toStringAsFixed(2);
    return 'R\$ ' + s;
  }

  // Helpers para meses
  List<String> _buildUltimos12Meses() {
    final now = DateTime.now();
    final list = <String>[];
    for (int i = 11; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      list.add('${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}');
    }
    return list;
  }

  String _key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  double get _totalReceita12 => _ultimos12Meses.fold(0.0, (a, k) => a + (_receitaPorMes[k] ?? 0));
  double get _totalDespesa12 => _ultimos12Meses.fold(0.0, (a, k) => a + (_despesaPorMes[k] ?? 0));

  Widget _netPieCard({required double pieSize, required double legendWidth}) {
    final receita = _totalReceita12;
    final despesa = _totalDespesa12;
    if (receita <= 0 && despesa <= 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Sem dados para exibir Receita vs Despesa.'),
        ),
      );
    }
    final total = (receita + despesa) == 0 ? 1 : (receita + despesa);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: pieSize,
              height: pieSize * 0.75,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 32,
                  sections: [
                    PieChartSectionData(
                      value: despesa,
                      color: scheme.error,
                      title: ((despesa / total) * 100).toStringAsFixed(0) + '%',
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: receita,
                      color: scheme.primary,
                      title: ((receita / total) * 100).toStringAsFixed(0) + '%',
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: legendWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Receita vs Despesa (12 meses)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _legendItem(label: 'Despesas', color: scheme.error, valor: despesa),
                      _legendItem(label: 'Receitas', color: scheme.primary, valor: receita),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
