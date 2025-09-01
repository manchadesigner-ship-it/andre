import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final _svc = SupabaseService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    debugPrint('[Clientes] initState');
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    return _svc.list('clientes', limit: 200);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    final nomeCtrl = TextEditingController(text: item?['nome'] ?? '');
    final cpfCtrl = TextEditingController(text: item?['cpf_cnpj'] ?? '');
    final telCtrl = TextEditingController(text: item?['telefone'] ?? '');
    final emailCtrl = TextEditingController(text: item?['email'] ?? '');
    final endCtrl = TextEditingController(text: item?['endereco'] ?? '');
    final isEdit = item != null;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Editar cliente' : 'Novo cliente'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cpfCtrl,
                decoration: const InputDecoration(labelText: 'CPF/CNPJ'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telCtrl,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(labelText: 'Endereço'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final data = {
                  'nome': nomeCtrl.text.trim(),
                  'cpf_cnpj': cpfCtrl.text.trim(),
                  'telefone': telCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'endereco': endCtrl.text.trim(),
                };
                if (isEdit) {
                  await _svc.updateById('clientes', item['id'], data);
                } else {
                  await _svc.insert('clientes', data);
                }
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(true);
              } catch (e) {
                debugPrint('[Clientes][ERROR] save: $e');
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
      await _svc.deleteById('clientes', id);
      _refresh();
    } catch (e) {
      debugPrint('[Clientes][ERROR] delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Clientes] build');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Clientes', style: Theme.of(context).textTheme.titleLarge),
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
                if (data.isEmpty) {
                  return const Center(child: Text('Nenhum cliente'));
                }
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
                              DataColumn(label: Text('Nome')),
                              DataColumn(label: Text('CPF/CNPJ')),
                              DataColumn(label: Text('Telefone')),
                              DataColumn(label: Text('E-mail')),
                              DataColumn(label: Text('Ações')),
                            ],
                            rows: data.map((e) {
                              return DataRow(cells: [
                                DataCell(Text('${e['id']}')),
                                DataCell(Text(e['nome'] ?? '')),
                                DataCell(Text(e['cpf_cnpj'] ?? '')),
                                DataCell(Text(e['telefone'] ?? '')),
                                DataCell(Text(e['email'] ?? '')),
                                DataCell(Row(
                                  children: [
                                    IconButton(onPressed: () => _openForm(item: e), icon: const Icon(Icons.edit)),
                                    IconButton(onPressed: () => _delete(e['id']), icon: const Icon(Icons.delete), color: Colors.red),
                                  ],
                                )),
                              ]);
                            }).toList(),
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
