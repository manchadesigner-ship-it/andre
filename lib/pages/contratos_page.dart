import 'package:flutter/material.dart';
import '../utils/format.dart';
import '../services/supabase_service.dart';

class ContratosPage extends StatefulWidget {
  const ContratosPage({super.key});

  @override
  State<ContratosPage> createState() => _ContratosPageState();
}

class _ContratosPageState extends State<ContratosPage> {
  final _svc = SupabaseService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    debugPrint('[Contratos] initState');
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    return _svc.list('contratos', limit: 200);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    // Carrega opções para dropdowns
    final imoveis = await _svc.list('imoveis', limit: 500);
    final clientes = await _svc.list('clientes', limit: 500);
    final rawImovel = item != null ? item['imovel_id'] : null;
    int? selectedImovelId = rawImovel is int
        ? rawImovel
        : int.tryParse((rawImovel)?.toString() ?? '');
    final rawCliente = item != null ? item['cliente_id'] : null;
    int? selectedClienteId = rawCliente is int
        ? rawCliente
        : int.tryParse((rawCliente)?.toString() ?? '');
    final valorCtrl = TextEditingController(text: item?['valor_aluguel']?.toString() ?? '');
    final vencCtrl = TextEditingController(text: item?['vencimento_dia']?.toString() ?? '');
    final inicioCtrl = TextEditingController(text: item?['inicio']?.toString() ?? '');
    final fimCtrl = TextEditingController(text: item?['fim']?.toString() ?? '');
    String tipo = item?['tipo'] ?? 'residencial';
    final multaCtrl = TextEditingController(text: item?['multa']?.toString() ?? '0');
    final jurosCtrl = TextEditingController(text: item?['juros']?.toString() ?? '0');
    final descCtrl = TextEditingController(text: item?['desconto']?.toString() ?? '0');
    final isEdit = item != null;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Editar contrato' : 'Novo contrato'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedImovelId,
                  decoration: const InputDecoration(labelText: 'Imóvel*'),
                  items: imoveis.map((e) => DropdownMenuItem(
                    value: e['id'] as int,
                    child: Text('${e['id']} - ${e['endereco'] ?? 'Sem endereço'}'),
                  )).toList(),
                  onChanged: (v) => selectedImovelId = v,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedClienteId,
                  decoration: const InputDecoration(labelText: 'Cliente*'),
                  items: clientes.map((e) => DropdownMenuItem(
                    value: e['id'] as int,
                    child: Text('${e['id']} - ${e['nome'] ?? 'Sem nome'}'),
                  )).toList(),
                  onChanged: (v) => selectedClienteId = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valorCtrl,
                  decoration: const InputDecoration(labelText: 'Valor do aluguel*'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vencCtrl,
                  decoration: const InputDecoration(labelText: 'Dia do vencimento*'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: inicioCtrl,
                  decoration: const InputDecoration(labelText: 'Data de início*'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fimCtrl,
                  decoration: const InputDecoration(labelText: 'Data de fim'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'residencial', child: Text('Residencial')),
                    DropdownMenuItem(value: 'comercial', child: Text('Comercial')),
                  ],
                  onChanged: (v) => tipo = v ?? 'residencial',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: multaCtrl,
                  decoration: const InputDecoration(labelText: 'Multa (%)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: jurosCtrl,
                  decoration: const InputDecoration(labelText: 'Juros (%)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Desconto (%)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedImovelId == null || selectedClienteId == null || valorCtrl.text.trim().isEmpty) return;
              if (!ctx.mounted) return;
              final payload = {
                'imovel_id': selectedImovelId,
                'cliente_id': selectedClienteId,
                'valor_aluguel': double.tryParse(valorCtrl.text.trim()) ?? 0,
                'vencimento_dia': int.tryParse(vencCtrl.text.trim()) ?? 1,
                'inicio': inicioCtrl.text.trim(),
                'fim': fimCtrl.text.trim().isEmpty ? null : fimCtrl.text.trim(),
                'tipo': tipo,
                'multa': double.tryParse(multaCtrl.text.trim()) ?? 0,
                'juros': double.tryParse(jurosCtrl.text.trim()) ?? 0,
                'desconto': double.tryParse(descCtrl.text.trim()) ?? 0,
                'status': 'ativo',
              };
              try {
                if (isEdit) {
                  await _svc.updateById('contratos', item['id'], payload);
                } else {
                  await _svc.insert('contratos', payload);
                }
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(true);
              } catch (e) {
                debugPrint('[Contratos][ERROR] save: $e');
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (res == true) _refresh();
  }

  Future<void> _delete(dynamic id) async {
    try {
      await _svc.deleteById('contratos', id);
      _refresh();
    } catch (e) {
      debugPrint('[Contratos][ERROR] delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Contratos] build');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Contratos', style: Theme.of(context).textTheme.titleLarge),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Novo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snap.data ?? [];
                if (data.isEmpty) return const Center(child: Text('Nenhum contrato'));
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('ID')),
                              DataColumn(label: Text('Imóvel')),
                              DataColumn(label: Text('Cliente')),
                              DataColumn(label: Text('Aluguel')),
                              DataColumn(label: Text('Venc.')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Ações')),
                            ],
                            rows: data.map((e) => DataRow(cells: [
                              DataCell(Text('${e['id']}')),
                              DataCell(Text('${e['imovel_id'] ?? ''}')),
                              DataCell(Text('${e['cliente_id'] ?? ''}')),
                              DataCell(Text(formatBrl(e['valor_aluguel']))),
                              DataCell(Text('${e['vencimento_dia'] ?? ''}')),
                              DataCell(Text('${e['status'] ?? ''}')),
                              DataCell(Row(children: [
                                IconButton(onPressed: () => _openForm(item: e), icon: const Icon(Icons.edit)),
                                IconButton(onPressed: () => _delete(e['id']), icon: const Icon(Icons.delete), color: Colors.red),
                              ])),
                            ])).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}
