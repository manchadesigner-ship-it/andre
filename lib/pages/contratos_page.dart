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
    
    debugPrint('[Contratos] Imoveis count: ${imoveis.length}');
    debugPrint('[Contratos] Clientes count: ${clientes.length}');
    
    // Debug dos dados dos imóveis
    for (int i = 0; i < imoveis.length && i < 3; i++) {
      debugPrint('[Contratos] Imovel $i: ${imoveis[i]}');
    }
    
    final rawImovel = item != null ? item['imovel_id'] : null;
    int? selectedImovelId = rawImovel is int
        ? rawImovel
        : int.tryParse((rawImovel)?.toString() ?? '');
    final rawCliente = item != null ? item['cliente_id'] : null;
    int? selectedClienteId = rawCliente is int
        ? rawCliente
        : int.tryParse((rawCliente)?.toString() ?? '');
        
    debugPrint('[Contratos] Selected imovel ID: $selectedImovelId');
    debugPrint('[Contratos] Selected cliente ID: $selectedClienteId');
        
    // Filtra apenas imóveis e clientes válidos
    final validImoveis = imoveis.where((e) {
      final id = e['imovel_id']; // Campo correto para imóveis
      final hasValidId = id != null && (id is int || int.tryParse(id.toString()) != null);
      if (!hasValidId) {
        debugPrint('[Contratos] Imovel inválido: $e');
      }
      return hasValidId;
    }).toList();
    
    final validClientes = clientes.where((e) {
      final id = e['id'];
      final hasValidId = id != null && (id is int || int.tryParse(id.toString()) != null);
      if (!hasValidId) {
        debugPrint('[Contratos] Cliente inválido: $e');
      }
      return hasValidId;
    }).toList();
    
    debugPrint('[Contratos] Valid imoveis: ${validImoveis.length}');
    debugPrint('[Contratos] Valid clientes: ${validClientes.length}');
    
    // Debug dos IDs válidos
    final imovelIds = validImoveis.map((e) => e['imovel_id']).toList();
    final clienteIds = validClientes.map((e) => e['id']).toList();
    debugPrint('[Contratos] Imovel IDs: $imovelIds');
    debugPrint('[Contratos] Cliente IDs: $clienteIds');
    
    // Validar se os IDs selecionados existem nas listas válidas
    if (selectedImovelId != null && !imovelIds.contains(selectedImovelId)) {
      debugPrint('[Contratos] ID do imóvel $selectedImovelId não encontrado na lista válida. Resetando...');
      selectedImovelId = null;
    }
    if (selectedClienteId != null && !clienteIds.contains(selectedClienteId)) {
      debugPrint('[Contratos] ID do cliente $selectedClienteId não encontrado na lista válida. Resetando...');
      selectedClienteId = null;
    }
    final valorCtrl = TextEditingController(text: item?['valor_aluguel']?.toString() ?? '');
    final vencCtrl = TextEditingController(text: item?['vencimento_dia']?.toString() ?? '');
    final inicioCtrl = TextEditingController(text: _formatDateForDisplay(item?['inicio']?.toString()));
    final fimCtrl = TextEditingController(text: _formatDateForDisplay(item?['fim']?.toString()));
    String tipo = item?['tipo'] ?? 'residencial';
    final multaCtrl = TextEditingController(text: item?['multa']?.toString() ?? '0');
    final jurosCtrl = TextEditingController(text: item?['juros']?.toString() ?? '0');
    final descCtrl = TextEditingController(text: item?['desconto']?.toString() ?? '0');
    String reajuste = _normalizeReajuste(item?['reajuste']?.toString());
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
                  items: validImoveis.isEmpty 
                    ? [const DropdownMenuItem<int>(value: null, child: Text('Nenhum imóvel encontrado'))]
                    : validImoveis.map((e) => DropdownMenuItem<int>(
                        value: e['imovel_id'] as int,
                        child: Text('${e['imovel_id']} - ${e['endereco'] ?? 'Sem endereço'}'),
                      )).toList(),
                  onChanged: validImoveis.isEmpty ? null : (v) {
                    selectedImovelId = v;
                    debugPrint('[Contratos] Imóvel selecionado: $v');
                  },
                  isExpanded: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedClienteId,
                  decoration: const InputDecoration(labelText: 'Cliente*'),
                  items: validClientes.isEmpty
                    ? [const DropdownMenuItem<int>(value: null, child: Text('Nenhum cliente encontrado'))]
                    : validClientes.map((e) => DropdownMenuItem<int>(
                        value: e['id'] as int,
                        child: Text('${e['id']} - ${e['nome'] ?? 'Sem nome'}'),
                      )).toList(),
                  onChanged: validClientes.isEmpty ? null : (v) {
                    selectedClienteId = v;
                    debugPrint('[Contratos] Cliente selecionado: $v');
                  },
                  isExpanded: true,
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
                  decoration: const InputDecoration(
                    labelText: 'Data de início*',
                    hintText: 'DD/MM/AAAA'
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fimCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Data de fim',
                    hintText: 'DD/MM/AAAA'
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo de contrato'),
                  items: const [
                    DropdownMenuItem(value: 'residencial', child: Text('Residencial')),
                    DropdownMenuItem(value: 'comercial', child: Text('Comercial')),
                    DropdownMenuItem(value: 'temporada', child: Text('Temporada')),
                    DropdownMenuItem(value: 'venda', child: Text('Venda')),
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
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: reajuste,
                  decoration: const InputDecoration(labelText: 'Reajuste do contrato*'),
                  items: const [
                    DropdownMenuItem(value: 'igpm', child: Text('IGPM')),
                    DropdownMenuItem(value: 'nenhum', child: Text('Nenhum')),
                  ],
                  onChanged: (v) => reajuste = v ?? 'igpm',
                  isExpanded: true,
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
              if (selectedImovelId == null || selectedClienteId == null || 
                  valorCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Preencha todos os campos obrigatórios')),
                );
                return;
              }
              if (!ctx.mounted) return;
              // Converter datas para formato ISO válido
              final inicioText = inicioCtrl.text.trim();
              final fimText = fimCtrl.text.trim();
              
              String? inicioFormatted;
              String? fimFormatted;
              
              try {
                if (inicioText.isNotEmpty) {
                  inicioFormatted = _parseAndFormatDate(inicioText);
                }
                if (fimText.isNotEmpty) {
                  fimFormatted = _parseAndFormatDate(fimText);
                }
              } catch (e) {
                debugPrint('[Contratos][ERROR] Formato de data inválido: $e');
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Formato de data inválido. Use DD/MM/AAAA')),
                );
                return;
              }

              final payload = {
                'imovel_id': selectedImovelId,
                'cliente_id': selectedClienteId,
                'valor_aluguel': double.tryParse(valorCtrl.text.trim()) ?? 0,
                'vencimento_dia': int.tryParse(vencCtrl.text.trim()) ?? 1,
                'inicio': inicioFormatted,
                'fim': fimFormatted,
                'tipo': tipo,
                'multa': double.tryParse(multaCtrl.text.trim()) ?? 0,
                'juros': double.tryParse(jurosCtrl.text.trim()) ?? 0,
                'desconto': double.tryParse(descCtrl.text.trim()) ?? 0,
                'reajuste': reajuste,
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

  String _parseAndFormatDate(String dateText) {
    // Tenta diferentes formatos de entrada
    DateTime? parsedDate;
    
    // Formato DD/MM/AAAA
    if (dateText.contains('/')) {
      final parts = dateText.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        
        if (day != null && month != null && year != null) {
          // Corrigir ano de 2 dígitos para 4 dígitos
          final fullYear = year < 100 ? (year < 50 ? 2000 + year : 1900 + year) : year;
          parsedDate = DateTime(fullYear, month, day);
        }
      }
    }
    
    // Formato AAAA-MM-DD (já válido)
    if (parsedDate == null && dateText.contains('-')) {
      parsedDate = DateTime.tryParse(dateText);
    }
    
    if (parsedDate == null) {
      throw FormatException('Data inválida: $dateText. Use formato DD/MM/AAAA');
    }
    
    // Retorna no formato ISO (AAAA-MM-DD)
    return parsedDate.toIso8601String().split('T')[0];
  }

  String _formatDateForDisplay(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    
    try {
      // Se já está no formato AAAA-MM-DD, converter para DD/MM/AAAA
      if (dateString.contains('-')) {
        final parsedDate = DateTime.tryParse(dateString);
        if (parsedDate != null) {
          return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}';
        }
      }
      
      // Se já está no formato DD/MM/AAAA, retornar como está
      if (dateString.contains('/')) {
        return dateString;
      }
      
      return dateString;
    } catch (e) {
      debugPrint('[Contratos] Erro ao formatar data para exibição: $e');
      return dateString;
    }
  }

  String _normalizeReajuste(String? reajuste) {
    const valoresValidos = ['igpm', 'nenhum'];
    
    String reajusteAtual = reajuste ?? 'igpm';
    
    // Mapeamento para valores antigos/diferentes
    switch (reajusteAtual.toLowerCase()) {
      case 'anual':
      case 'annual':
      case 'igp-m':
      case 'igp':
        reajusteAtual = 'igpm';
        break;
      case 'bienal':
      case 'biennial':
        reajusteAtual = 'igpm'; // Por enquanto só igpm e nenhum
        break;
      case 'none':
      case 'sem':
      case 'sem reajuste':
        reajusteAtual = 'nenhum';
        break;
    }
    
    return valoresValidos.contains(reajusteAtual) ? reajusteAtual : 'igpm';
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
