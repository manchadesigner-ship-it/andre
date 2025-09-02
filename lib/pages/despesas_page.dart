import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../services/supabase_service.dart';

class DespesasPage extends StatefulWidget {
  const DespesasPage({super.key});

  @override
  State<DespesasPage> createState() => _DespesasPageState();
}

class _DespesasPageState extends State<DespesasPage> {
  final _svc = SupabaseService();
  late Future<List<Map<String, dynamic>>> _future;
  final Set<dynamic> _uploading = {};

  @override
  void initState() {
    super.initState();
    debugPrint('[Despesas] initState');
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    return _svc.list('despesas', limit: 200);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    // Carrega opções para dropdowns
    final imoveis = await _svc.list('imoveis', limit: 500);
    final rawImovel = item != null ? item['imovel_id'] : null;
    int? selectedImovelId = rawImovel is int
        ? rawImovel
        : int.tryParse((rawImovel)?.toString() ?? '');
    final valorCtrl = TextEditingController(text: item?['valor']?.toString() ?? '');
    final descCtrl = TextEditingController(text: item?['descricao'] ?? '');
    final dataCtrl = TextEditingController(text: _fmtDate(item?['data']));
    String tipo = item?['tipo_despesa'] ?? 'outro';
    final isEdit = item != null;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Editar despesa' : 'Nova despesa'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedImovelId,
                  decoration: const InputDecoration(labelText: 'Imóvel*'),
                  items: imoveis.map((e) {
                    final raw = e.containsKey('imovel_id') ? e['imovel_id'] : (e['id'] ?? e['ID']);
                    final idVal = raw is int ? raw : int.tryParse((raw)?.toString() ?? '');
                    if (idVal == null) return null;
                    return DropdownMenuItem<int>(
                      value: idVal,
                      child: Text('$idVal - ${e['endereco'] ?? 'Sem endereço'}'),
                    );
                  }).whereType<DropdownMenuItem<int>>().toList(),
                  onChanged: (v) => selectedImovelId = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valorCtrl,
                  decoration: const InputDecoration(labelText: 'Valor*'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descrição*'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dataCtrl,
                  decoration: const InputDecoration(labelText: 'Data*'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'condominio', child: Text('Condomínio')),
                    DropdownMenuItem(value: 'iptu', child: Text('IPTU')),
                    DropdownMenuItem(value: 'manutencao', child: Text('Manutenção')),
                    DropdownMenuItem(value: 'outro', child: Text('Outro')),
                  ],
                  onChanged: (v) => tipo = v ?? 'outro',
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
              if (selectedImovelId == null || valorCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) return;
              if (!ctx.mounted) return;
              String _dateToDb(String s) {
                if (s.isEmpty) {
                  return DateFormat('yyyy-MM-dd').format(DateTime.now());
                }
                try {
                  if (s.contains('/')) {
                    final dt = DateFormat('dd/MM/yyyy').parseStrict(s);
                    return DateFormat('yyyy-MM-dd').format(dt);
                  }
                  final dt = DateTime.tryParse(s);
                  if (dt != null) {
                    return DateFormat('yyyy-MM-dd').format(dt);
                  }
                } catch (_) {}
                return DateFormat('yyyy-MM-dd').format(DateTime.now());
              }
              final payload = {
                'imovel_id': selectedImovelId,
                'valor': double.tryParse(valorCtrl.text.trim()) ?? 0,
                'descricao': descCtrl.text.trim(),
                'data': _dateToDb(dataCtrl.text.trim()),
                'tipo_despesa': tipo,
              };
              try {
                if (isEdit) {
                  await _svc.updateById('despesas', item['id'], payload);
                } else {
                  await _svc.insert('despesas', payload);
                }
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(true);
              } catch (e) {
                debugPrint('[Despesas][ERROR] save: $e');
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
      await _svc.deleteById('despesas', id);
      _refresh();
    } catch (e) {
      debugPrint('[Despesas][ERROR] delete: $e');
    }
  }

  String _fmtDate(dynamic date) {
    if (date == null) return '';
    if (date is String) {
      final dt = DateTime.tryParse(date);
      if (dt != null) {
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
    }
    return date.toString();
  }

  Future<void> _openComprovante(String url) async {
    // Implementar visualização do comprovante
    debugPrint('[Despesas] Abrir comprovante: $url');
  }

  Future<void> _uploadComprovante(dynamic id) async {
    try {
      if (id == null) {
        debugPrint('[Despesas][ERROR] uploadComprovante: id is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro: ID da despesa não encontrado.'),
            ),
          );
        }
        return;
      }

      setState(() => _uploading.add(id));
      
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
        withData: true,
      );
      
      if (res == null) {
        debugPrint('[Despesas] Upload cancelado pelo usuário');
        return;
      }

      final file = res.files.first;
      final bytes = file.bytes;
      
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: Não foi possível ler o arquivo.')),
          );
        }
        return;
      }

      final rawExt = (file.extension ?? '').toLowerCase();
      final ext = rawExt.isEmpty ? 'pdf' : rawExt;
      final contentType = _getContentType(ext);
      final safeName = file.name.isEmpty ? 'comprovante_$id.$ext' : file.name;
      final path = 'despesas/$id/comprovantes/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      debugPrint('[Despesas] Enviando comprovante: $safeName');

      final url = await _svc.uploadBytes(
        bucket: 'galeria',
        path: path,
        bytes: bytes,
        contentType: contentType,
      );

      // Atualizar despesa com URL do comprovante
      await _svc.updateById('despesas', id, {
        'comprovante_url': url,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comprovante enviado com sucesso!')),
        );
      }

    } catch (e) {
      debugPrint('[Despesas][ERROR] uploadComprovante: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao enviar comprovante: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(id));
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Despesas] build');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Despesas', style: Theme.of(context).textTheme.titleLarge),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Nova'),
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
                  return const Center(child: Text('Nenhuma despesa'));
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
                              DataColumn(label: Text('Imóvel')),
                              DataColumn(label: Text('Tipo')),
                              DataColumn(label: Text('Descrição')),
                              DataColumn(label: Text('Valor')),
                              DataColumn(label: Text('Data')),
                              DataColumn(label: Text('Comprovante')),
                              DataColumn(label: Text('Ações')),
                            ],
                            rows: data.map((e) => DataRow(cells: [
                              DataCell(Text('${e['id']}')),
                              DataCell(Text('${e['imovel_id'] ?? ''}')),
                              DataCell(Text('${e['tipo_despesa'] ?? ''}')),
                              DataCell(Text(e['descricao'] ?? '')),
                              DataCell(Text('${e['valor'] ?? ''}')),
                              DataCell(Text(_fmtDate(e['data']))),
                              DataCell(Row(children: [
                                if (e['comprovante_url'] != null)
                                  TextButton.icon(
                                    onPressed: () => _openComprovante(e['comprovante_url']),
                                    icon: const Icon(Icons.visibility),
                                    label: const Text('Ver'),
                                  )
                                else
                                  const Text('-')
                              ])),
                              DataCell(Row(children: [
                                IconButton(onPressed: () => _openForm(item: e), icon: const Icon(Icons.edit)),
                                Builder(builder: (ctx){
                                  final uploading = _uploading.contains(e['id']);
                                  return IconButton(
                                    onPressed: uploading ? null : () => _uploadComprovante(e['id']),
                                    icon: uploading
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.attach_file),
                                    tooltip: 'Enviar comprovante',
                                  );
                                }),
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
