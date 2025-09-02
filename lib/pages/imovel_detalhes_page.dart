import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../utils/format.dart';

class ImovelDetalhesPage extends StatefulWidget {
  const ImovelDetalhesPage({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  State<ImovelDetalhesPage> createState() => _ImovelDetalhesPageState();
}

class _ImovelDetalhesPageState extends State<ImovelDetalhesPage> {
  final _svc = SupabaseService();
  late Map<String, dynamic> _item;
  final Set<dynamic> _uploadingFotos = {};
  final Set<dynamic> _uploadingPlantas = {};
  final Set<dynamic> _uploadingManutencao = {};
  int _coverIndex = 0;

  @override
  void initState() {
    super.initState();
    _item = Map<String, dynamic>.from(widget.item);
    _reloadFromDb();
  }

  dynamic _rowId(Map<String, dynamic> e) {
    if (e.containsKey('imovel_id')) return e['imovel_id'];
    if (e.containsKey('id')) return e['id'];
    if (e.containsKey('ID')) return e['ID'];
    return null;
  }

  String _idColumnFor(Map<String, dynamic> e) {
    if (e.containsKey('imovel_id')) return 'imovel_id';
    if (e.containsKey('id')) return 'id';
    if (e.containsKey('ID')) return 'ID';
    return 'imovel_id';
  }

  /// Retorna a URL base correta dependendo do ambiente
  String _getBaseUrl() {
    // Se estiver rodando em localhost, use a URL de produção configurada
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      // URL de produção no Vercel
      return 'https://andre-ten.vercel.app';
    }
    // Caso contrário, use a URL atual
    return Uri.base.origin;
  }

  /// Normaliza tipos de imóveis para garantir compatibilidade com o dropdown
  String _normalizarTipo(String? tipo) {
    const tiposValidos = [
      'Apartamento', 'Casa', 'Casa de Condomínio', 'Kitnet', 'Loft', 'Studio', 
      'Sobrado', 'Cobertura', 'Comercial', 'Sala Comercial', 'Loja', 'Galpão', 'Terreno', 'Outro'
    ];
    
    String tipoAtual = tipo ?? 'Apartamento';
    
    // Mapeamento para tipos antigos/diferentes
    switch (tipoAtual.toLowerCase()) {
      case 'comercial':
        tipoAtual = 'Comercial';
        break;
      case 'residencial':
        tipoAtual = 'Apartamento';
        break;
      case 'casa':
        tipoAtual = 'Casa';
        break;
    }
    
    return tiposValidos.contains(tipoAtual) ? tipoAtual : 'Apartamento';
  }

  Future<void> _reloadFromDb() async {
    final rid = _rowId(_item);
    if (rid == null) return;
    try {
      final data = await Supabase.instance.client
          .from('imoveis')
          .select()
          .eq(_idColumnFor(_item), rid)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _item = Map<String, dynamic>.from(data);
          final fotos = (_item['fotos_divulgacao'] as List?)?.map((e) => e.toString()).toList() ?? [];
          if (_coverIndex >= fotos.length) {
            _coverIndex = fotos.isEmpty ? 0 : fotos.length - 1;
          }
        });
      }
    } catch (_) {}
  }

  String _imageContentType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }


  Future<void> _uploadFotos(dynamic id, {required String idColumn}) async {
    try {
      if (id == null) return;
      setState(() => _uploadingFotos.add(id));
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (res == null) return;
      final urls = <String>[];
      int i = 0;
      for (final f in res.files) {
        i++;
        try {
          final bytes = f.bytes;
          if (bytes == null) continue;
          final rawExt = (f.extension ?? '').toLowerCase();
          final ext = (rawExt.isEmpty) ? 'jpg' : rawExt;
          final ct = _imageContentType(ext);
          final safeName = (f.name.isEmpty) ? 'arquivo_$i.$ext' : f.name;
          final path = 'imoveis/$id/fotos/${DateTime.now().millisecondsSinceEpoch}_$safeName';
          final url = await _svc.uploadBytes(
            bucket: 'galeria',
            path: path,
            bytes: bytes,
            contentType: ct,
          );
          urls.add(url);
        } catch (_) {}
      }
      if (urls.isNotEmpty) {
        await _svc.appendToArrayColumn(
          table: 'imoveis',
          id: id,
          column: 'fotos_divulgacao',
          valuesToAppend: urls,
          idColumn: idColumn,
        );
        await _reloadFromDb();
      }
    } finally {
      if (mounted) setState(() => _uploadingFotos.remove(id));
    }
  }

  Future<void> _uploadPlanta(dynamic id, {required String idColumn}) async {
    try {
      if (id == null) return;
      setState(() => _uploadingPlantas.add(id));
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (res == null) return;
      final urls = <String>[];
      for (final f in res.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        final ext = (f.extension ?? 'pdf').toLowerCase();
        final path = 'plantas/imoveis/$id/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
        final url = await _svc.uploadBytes(
          bucket: 'galeria',
          path: path,
          bytes: bytes,
          contentType: ext == 'pdf' ? 'application/pdf' : _imageContentType(ext),
        );
        urls.add(url);
      }
      if (urls.isNotEmpty) {
        await _svc.appendToArrayColumn(
          table: 'imoveis',
          id: id,
          column: 'plantas',
          valuesToAppend: urls,
          idColumn: idColumn,
        );
        await _reloadFromDb();
      }
    } finally {
      if (mounted) setState(() => _uploadingPlantas.remove(id));
    }
  }

  Future<void> _uploadManutencao(dynamic id, {required String idColumn}) async {
    try {
      if (id == null) return;
      setState(() => _uploadingManutencao.add(id));
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (res == null) return;
      final urls = <String>[];
      int i = 0;
      for (final f in res.files) {
        i++;
        try {
          final bytes = f.bytes;
          if (bytes == null) continue;
          final rawExt = (f.extension ?? '').toLowerCase();
          final ext = (rawExt.isEmpty) ? 'jpg' : rawExt;
          final ct = _imageContentType(ext);
          final safeName = (f.name.isEmpty) ? 'arquivo_$i.$ext' : f.name;
          final path = 'imoveis/$id/manutencao/${DateTime.now().millisecondsSinceEpoch}_$safeName';
          final url = await _svc.uploadBytes(
            bucket: 'galeria',
            path: path,
            bytes: bytes,
            contentType: ct,
          );
          urls.add(url);
        } catch (_) {}
      }
      if (urls.isNotEmpty) {
        await _svc.appendToArrayColumn(
          table: 'imoveis',
          id: id,
          column: 'fotos_manutencao',
          valuesToAppend: urls,
          idColumn: idColumn,
        );
        await _reloadFromDb();
      }
    } finally {
      if (mounted) setState(() => _uploadingManutencao.remove(id));
    }
  }

  Future<void> _openGaleria(List<String> fotos, {dynamic imovelId, String idColumn = 'id', required String column}) async {
    if (fotos.isEmpty) return;
    int index = 0;
    final items = List<String>.from(fotos);
    final controller = PageController(initialPage: index);
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 900,
                height: 600,
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: controller,
                            onPageChanged: (i) => setSt(() => index = i),
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              return InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 5,
                                child: Image.network(
                                  items[i],
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                                ),
                              );
                            },
                          ),
                          if (imovelId != null && items.isNotEmpty)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: IconButton(
                                tooltip: 'Excluir',
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final current = items[index];
                                  final ok = await _confirmAndDeleteMedia(
                                    imovelId: imovelId,
                                    idColumn: idColumn,
                                    column: column,
                                    url: current,
                                  );
                                  if (ok) {
                                    setSt(() {
                                      items.removeAt(index);
                                      if (index >= items.length) index = items.isEmpty ? 0 : items.length - 1;
                                    });
                                    if (items.isEmpty) Navigator.pop(ctx);
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Imagem ${items.isEmpty ? 0 : index + 1} de ${items.length}'),
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmAndDeleteMedia({
    required dynamic imovelId,
    required String idColumn,
    required String column,
    required String url,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover arquivo?'),
        content: const Text('Esta ação é irreversível.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      await _svc.deleteStorageObjectByPublicUrl(bucket: 'galeria', publicUrl: url);
      final current = List<String>.from((_item[column] as List?)?.map((e) => e.toString()) ?? []);
      current.removeWhere((e) => e == url);
      await Supabase.instance.client.from('imoveis').update({column: current}).eq(idColumn, imovelId);
      await _reloadFromDb();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arquivo excluído')));
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao excluir: $e')));
      }
      return false;
    }
  }

  Future<void> _openShareDialog() async {
    final rid = _rowId(_item);
    if (rid == null) return;
    // Reutiliza a mesma implementação de ImoveisPage de forma simplificada: apenas criar um link padrão
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Compartilhar imóvel'),
        content: const Text('Gerar link público de compartilhamento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gerar')),
        ],
      ),
    );
    if (ok == true) {
      try {
        final exp = DateTime.now().add(const Duration(days: 14)).millisecondsSinceEpoch;
        final token = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
        final uri = Uri(
          fragment: '/share',
          queryParameters: {
            'i': rid.toString(),
            't': token,
            'exp': exp.toString(),
          },
        );
        final baseUrl = _getBaseUrl();
        final link = '$baseUrl/#${uri.fragment}?${uri.query}';
        await _svc.addShareLink(imovelId: rid, shareLink: link);
        if (!mounted) return;
        await Clipboard.setData(ClipboardData(text: link));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link gerado e copiado')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao gerar link: $e')));
      }
    }
  }

  Future<void> _openEditForm() async {
    // Carregar dados atuais do imóvel
    final item = _item;
    final nomeCtrl = TextEditingController(text: item['nome']?.toString() ?? '');
    String tipoSelecionado = _normalizarTipo(item['tipo']?.toString());
    final endCtrl = TextEditingController(text: item['endereco']?.toString() ?? '');
    final aluguelCtrl = TextEditingController(text: item['valor_aluguel']?.toString() ?? '');
    final condCtrl = TextEditingController(text: item['condominio']?.toString() ?? '');
    final iptuCtrl = TextEditingController(text: item['iptu']?.toString() ?? '');
    final iptuNumCtrl = TextEditingController(text: item['numero_iptu']?.toString() ?? '');
    final ucEnergiaCtrl = TextEditingController(text: item['uc_energia']?.toString() ?? '');
    final ucAguaCtrl = TextEditingController(text: item['uc_agua']?.toString() ?? '');
    final internetCtrl = TextEditingController(text: item['internet']?.toString() ?? '');
    final areaCtrl = TextEditingController(text: item['area']?.toString() ?? '');
    final descCtrl = TextEditingController(text: item['descricao']?.toString() ?? '');
    final obsCtrl = TextEditingController(text: item['observacoes']?.toString() ?? '');
    final senhaAlarmeCtrl = TextEditingController(text: item['senha_alarme']?.toString() ?? '');
    final senhaInternetCtrl = TextEditingController(text: item['senha_internet']?.toString() ?? '');
    bool mobiliado = item['mobiliado'] == true;
    bool pets = item['pets'] == true;
    String status = item['status']?.toString() ?? 'disponivel';

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar imóvel'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: tipoSelecionado,
                  decoration: const InputDecoration(labelText: 'Tipo*'),
                  items: const [
                    DropdownMenuItem(value: 'Apartamento', child: Text('Apartamento')),
                    DropdownMenuItem(value: 'Casa', child: Text('Casa')),
                    DropdownMenuItem(value: 'Casa de Condomínio', child: Text('Casa de Condomínio')),
                    DropdownMenuItem(value: 'Kitnet', child: Text('Kitnet')),
                    DropdownMenuItem(value: 'Loft', child: Text('Loft')),
                    DropdownMenuItem(value: 'Studio', child: Text('Studio')),
                    DropdownMenuItem(value: 'Sobrado', child: Text('Sobrado')),
                    DropdownMenuItem(value: 'Cobertura', child: Text('Cobertura')),
                    DropdownMenuItem(value: 'Comercial', child: Text('Comercial')),
                    DropdownMenuItem(value: 'Sala Comercial', child: Text('Sala Comercial')),
                    DropdownMenuItem(value: 'Loja', child: Text('Loja')),
                    DropdownMenuItem(value: 'Galpão', child: Text('Galpão')),
                    DropdownMenuItem(value: 'Terreno', child: Text('Terreno')),
                    DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                  ],
                  onChanged: (v) => tipoSelecionado = v ?? 'Apartamento',
                  isExpanded: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: endCtrl,
                  decoration: const InputDecoration(labelText: 'Endereço*'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: aluguelCtrl,
                  decoration: const InputDecoration(labelText: 'Valor aluguel*'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: condCtrl,
                  decoration: const InputDecoration(labelText: 'Condomínio'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: iptuCtrl,
                  decoration: const InputDecoration(labelText: 'IPTU'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: iptuNumCtrl,
                  decoration: const InputDecoration(labelText: 'Número do IPTU'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ucEnergiaCtrl,
                  decoration: const InputDecoration(labelText: 'UC Energia'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ucAguaCtrl,
                  decoration: const InputDecoration(labelText: 'UC Água'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: internetCtrl,
                  decoration: const InputDecoration(labelText: 'Internet (mensal)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: areaCtrl,
                  decoration: const InputDecoration(labelText: 'Área (m²)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: obsCtrl,
                  decoration: const InputDecoration(labelText: 'Observações'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: senhaAlarmeCtrl,
                  decoration: const InputDecoration(labelText: 'Senha do alarme'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: senhaInternetCtrl,
                  decoration: const InputDecoration(labelText: 'Senha da internet'),
                ),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (context, setState) => Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('Mobiliado'),
                        value: mobiliado,
                        onChanged: (v) => setState(() => mobiliado = v ?? false),
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Aceita pets'),
                        value: pets,
                        onChanged: (v) => setState(() => pets = v ?? false),
                        contentPadding: EdgeInsets.zero,
                      ),
                      DropdownButtonFormField<String>(
                        value: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'disponivel', child: Text('Disponível')),
                          DropdownMenuItem(value: 'ocupado', child: Text('Ocupado')),
                          DropdownMenuItem(value: 'manutencao', child: Text('Manutenção')),
                          DropdownMenuItem(value: 'inativo', child: Text('Inativo')),
                        ],
                        onChanged: (v) => setState(() => status = v ?? 'disponivel'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tipoSelecionado.trim().isEmpty || endCtrl.text.trim().isEmpty || aluguelCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Preencha os campos obrigatórios')),
                );
                return;
              }

              double? toNum(String s) => s.trim().isEmpty ? null : double.tryParse(s.replaceAll(',', '.'));
              
              final payload = {
                'nome': nomeCtrl.text.trim().isEmpty ? null : nomeCtrl.text.trim(),
                'tipo': tipoSelecionado.trim(),
                'endereco': endCtrl.text.trim(),
                'valor_aluguel': double.tryParse(aluguelCtrl.text.trim()) ?? 0,
                'condominio': toNum(condCtrl.text),
                'iptu': toNum(iptuCtrl.text),
                'numero_iptu': iptuNumCtrl.text.trim().isEmpty ? null : iptuNumCtrl.text.trim(),
                'uc_energia': ucEnergiaCtrl.text.trim().isEmpty ? null : ucEnergiaCtrl.text.trim(),
                'uc_agua': ucAguaCtrl.text.trim().isEmpty ? null : ucAguaCtrl.text.trim(),
                'internet': toNum(internetCtrl.text),
                'area': toNum(areaCtrl.text),
                'descricao': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                'observacoes': obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
                'senha_alarme': senhaAlarmeCtrl.text.trim().isEmpty ? null : senhaAlarmeCtrl.text.trim(),
                'senha_internet': senhaInternetCtrl.text.trim().isEmpty ? null : senhaInternetCtrl.text.trim(),
                'mobiliado': mobiliado,
                'pets': pets,
                'status': status,
                'updated_at': DateTime.now().toIso8601String(),
              };

              try {
                final rid = _rowId(_item);
                final idCol = _idColumnFor(_item);
                await _svc.updateBy(
                  table: 'imoveis',
                  id: rid,
                  values: payload,
                  idColumn: idCol,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx, true);
              } catch (e) {
                debugPrint('[ImovelDetalhes][ERROR] save: $e');
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Falha ao salvar: $e')),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (res == true) {
      // Recarregar dados do banco
      await _reloadFromDb();
    }
  }

  Future<void> _openDespesaFormForImovel(dynamic imovelId) async {
    final tipo = ValueNotifier<String>('condominio');
    final descCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    DateTime? data;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova despesa para este imóvel'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: tipo,
                builder: (_, value, __) => DropdownButtonFormField<String>(
                  value: value,
                  items: const [
                    DropdownMenuItem(value: 'condominio', child: Text('Condomínio')),
                    DropdownMenuItem(value: 'iptu', child: Text('IPTU')),
                    DropdownMenuItem(value: 'manutencao', child: Text('Manutenção')),
                  ],
                  onChanged: (v) => tipo.value = v ?? 'condominio',
                  decoration: const InputDecoration(labelText: 'Tipo de despesa*'),
                ),
              ),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descrição')),
              TextField(controller: valorCtrl, decoration: const InputDecoration(labelText: 'Valor*')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data == null ? 'Data: —' : 'Data: ${data!.toIso8601String().split('T').first}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime(now.year - 5),
                        lastDate: DateTime(now.year + 5),
                        initialDate: now,
                      );
                      if (picked != null) {
                        data = picked;
                        (ctx as Element).markNeedsBuild();
                      }
                    },
                    child: const Text('Escolher data'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final valor = double.tryParse(valorCtrl.text.replaceAll(',', '.'));
              if (valor == null) return;
              final payload = {
                'imovel_id': imovelId,
                'tipo_despesa': tipo.value,
                'descricao': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                'valor': valor,
                'data': (data ?? DateTime.now()).toIso8601String(),
                'created_at': DateTime.now().toIso8601String(),
                'user_ref': Supabase.instance.client.auth.currentUser?.id,
              };
              try {
                await _svc.insert('despesas', payload);
                if (!mounted) return;
                Navigator.pop(ctx, true);
              } catch (_) {}
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (res == true) {
      // no-op
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotos = (_item['fotos_divulgacao'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final plantas = (_item['plantas'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final manutencao = (_item['fotos_manutencao'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final rid = _rowId(_item);
    final idCol = _idColumnFor(_item);
    final cover = fotos.isNotEmpty ? fotos[_coverIndex.clamp(0, fotos.length - 1)] : null;
    return Scaffold(
      appBar: AppBar(title: Text(_item['nome']?.toString() ?? 'Imóvel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cover != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      cover,
                      height: 270,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(height: 270, child: Center(child: Icon(Icons.image_not_supported))),
                    ),
                  ),
                if (fotos.length > 1) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 78,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: fotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final thumb = fotos[i];
                        final selected = i == _coverIndex;
                        return InkWell(
                          onTap: () => setState(() => _coverIndex = i),
                          onLongPress: () => _openGaleria(fotos, imovelId: rid, idColumn: idCol, column: 'fotos_divulgacao'),
                          child: Container(
                            width: 78,
                            decoration: BoxDecoration(
                              border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300, width: selected ? 2 : 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                thumb,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 20)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(_item['nome']?.toString() ?? '', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(_item['descricao']?.toString() ?? ''),
                const SizedBox(height: 8),
                Text(_item['endereco']?.toString() ?? ''),
                const SizedBox(height: 8),
                Text(formatBrl(_item['valor_aluguel']), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: rid == null || _uploadingFotos.contains(rid) ? null : () => _uploadFotos(rid, idColumn: idCol),
                      icon: _uploadingFotos.contains(rid)
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.photo_camera),
                      label: const Text('Enviar fotos'),
                    ),
                    OutlinedButton.icon(
                      onPressed: rid == null || _uploadingPlantas.contains(rid) ? null : () => _uploadPlanta(rid, idColumn: idCol),
                      icon: _uploadingPlantas.contains(rid)
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.picture_as_pdf),
                      label: const Text('Enviar planta'),
                    ),
                    OutlinedButton.icon(
                      onPressed: rid == null || _uploadingManutencao.contains(rid) ? null : () => _uploadManutencao(rid, idColumn: idCol),
                      icon: _uploadingManutencao.contains(rid)
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.build_circle_outlined),
                      label: const Text('Enviar manutenção'),
                    ),
                    TextButton.icon(
                      onPressed: fotos.isEmpty ? null : () => _openGaleria(fotos, imovelId: rid, idColumn: idCol, column: 'fotos_divulgacao'),
                      icon: const Icon(Icons.slideshow),
                      label: const Text('Ver fotos'),
                    ),
                    TextButton.icon(
                      onPressed: () => _openPlantasDialog(plantas, imovelId: rid, idColumn: idCol),
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Ver plantas'),
                    ),
                    TextButton.icon(
                      onPressed: manutencao.isEmpty ? null : () => _openGaleria(manutencao, imovelId: rid, idColumn: idCol, column: 'fotos_manutencao'),
                      icon: const Icon(Icons.build_outlined),
                      label: const Text('Ver manutenção'),
                    ),
                    TextButton.icon(
                      onPressed: _openShareDialog,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartilhar'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openEditForm(),
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar imóvel'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Excluir imóvel?'),
                            content: const Text('Esta ação é irreversível.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
                            ],
                          ),
                        );
                        if (ok == true && rid != null) {
                          try {
                            await _svc.softDeleteById('imoveis', rid, idColumn: idCol);
                            if (mounted) Navigator.pop(context, true);
                          } catch (_) {}
                        }
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Excluir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isPdf(String url) => url.toLowerCase().endsWith('.pdf');

  Future<void> _openPlantasDialog(List<String> plantas, {dynamic imovelId, String idColumn = 'id'}) async {
    if (plantas.isEmpty) return;
    final items = List<String>.from(plantas);
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: const Text('Plantas'),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: items.map((p) {
                      final isPdf = _isPdf(p);
                      return Stack(
                        children: [
                          InkWell(
                            onTap: () async {
                              if (isPdf) {
                                final uri = Uri.parse(p);
                                await launchUrl(uri, webOnlyWindowName: '_blank');
                              } else {
                                await _openGaleria(
                                  [p, ...items.where((x) => !_isPdf(x))],
                                  imovelId: imovelId,
                                  idColumn: idColumn,
                                  column: 'plantas',
                                );
                              }
                            },
                            child: Container(
                              width: 200,
                              height: 140,
                              color: Colors.grey.shade200,
                              child: Center(
                                child: isPdf
                                    ? const Icon(Icons.picture_as_pdf, size: 48, color: Colors.red)
                                    : Image.network(p, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                              ),
                            ),
                          ),
                          if (imovelId != null)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: IconButton(
                                tooltip: 'Excluir',
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final ok = await _confirmAndDeleteMedia(
                                    imovelId: imovelId,
                                    idColumn: idColumn,
                                    column: 'plantas',
                                    url: p,
                                  );
                                  if (ok) {
                                    setSt(() => items.remove(p));
                                  }
                                },
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
              ],
            );
          },
        );
      },
    );
  }
}


