import 'package:flutter/material.dart';
import '../utils/format.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

// For web CSV download
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  DateTimeRange? _range;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _despesas = [];
  List<Map<String, dynamic>> _imoveis = [];
  List<Map<String, dynamic>> _contratos = [];
  List<Map<String, dynamic>> _clientes = [];

  // Formata datas para o padrão DDMMYYYY
  String _fmtDate(dynamic v) {
    if (v == null) return '';
    DateTime? d;
    if (v is DateTime) d = v;
    d ??= DateTime.tryParse(v.toString());
    if (d == null) return '';
    return DateFormat('ddMMyyyy').format(d);
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[Relatórios] initState');
    _range = _currentMonth();
    _load();
  }

  Future<void> _exportPdfDespesas() async {
    try {
      final fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');
      final doc = pw.Document();
      final total = _despesas.fold<double>(0, (sum, e) {
        final v = (e['valor'] is num) ? (e['valor'] as num).toDouble() : double.tryParse('${e['valor']}') ?? 0;
        return sum + v;
      });
      final porTipo = <String, double>{};
      for (final e in _despesas) {
        final t = '${e['tipo_despesa'] ?? '-'}';
        final v = (e['valor'] is num) ? (e['valor'] as num).toDouble() : double.tryParse('${e['valor']}') ?? 0;
        porTipo[t] = (porTipo[t] ?? 0) + v;
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => [
            pw.Header(level: 0, child: pw.Text('Relatório de Despesas', style: pw.TextStyle(fontSize: 20))),
            pw.Text('Período: ' + (_range == null
                ? '-'
                : DateFormat('ddMMyyyy').format(_range!.start) + ' a ' + DateFormat('ddMMyyyy').format(_range!.end))),
            pw.SizedBox(height: 8),
            pw.Text('Resumo por Tipo'),
            pw.SizedBox(height: 4),
            pw.Table.fromTextArray(
              headers: ['Tipo', 'Total'],
              data: porTipo.entries.map((e) => [e.key, fmt.format(e.value)]).toList(),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Total geral: ' + fmt.format(total)),
            pw.SizedBox(height: 16),
            pw.Text('Detalhes'),
            pw.SizedBox(height: 4),
            pw.Table.fromTextArray(
              headers: ['ID','Imóvel','Tipo','Descrição','Valor','Data'],
              data: _despesas.map((e) {
                final v = (e['valor'] is num) ? (e['valor'] as num).toDouble() : double.tryParse('${e['valor']}') ?? 0;
                return [
                  '${e['id'] ?? ''}',
                  '${e['imovel_id'] ?? ''}',
                  '${e['tipo_despesa'] ?? ''}',
                  '${e['descricao'] ?? ''}',
                  fmt.format(v),
                  (_fmtDate(e['data']).isEmpty ? '-' : _fmtDate(e['data'])),
                ];
              }).toList(),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      // Abrir diálogo de impressão/salvar (funciona no Web/desktop/mobile)
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'despesas_relatorio.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao exportar PDF: $e')),
      );
    }
  }

  DateTimeRange _currentMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      // Despesas por período
      final data = await client
          .from('despesas')
          .select()
          .gte('data', _range!.start.toIso8601String())
          .lte('data', _range!.end.toIso8601String());
      _despesas = (data as List).cast<Map<String, dynamic>>();

      // Demais tabelas (sem filtro de período por ora)
      final imoveis = await client.from('imoveis').select();
      _imoveis = (imoveis as List).cast<Map<String, dynamic>>();
      final contratos = await client.from('contratos').select();
      _contratos = (contratos as List).cast<Map<String, dynamic>>();
      // clientes pode não existir no schema do usuário; tentar e ignorar erro
      try {
        final clientes = await client.from('clientes').select();
        _clientes = (clientes as List).cast<Map<String, dynamic>>();
      } catch (_) {
        _clientes = [];
      }
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _exportCsvDespesas() {
    try {
      final headers = ['id','imovel_id','tipo_despesa','descricao','valor','data'];
      final lines = <String>[];
      lines.add(headers.join(';'));
      for (final m in _despesas) {
        lines.add([
          m['id'],
          m['imovel_id'],
          m['tipo_despesa'],
          (m['descricao'] ?? '').toString().replaceAll(';', ','),
          (m['valor'] ?? '').toString(),
          _fmtDate(m['data']),
        ].join(';'));
      }
      final csv = lines.join('\n');
      if (kIsWeb) {
        final bytes = html.Blob([csv], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(bytes);
        final a = html.AnchorElement(href: url)
          ..download = 'despesas_${_fmtDate(_range!.start)}_${_fmtDate(_range!.end)}.csv'
          ..style.display = 'none';
        html.document.body!.children.add(a);
        a.click();
        a.remove();
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao exportar CSV: $e')),
      );
    }
  }

  void _exportCsvImoveis() {
    try {
      final headers = ['id','tipo','endereco','valor_aluguel','status'];
      final lines = <String>[];
      lines.add(headers.join(';'));
      for (final m in _imoveis) {
        lines.add([
          m['id'] ?? m['ID'] ?? '',
          m['tipo'] ?? '',
          (m['endereco'] ?? '').toString().replaceAll(';', ','),
          (m['valor_aluguel'] ?? '').toString(),
          m['status'] ?? '',
        ].join(';'));
      }
      final csv = lines.join('\n');
      if (kIsWeb) {
        final bytes = html.Blob([csv], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(bytes);
        final a = html.AnchorElement(href: url)
          ..download = 'imoveis.csv'
          ..style.display = 'none';
        html.document.body!.children.add(a);
        a.click();
        a.remove();
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao exportar CSV: $e')),
      );
    }
  }

  void _exportCsvContratos() {
    try {
      final headers = ['id','imovel_id','cliente_id','valor_aluguel','vencimento_dia','inicio','fim','status'];
      final lines = <String>[];
      lines.add(headers.join(';'));
      for (final m in _contratos) {
        lines.add([
          m['id'],
          m['imovel_id'],
          m['cliente_id'],
          (m['valor_aluguel'] ?? '').toString(),
          m['vencimento_dia'],
          m['inicio'],
          m['fim'],
          m['status'],
        ].join(';'));
      }
      final csv = lines.join('\n');
      if (kIsWeb) {
        final bytes = html.Blob([csv], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(bytes);
        final a = html.AnchorElement(href: url)
          ..download = 'contratos.csv'
          ..style.display = 'none';
        html.document.body!.children.add(a);
        a.click();
        a.remove();
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao exportar CSV: $e')),
      );
    }
  }

  void _exportCsvClientes() {
    try {
      final headers = ['id','nome','email','telefone'];
      final lines = <String>[];
      lines.add(headers.join(';'));
      for (final m in _clientes) {
        lines.add([
          m['id'] ?? m['ID'] ?? '',
          (m['nome'] ?? '').toString().replaceAll(';', ','),
          (m['email'] ?? m['e - mail'] ?? '').toString().replaceAll(';', ','),
          (m['telefone'] ?? '').toString(),
        ].join(';'));
      }
      final csv = lines.join('\n');
      if (kIsWeb) {
        final bytes = html.Blob([csv], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(bytes);
        final a = html.AnchorElement(href: url)
          ..download = 'clientes.csv'
          ..style.display = 'none';
        html.document.body!.children.add(a);
        a.click();
        a.remove();
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao exportar CSV: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Relatórios] build');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DefaultTabController(
        length: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Relatórios', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const TabBar(
              tabs: [
                Tab(text: 'Despesas'),
                Tab(text: 'Imóveis'),
                Tab(text: 'Contratos'),
                Tab(text: 'Clientes'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Erro: $_error'))
                      : TabBarView(
                          children: [
                            // Despesas
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _pickRange,
                                      icon: const Icon(Icons.date_range),
                                      label: Text(_range == null
                                          ? 'Período'
                                          : '${_fmtDate(_range!.start)} a ${_fmtDate(_range!.end)}'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _despesas.isEmpty ? null : _exportPdfDespesas,
                                      icon: const Icon(Icons.picture_as_pdf),
                                      label: const Text('Exportar PDF'),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _despesas.isEmpty ? null : _exportCsvDespesas,
                                      icon: const Icon(Icons.download),
                                      label: const Text('Exportar CSV'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _despesas.isEmpty
                                      ? const Center(child: Text('Sem despesas no período'))
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columns: const [
                                              DataColumn(label: Text('ID')),
                                              DataColumn(label: Text('Imóvel')),
                                              DataColumn(label: Text('Tipo')),
                                              DataColumn(label: Text('Descrição')),
                                              DataColumn(label: Text('Valor')),
                                              DataColumn(label: Text('Data')),
                                            ],
                                            rows: _despesas
                                                .map((e) => DataRow(cells: [
                                                      DataCell(Text('${e['id']}')),
                                                      DataCell(Text('${e['imovel_id'] ?? ''}')),
                                                      DataCell(Text('${e['tipo_despesa'] ?? ''}')),
                                                      DataCell(Text('${e['descricao'] ?? ''}')),
                                                      DataCell(Text('${e['valor'] ?? ''}')),
                                                      DataCell(Text('${e['data'] ?? ''}')),
                                                    ]))
                                                .toList(),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                            // Imóveis
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton.icon(
                                    onPressed: _imoveis.isEmpty ? null : _exportCsvImoveis,
                                    icon: const Icon(Icons.download),
                                    label: const Text('Exportar CSV'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _imoveis.isEmpty
                                      ? const Center(child: Text('Sem registros'))
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columns: const [
                                              DataColumn(label: Text('ID')),
                                              DataColumn(label: Text('Tipo')),
                                              DataColumn(label: Text('Endereço')),
                                              DataColumn(label: Text('Aluguel')),
                                              DataColumn(label: Text('Status')),
                                            ],
                                            rows: _imoveis
                                                .map((e) => DataRow(cells: [
                                                      DataCell(Text('${e['id'] ?? e['ID'] ?? ''}')),
                                                      DataCell(Text('${e['tipo'] ?? ''}')),
                                                      DataCell(Text('${e['endereco'] ?? ''}')),
                                                      DataCell(Text(formatBrl(e['valor_aluguel']))),
                                                      DataCell(Text('${e['status'] ?? ''}')),
                                                    ]))
                                                .toList(),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                            // Contratos
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton.icon(
                                    onPressed: _contratos.isEmpty ? null : _exportCsvContratos,
                                    icon: const Icon(Icons.download),
                                    label: const Text('Exportar CSV'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _contratos.isEmpty
                                      ? const Center(child: Text('Sem registros'))
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columns: const [
                                              DataColumn(label: Text('ID')),
                                              DataColumn(label: Text('Imóvel')),
                                              DataColumn(label: Text('Cliente')),
                                              DataColumn(label: Text('Aluguel')),
                                              DataColumn(label: Text('Venc.')),
                                              DataColumn(label: Text('Início')),
                                              DataColumn(label: Text('Fim')),
                                              DataColumn(label: Text('Status')),
                                            ],
                                            rows: _contratos
                                                .map((e) => DataRow(cells: [
                                                      DataCell(Text('${e['id']}')),
                                                      DataCell(Text('${e['imovel_id'] ?? ''}')),
                                                      DataCell(Text('${e['cliente_id'] ?? ''}')),
                                                      DataCell(Text(formatBrl(e['valor_aluguel']))),
                                                      DataCell(Text('${e['vencimento_dia'] ?? ''}')),
                                                      DataCell(Text(_fmtDate(e['inicio']))),
                                                      DataCell(Text(_fmtDate(e['fim']))),
                                                      DataCell(Text('${e['status'] ?? ''}')),
                                                    ]))
                                                .toList(),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                            // Clientes
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton.icon(
                                    onPressed: _clientes.isEmpty ? null : _exportCsvClientes,
                                    icon: const Icon(Icons.download),
                                    label: const Text('Exportar CSV'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _clientes.isEmpty
                                      ? const Center(child: Text('Sem registros'))
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columns: const [
                                              DataColumn(label: Text('ID')),
                                              DataColumn(label: Text('Nome')),
                                              DataColumn(label: Text('Email')),
                                              DataColumn(label: Text('Telefone')),
                                            ],
                                            rows: _clientes
                                                .map((e) => DataRow(cells: [
                                                      DataCell(Text('${e['id'] ?? e['ID'] ?? ''}')),
                                                      DataCell(Text('${e['nome'] ?? ''}')),
                                                      DataCell(Text('${e['email'] ?? e['e - mail'] ?? ''}')),
                                                      DataCell(Text('${e['telefone'] ?? ''}')),
                                                    ]))
                                                .toList(),
                                          ),
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
    );
  }
}
