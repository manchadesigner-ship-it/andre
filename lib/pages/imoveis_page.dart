import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/format.dart';

class ImoveisPage extends StatefulWidget {
  const ImoveisPage({super.key});

  @override
  State<ImoveisPage> createState() => _ImoveisPageState();
}

class _ImoveisPageState extends State<ImoveisPage> {
  final _svc = SupabaseService();
  late Future<List<Map<String, dynamic>>> _future;
  final Set<dynamic> _uploadingFotos = {};
  final Set<dynamic> _uploadingPlantas = {};
  final Set<dynamic> _uploadingManutencao = {};

  @override
  void initState() {
    super.initState();
    debugPrint('[Imóveis] initState');
    _future = _load();
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
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

  Future<void> _openShareDialog(Map<String, dynamic> e) async {
    final rid = _rowId(e);
    if (rid == null) return;
    // Options
    final incFotos = ValueNotifier<bool>(true);
    final incNome = ValueNotifier<bool>(true);
    final incTipo = ValueNotifier<bool>(true);
    final incDescricao = ValueNotifier<bool>(true);
    final incEndereco = ValueNotifier<bool>(true);
    final incValor = ValueNotifier<bool>(true);
    final incArea = ValueNotifier<bool>(true);
    final incMobiliado = ValueNotifier<bool>(true);
    final incPets = ValueNotifier<bool>(true);
    final saveLink = ValueNotifier<bool>(true);
    
    // Carregar links de compartilhamento existentes
    List<String> existingLinks = [];
    try {
      existingLinks = await _svc.getShareLinks(imovelId: rid);
      debugPrint('[Imoveis] Links de compartilhamento existentes: $existingLinks');
    } catch (e) {
      debugPrint('[Imoveis][ERROR] Erro ao carregar links de compartilhamento: $e');
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Compartilhar imóvel'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existingLinks.isNotEmpty) ...[  
                  const Text('Links compartilhados anteriormente:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    height: 100,
                    child: ListView.builder(
                      itemCount: existingLinks.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          dense: true,
                          title: Text(
                            existingLinks[index],
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: existingLinks[index]));
                                  if (!ctx.mounted) return;
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Link copiado para a área de transferência')),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () async {
                                  try {
                                    await _svc.removeShareLink(
                                      imovelId: rid,
                                      shareLink: existingLinks[index],
                                    );
                                    existingLinks.removeAt(index);
                                    if (!ctx.mounted) return;
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Link removido com sucesso')),
                                    );
                                    Navigator.of(ctx).pop();
                                    _openShareDialog(e); // Reabrir diálogo atualizado
                                  } catch (e) {
                                    debugPrint('[Imoveis][ERROR] Erro ao remover link: $e');
                                    if (!ctx.mounted) return;
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Erro ao remover link: $e')),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                ],
                const Text('Criar novo link de compartilhamento:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: incFotos,
                  builder: (_, v, __) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir fotos de divulgação'),
                    value: v,
                    onChanged: (nv) => incFotos.value = nv ?? true,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: incNome,
                  builder: (_, v, __) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir nome'),
                    value: v,
                    onChanged: (nv) => incNome.value = nv ?? true,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: incTipo,
                  builder: (_, v, __) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir tipo'),
                    value: v,
                    onChanged: (nv) => incTipo.value = nv ?? true,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: incDescricao,
                  builder: (_, v, __) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir descrição'),
                    value: v,
                    onChanged: (nv) => incDescricao.value = nv ?? true,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: incEndereco,
                  builder: (_, v, __) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir endereço'),
                    value: v,
                    onChanged: (nv) => incEndereco.value = nv ?? true,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: incValor,
                  builder: (_, v, __) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir valor do aluguel'),
                    value: v,
                    onChanged: (nv) => incValor.value = nv ?? true,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: incArea,
                  builder: (_, v, __) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir área'),
                    value: v,
                    onChanged: (nv) => incArea.value = nv ?? true,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: incMobiliado,
                  builder: (_, v, __) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir informação de mobiliado'),
                    value: v,
                    onChanged: (nv) => incMobiliado.value = nv ?? true,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: incPets,
                  builder: (_, v, __) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir informação de pets'),
                    value: v,
                    onChanged: (nv) => incPets.value = nv ?? true,
                  ),
                ),
                const Divider(),
                ValueListenableBuilder<bool>(
                  valueListenable: saveLink,
                  builder: (_, v, __) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Salvar link para compartilhamentos futuros'),
                    value: v,
                    onChanged: (nv) => saveLink.value = nv ?? true,
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gerar link'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final fotos = (e['fotos_divulgacao'] as List?)?.map((x) => x.toString()).toList() ?? [];
    final buf = StringBuffer();
    
    // HTML seguindo design do visual.md - clean, minimalista com verde lima #A4D65E
    buf.writeln('''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${_escapeHtml((e['tipo'] ?? 'Imóvel').toString())} - ${_escapeHtml((e['endereco'] ?? '').toString())}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #A4D65E 0%, #8BC34A 100%);
            min-height: 100vh;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: linear-gradient(135deg, #A4D65E 0%, #8BC34A 100%);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            text-align: center;
        }
        
        .header h1 {
            color: white;
            font-size: 2.5rem;
            margin-bottom: 10px;
            font-weight: 700;
        }
        
        .header .subtitle {
            color: rgba(255,255,255,0.9);
            font-size: 1.2rem;
            margin-bottom: 20px;
        }
        
        .price {
            background: rgba(255,255,255,0.95);
            color: #A4D65E;
            padding: 15px 30px;
            border-radius: 50px;
            font-size: 1.5rem;
            font-weight: bold;
            display: inline-block;
            margin: 20px 0;
        }
        
        .main-content {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 30px;
            margin-bottom: 30px;
        }
        
        .info-card {
            background: white;
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        
        .info-card h2 {
            color: #2c3e50;
            margin-bottom: 20px;
            font-size: 1.5rem;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        
        .info-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px 0;
            border-bottom: 1px solid #ecf0f1;
        }
        
        .info-item:last-child {
            border-bottom: none;
        }
        
        .info-label {
            font-weight: 600;
            color: #34495e;
        }
        
        .info-value {
            color: #2c3e50;
            font-weight: 500;
        }
        
        .gallery {
            background: white;
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            margin-bottom: 30px;
        }
        
        .gallery h2 {
            color: #2c3e50;
            margin-bottom: 20px;
            font-size: 1.5rem;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        
        .photo-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        
        .photo-item {
            position: relative;
            border-radius: 15px;
            overflow: hidden;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }
        
        .photo-item:hover {
            transform: translateY(-5px);
        }
        
        .photo-item img {
            width: 100%;
            height: 250px;
            object-fit: cover;
            display: block;
        }
        
        .contact-section {
            background: white;
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            text-align: center;
        }
        
        .contact-section h2 {
            color: #2c3e50;
            margin-bottom: 20px;
            font-size: 1.5rem;
        }
        
        .contact-info {
            background: linear-gradient(45deg, #3498db, #2980b9);
            color: white;
            padding: 20px;
            border-radius: 15px;
            margin: 20px 0;
        }
        
        .footer {
            text-align: center;
            color: white;
            margin-top: 30px;
            padding: 20px;
        }
        
        .badge {
            background: #27ae60;
            color: white;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9rem;
            font-weight: 600;
        }
        
        .badge.disponivel {
            background: #27ae60;
        }
        
        .badge.alugado {
            background: #e74c3c;
        }
        
        @media (max-width: 768px) {
            .main-content {
                grid-template-columns: 1fr;
            }
            
            .header h1 {
                font-size: 2rem;
            }
            
            .photo-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>${_escapeHtml((e['tipo'] ?? 'Imóvel').toString())}</h1>
            <div class="subtitle">${_escapeHtml((e['endereco'] ?? '').toString())}</div>
            <div class="price">${_escapeHtml(formatBrl(e['valor_aluguel']))}/mês</div>
            <span class="badge ${_escapeHtml((e['status'] ?? 'disponivel').toString())}">${_escapeHtml((e['status'] ?? 'disponivel').toString().toUpperCase())}</span>
        </div>
        
        <div class="main-content">
            <div class="info-card">
                <h2>📋 Informações do Imóvel</h2>
                ${incTipo.value ? '<div class="info-item"><span class="info-label">Tipo:</span><span class="info-value">${_escapeHtml((e['tipo'] ?? '').toString())}</span></div>' : ''}
                ${incEndereco.value ? '<div class="info-item"><span class="info-label">📍 Endereço:</span><span class="info-value">${_escapeHtml((e['endereco'] ?? '').toString())}</span></div>' : ''}
                ${incValor.value ? '<div class="info-item"><span class="info-label">💰 Aluguel:</span><span class="info-value">' + _escapeHtml(formatBrl(e['valor_aluguel'])) + '</span></div>' : ''}
                ${e['condominio'] != null ? '<div class="info-item"><span class="info-label">🏢 Condomínio:</span><span class="info-value">' + _escapeHtml(formatBrl(e['condominio'])) + '</span></div>' : ''}
                ${e['iptu'] != null ? '<div class="info-item"><span class="info-label">🏛️ IPTU:</span><span class="info-value">' + _escapeHtml(formatBrl(e['iptu'])) + '</span></div>' : ''}
            </div>
            
            <div class="info-card">
                <h2>🏠 Características</h2>
                ${incArea.value && e['area'] != null ? '<div class="info-item"><span class="info-label">📏 Área:</span><span class="info-value">${_escapeHtml(e['area'].toString())} m²</span></div>' : ''}
                ${incMobiliado.value && e['mobiliado'] != null ? '<div class="info-item"><span class="info-label">🪑 Mobiliado:</span><span class="info-value">${e['mobiliado'] == true ? 'Sim' : 'Não'}</span></div>' : ''}
                ${incPets.value && e['pets'] != null ? '<div class="info-item"><span class="info-label">🐕 Aceita Pets:</span><span class="info-value">${e['pets'] == true ? 'Sim' : 'Não'}</span></div>' : ''}
                <div class="info-item"><span class="info-label">📅 Status:</span><span class="info-value">${_escapeHtml((e['status'] ?? 'disponivel').toString().toUpperCase())}</span></div>
            </div>
        </div>
        
        ${incDescricao.value && e['descricao'] != null && e['descricao'].toString().isNotEmpty ? '''
        <div class="info-card">
            <h2>📝 Descrição</h2>
            <p style="font-size: 1.1rem; line-height: 1.8; color: #2c3e50;">${_escapeHtml(e['descricao'].toString())}</p>
        </div>
        ''' : ''}
        
        ${incFotos.value && fotos.isNotEmpty ? '''
        <div class="gallery">
            <h2>📸 Galeria de Fotos</h2>
            <div class="photo-grid">
                ${fotos.map((foto) => '<div class="photo-item"><img src="$foto" alt="Foto do imóvel" loading="lazy"></div>').join('')}
            </div>
        </div>
        ''' : ''}
        
        <div class="contact-section">
            <h2>📞 Interessado no Imóvel?</h2>
            <div class="contact-info">
                <p style="font-size: 1.2rem; margin-bottom: 10px;">Entre em contato conosco para agendar uma visita!</p>
                <p style="font-size: 1rem; opacity: 0.9;">Este imóvel está sendo divulgado pelo nosso sistema de gestão imobiliária.</p>
            </div>
        </div>
    </div>
    
    <div class="footer">
        <p>🏠 Sistema de Gestão Imobiliária</p>
        <p style="opacity: 0.8; margin-top: 5px;">Link gerado em ${DateTime.now().toString().split('.')[0]}</p>
    </div>
</body>
</html>
    ''');

    try {
      debugPrint('[Imoveis] Gerando HTML para compartilhamento...');
      final bytes = utf8.encode(buf.toString());
      debugPrint('[Imoveis] HTML gerado com ${bytes.length} bytes');
      
      // Usa um caminho estável para poder "reenvio/atualização" mantendo a mesma URL
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'shares/imoveis/$rid/${timestamp}_index.html';
      debugPrint('[Imoveis] Fazendo upload para: $path');
      
      // Jeito correto: gerar link para a rota pública do app com token e expiração
      // Use a URL correta baseada no ambiente (produção vs desenvolvimento)
      final origin = _getBaseUrl();
      // Gera token seguro para Web sem usar shifts (que viram 0 em JS bitwise)
      final token = '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${Random().nextInt(0x7fffffff).toRadixString(36)}';
      // exp padrão: 30 dias
      final exp = DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
      // telefone de contato em formato E.164 (Brasil): +55 48 99922-0029 -> 5548999220029
      const contactPhone = '5548999220029';
      final url = '$origin/#/share?i=$rid&t=$token&exp=$exp&p=$contactPhone';
      debugPrint('[Imoveis] Link público gerado: $url');

      // Opcional: criar uma página OG mínima no Storage para previews em redes sociais
      try {
        final String title = _escapeHtml((e['tipo'] ?? 'Imóvel').toString());
        final String desc = _escapeHtml(((e['descricao'] ?? e['endereco']) ?? '').toString());
        final String img = (fotos.isNotEmpty) ? fotos.first : '';
        final og = '''<!doctype html><html lang="pt-BR"><head>
<meta charset="utf-8"/>
<title>$title</title>
<meta property="og:title" content="$title"/>
<meta property="og:description" content="$desc"/>
${img.isNotEmpty ? '<meta property="og:image" content="$img"/>' : ''}
<meta property="og:type" content="website"/>
<meta property="og:url" content="$url"/>
<meta http-equiv="refresh" content="0;url=$url"/>
</head><body>
<p>Redirecionando para <a href="$url">$url</a></p>
</body></html>''';
        final ogPath = 'shares/imoveis/$rid/${DateTime.now().millisecondsSinceEpoch}_og.html';
        await _svc.uploadBytes(
        bucket: 'galeria',
          path: ogPath,
          bytes: Uint8List.fromList(utf8.encode(og)),
        contentType: 'text/html; charset=utf-8',
          cacheControl: 'public, max-age=31536000',
        deleteBeforeUpload: true,
          upsertHeaders: const {
          'content-type': 'text/html; charset=utf-8',
        },
      );
      } catch (e) {
        debugPrint('[Imoveis][WARN] Falha ao criar OG page: $e');
      }
      
      // Salvar link no banco de dados se a opção estiver marcada
      if (saveLink.value) {
        try {
          await _svc.addShareLink(imovelId: rid, shareLink: url);
          debugPrint('[Imoveis] Link de compartilhamento salvo: $url');
        } catch (e) {
          debugPrint('[Imoveis][ERROR] Erro ao salvar link de compartilhamento: $e');
        }
      }
      
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Link copiado: $url'),
              if (saveLink.value)
                const Text('Link salvo para compartilhamentos futuros', 
                  style: TextStyle(fontSize: 12),
                ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      try {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('[Imoveis][ERROR] share: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao gerar link: $e')),
      );
    }
  }

  Future<void> _uploadManutencao(dynamic id, {required String idColumn}) async {
    try {
      if (id == null) {
        debugPrint('[Imoveis][ERROR] uploadManutencao: id is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível enviar: ID do imóvel está vazio. Salve o imóvel e tente novamente.',
              ),
            ),
          );
        }
        return;
      }
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
        } catch (e) {
          debugPrint('[Imoveis][ERROR] Falha ao enviar manutenção #$i (${f.name}): $e');
        }
      }
      if (urls.isNotEmpty) {
        await _svc.appendToArrayColumn(
          table: 'imoveis',
          id: id,
          column: 'fotos_manutencao',
          valuesToAppend: urls,
          idColumn: idColumn,
        );
        _refresh();
      }
    } catch (e) {
      debugPrint('[Imoveis][ERROR] uploadManutencao: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao enviar fotos de manutenção: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingManutencao.remove(id));
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    return _svc.list('imoveis', limit: 200);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    final nomeCtrl = TextEditingController(text: item?['nome'] ?? '');
    
    String tipoSelecionado = _normalizarTipo(item?['tipo']);
    
    final endCtrl = TextEditingController(text: item?['endereco'] ?? '');
    final aluguelCtrl = TextEditingController(
      text: item?['valor_aluguel']?.toString() ?? '',
    );
    final condCtrl = TextEditingController(
      text: item?['condominio']?.toString() ?? '',
    );
    final iptuCtrl = TextEditingController(
      text: item?['iptu']?.toString() ?? '',
    );
    final iptuNumCtrl = TextEditingController(text: item?['numero_iptu'] ?? '');
    final ucEnergiaCtrl = TextEditingController(text: item?['uc_energia'] ?? '');
    final ucAguaCtrl = TextEditingController(text: item?['uc_agua'] ?? '');
    final internetCtrl = TextEditingController(text: item?['internet']?.toString() ?? '');
    final areaCtrl = TextEditingController(
      text: item?['area']?.toString() ?? '',
    );
    final descCtrl = TextEditingController(text: item?['descricao'] ?? '');
    final obsCtrl = TextEditingController(text: item?['observacoes'] ?? '');
    final senhaAlarmeCtrl = TextEditingController(text: item?['senha_alarme'] ?? '');
    final senhaInternetCtrl = TextEditingController(text: item?['senha_internet'] ?? '');
    bool mobiliado = item?['mobiliado'] == true;
    bool pets = item?['pets'] == true;
    String status = _statusFromDb(item?['status'] ?? 'disponivel');
    final itemId = (item == null) ? null : _rowId(item);
    final isEdit = item != null;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Editar imóvel' : 'Novo imóvel'),
        content: SizedBox(
          width: 480,
          child: StatefulBuilder(
            builder: (ctx2, setSt) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
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
                    onChanged: (v) => setSt(() => tipoSelecionado = v ?? 'Apartamento'),
                    isExpanded: true,
                  ),
                  TextField(
                    controller: endCtrl,
                    decoration: const InputDecoration(labelText: 'Endereço*'),
                  ),
                  TextField(
                    controller: aluguelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Valor aluguel*',
                    ),
                  ),
                  TextField(
                    controller: condCtrl,
                    decoration: const InputDecoration(labelText: 'Condomínio'),
                  ),
                  TextField(
                    controller: iptuCtrl,
                    decoration: const InputDecoration(labelText: 'IPTU'),
                  ),
                  TextField(
                    controller: iptuNumCtrl,
                    decoration: const InputDecoration(labelText: 'Número do IPTU'),
                  ),
                  TextField(
                    controller: ucEnergiaCtrl,
                    decoration: const InputDecoration(labelText: 'UC Energia'),
                  ),
                  TextField(
                    controller: ucAguaCtrl,
                    decoration: const InputDecoration(labelText: 'UC Água'),
                  ),
                  TextField(
                    controller: internetCtrl,
                    decoration: const InputDecoration(labelText: 'Internet (mensal)'),
                  ),
                  TextField(
                    controller: areaCtrl,
                    decoration: const InputDecoration(labelText: 'Área (m²)'),
                  ),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                    maxLines: 3,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mobiliado'),
                    value: mobiliado,
                    onChanged: (v) => setSt(() => mobiliado = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aceita pets'),
                    value: pets,
                    onChanged: (v) => setSt(() => pets = v),
                  ),
                  TextField(
                    controller: obsCtrl,
                    decoration: const InputDecoration(labelText: 'Observações'),
                    maxLines: 3,
                  ),
                  TextField(
                    controller: senhaAlarmeCtrl,
                    decoration: const InputDecoration(labelText: 'Senha do alarme'),
                  ),
                  TextField(
                    controller: senhaInternetCtrl,
                    decoration: const InputDecoration(labelText: 'Senha da internet'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const [
                      DropdownMenuItem(
                        value: 'disponivel',
                        child: Text('Disponível'),
                      ),
                      DropdownMenuItem(value: 'alugado', child: Text('alugado')),
                      DropdownMenuItem(
                        value: 'manutencao',
                        child: Text('Manutenção'),
                      ),
                    ],
                    onChanged: (v) => status = v ?? 'disponivel',
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                ],
              ),
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
              if (tipoSelecionado.trim().isEmpty ||
                  endCtrl.text.trim().isEmpty ||
                  aluguelCtrl.text.trim().isEmpty)
                return;
              double? toNum(String s) => s.trim().isEmpty
                  ? null
                  : double.tryParse(s.replaceAll(',', '.'));
              // Normalize status for DB now to avoid UI value leaking
              final dbStatus = _statusToDb(status);
              final payload = {
                'nome': nomeCtrl.text.trim().isEmpty ? null : nomeCtrl.text.trim(),
                'tipo': tipoSelecionado.trim(),
                'endereco': endCtrl.text.trim(),
                'valor_aluguel': toNum(aluguelCtrl.text) ?? 0,
                'condominio': toNum(condCtrl.text),
                'iptu': toNum(iptuCtrl.text),
                'numero_iptu': iptuNumCtrl.text.trim().isEmpty ? null : iptuNumCtrl.text.trim(),
                'uc_energia': ucEnergiaCtrl.text.trim().isEmpty ? null : ucEnergiaCtrl.text.trim(),
                'uc_agua': ucAguaCtrl.text.trim().isEmpty ? null : ucAguaCtrl.text.trim(),
                'internet': toNum(internetCtrl.text),
                'area': toNum(areaCtrl.text),
                'descricao': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                'mobiliado': mobiliado,
                'pets': pets,
                'observacoes': obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
                'senha_alarme': senhaAlarmeCtrl.text.trim().isEmpty ? null : senhaAlarmeCtrl.text.trim(),
                'senha_internet': senhaInternetCtrl.text.trim().isEmpty ? null : senhaInternetCtrl.text.trim(),
                'status': dbStatus,
                'user_ref': Supabase.instance.client.auth.currentUser?.id,
              };
              try {
                if (isEdit) {
                  if (itemId == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Não foi possível salvar: ID do imóvel ausente.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
                  final idCol = _idColumnFor(item);
                  await _svc.updateBy(
                    table: 'imoveis',
                    id: itemId,
                    values: payload,
                    idColumn: idCol,
                  );
                } else {
                  payload['created_at'] = DateTime.now().toIso8601String();
                  await _svc.insert('imoveis', payload);
                }
                if (!mounted) return;
                Navigator.pop(context, true);
              } catch (e) {
                debugPrint('[Imoveis][ERROR] save: $e');
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (res == true) _refresh();
  }

  Future<void> _delete(dynamic id, {required String idColumn}) async {
    if (id == null) {
      debugPrint('[Imoveis][WARN] delete: id is null');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível excluir: ID do imóvel ausente.'),
          ),
        );
      }
      return;
    }
    try {
      await _svc.softDeleteById('imoveis', id, idColumn: idColumn);
      _refresh();
    } catch (e) {
      debugPrint('[Imoveis][ERROR] delete: $e');
    }
  }

  Future<void> _uploadFotos(dynamic id, {required String idColumn}) async {
    try {
      if (id == null) {
        debugPrint('[Imoveis][ERROR] uploadFotos: id is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível enviar: ID do imóvel está vazio. Salve o imóvel e tente novamente.',
              ),
            ),
          );
        }
        return;
      }
      setState(() => _uploadingFotos.add(id));
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (res == null) {
        debugPrint('[Imoveis] uploadFotos cancelado pelo usuário');
        return;
      }
      debugPrint(
        '[Imoveis] uploadFotos: ${res.files.length} arquivo(s) selecionado(s)',
      );
      final urls = <String>[];
      int i = 0;
      for (final f in res.files) {
        i++;
        try {
          final bytes = f.bytes;
          if (bytes == null) {
            debugPrint(
              '[Imoveis][WARN] Arquivo #$i sem bytes (possivelmente muito grande no Web). Pulando. name=${f.name}',
            );
            continue;
          }
          final rawExt = (f.extension ?? '').toLowerCase();
          final ext = (rawExt.isEmpty) ? 'jpg' : rawExt;
          final ct = _imageContentType(ext);
          final safeName = (f.name.isEmpty) ? 'arquivo_$i.$ext' : f.name;
          final path =
              'imoveis/$id/fotos/${DateTime.now().millisecondsSinceEpoch}_$safeName';
          debugPrint(
            '[Imoveis] Enviando foto #$i: name=$safeName, ext=$ext, bytes=${bytes.length}, contentType=$ct, path=$path',
          );
          final url = await _svc.uploadBytes(
            bucket: 'galeria',
            path: path,
            bytes: bytes,
            contentType: ct,
          );
          urls.add(url);
        } catch (e) {
          debugPrint(
            '[Imoveis][ERROR] Falha ao enviar arquivo #$i (${f.name}): $e',
          );
        }
      }
      if (urls.isNotEmpty) {
        await _svc.appendToArrayColumn(
          table: 'imoveis',
          id: id,
          column: 'fotos_divulgacao',
          valuesToAppend: urls,
          idColumn: idColumn,
        );
        _refresh();
      }
    } catch (e) {
      debugPrint('[Imoveis][ERROR] uploadFotos: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao enviar fotos: $e')));
    } finally {
      if (mounted) setState(() => _uploadingFotos.remove(id));
    }
  }

  Future<void> _uploadPlanta(dynamic id, {required String idColumn}) async {
    try {
      if (id == null) {
        debugPrint('[Imoveis][ERROR] uploadPlanta: id is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível enviar: ID do imóvel está vazio. Salve o imóvel e tente novamente.',
              ),
            ),
          );
        }
        return;
      }
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
        final path =
            'plantas/imoveis/$id/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
        final url = await _svc.uploadBytes(
          bucket: 'galeria',
          path: path,
          bytes: bytes,
          contentType: ext == 'pdf'
              ? 'application/pdf'
              : _imageContentType(ext),
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
        _refresh();
      }
    } catch (e) {
      debugPrint('[Imoveis][ERROR] uploadPlanta: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao enviar planta: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPlantas.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Imóveis] build');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Imóveis', style: Theme.of(context).textTheme.titleLarge),
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
                if (data.isEmpty)
                  return const Center(child: Text('Nenhum imóvel'));
                return LayoutBuilder(
                  builder: (context, constraints) {
                    int cross = 3;
                    final w = constraints.maxWidth;
                    if (w < 650) {
                      cross = 1;
                    } else if (w < 1000) {
                      cross = 2;
                    } else if (w > 1500) {
                      cross = 4;
                    }
                    // Provide a bit more height when there are fewer columns
                    double aspect;
                    if (cross == 1) {
                      aspect = 1.02; // ~15% shorter than current mobile height
                    } else if (cross == 2) {
                      aspect =
                          0.85; // taller to accommodate 200px image + content
                    } else if (cross >= 4) {
                      aspect = 1.35;
                    } else {
                      aspect = 1.1;
                    }
                    // Responsive sizing tweaks for mobile
                    final bool oneCol = cross == 1;
                    final double imageH = oneCol ? 180 : 200; // +50px on mobile
                    final double gridMainSpacing = oneCol ? 4 : 12;
                    final double gridCrossSpacing = oneCol ? 8 : 12;
                    final double contentPadding = oneCol ? 8.0 : 12.0;
                    final double chipWrapSpacing = oneCol ? 4 : 6; // kept for future use if needed
                    final double actionWrapSpacing = oneCol ? 10 : 12; // kept for future use in other sections
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        crossAxisSpacing: gridCrossSpacing,
                        mainAxisSpacing: gridMainSpacing,
                        childAspectRatio: aspect,
                      ),
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        final e = data[index];
                        final rid = _rowId(e);
                        final idCol = _idColumnFor(e);
                        final fotos =
                            (e['fotos_divulgacao'] as List?)
                                ?.cast<dynamic>()
                                .map((x) => x.toString())
                                .toList() ??
                            [];
                        final plantas =
                            (e['plantas'] as List?)
                                ?.cast<dynamic>()
                                .map((x) => x.toString())
                                .toList() ??
                            [];
                        final manutencao =
                            (e['fotos_manutencao'] as List?)
                                ?.cast<dynamic>()
                                .map((x) => x.toString())
                                .toList() ??
                            [];
                        final cover = fotos.isNotEmpty ? fotos.first : null;
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          elevation: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: imageH,
                                child: InkWell(
                                  onTap: fotos.isNotEmpty
                                      ? () => _openGaleria(
                                            fotos,
                                            imovelId: rid,
                                            idColumn: idCol,
                                            column: 'fotos_divulgacao',
                                          )
                                      : null,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      cover != null
                                          ? Image.network(
                                              cover,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Center(
                                                    child: Icon(
                                                      Icons.image_not_supported,
                                                    ),
                                                  ),
                                            )
                                          : Container(
                                              color: Colors.grey.shade200,
                                              child: const Center(
                                                child: Icon(
                                                  Icons.home,
                                                  size: 48,
                                                ),
                                              ),
                                            ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black54,
                                              ],
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  "${e['tipo'] ?? ''} • ${formatBrl(e['valor_aluguel'])}",
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _statusChip(
                                                _statusFromDb(
                                                  e['status']
                                                          ?.toString()
                                                          .toLowerCase()
                                                          .replaceAll(
                                                            RegExp(r'[^\w\s]'),
                                                            '',
                                                          ) ??
                                                      'disponivel',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final ok = await Navigator.of(context).pushNamed(
                                      '/imovel/detalhes',
                                      arguments: e,
                                    );
                                    if (ok == true) _refresh();
                                  },
                                child: Padding(
                                  padding: EdgeInsets.all(contentPadding),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(e['nome']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(e['descricao']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 6),
                                        Text(e['endereco']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 6),
                                        Text(formatBrl(e['valor_aluguel']),
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  

  Widget _statusChip(String status) {
    Color bg;
    const Color fg = Colors.white;
    switch (status) {
      case 'alugado':
        bg = Colors.orange;
        break;
      case 'manutencao':
        bg = Colors.blueGrey;
        break;
      case 'disponivel':
      default:
        bg = Colors.green;
        break;
    }
    return Chip(
      label: Text(status),
      backgroundColor: bg,
      labelStyle: const TextStyle(color: fg),
    );
  }

  bool _isPdf(String url) => url.toLowerCase().endsWith('.pdf');

  // Resolve o ID independente do nome de coluna usado no retorno
  dynamic _rowId(Map<String, dynamic> e) {
    // Prioriza imovel_id que é a PK real do banco
    if (e.containsKey('imovel_id')) return e['imovel_id'];
    if (e.containsKey('id')) return e['id'];
    if (e.containsKey('ID')) return e['ID'];
    return null;
  }

  // Mapeia valores de status entre UI (disponivel/alugado/manutencao) e enum do banco
  String _statusFromDb(String db) {
    final v = (db).toLowerCase();
    if (v.contains('alug')) return 'alugado';
    if (v.contains('manuten')) return 'manutencao';
    return 'disponivel';
  }

  String _statusToDb(String ui) {
    switch (ui) {
      case 'alugado':
        return 'alugado';
      case 'manutencao':
        return 'manutencao';
      default:
        return 'disponivel';
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
                    DropdownMenuItem(
                      value: 'condominio',
                      child: Text('Condomínio'),
                    ),
                    DropdownMenuItem(value: 'iptu', child: Text('IPTU')),
                    DropdownMenuItem(
                      value: 'manutencao',
                      child: Text('Manutenção'),
                    ),
                  ],
                  onChanged: (v) => tipo.value = v ?? 'condominio',
                  decoration: const InputDecoration(
                    labelText: 'Tipo de despesa*',
                  ),
                ),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              TextField(
                controller: valorCtrl,
                decoration: const InputDecoration(labelText: 'Valor*'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data == null
                          ? 'Data: —'
                          : 'Data: ${data!.toIso8601String().split('T').first}',
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final valor = double.tryParse(
                valorCtrl.text.replaceAll(',', '.'),
              );
              if (valor == null) return;
              final payload = {
                'imovel_id': imovelId,
                'tipo_despesa': tipo.value,
                'descricao': descCtrl.text.trim().isEmpty
                    ? null
                    : descCtrl.text.trim(),
                'valor': valor,
                'data': (data ?? DateTime.now()).toIso8601String(),
                'created_at': DateTime.now().toIso8601String(),
                'user_ref': Supabase.instance.client.auth.currentUser?.id,
              };
              try {
                await _svc.insert('despesas', payload);
                if (!mounted) return;
                Navigator.pop(ctx, true);
              } catch (e) {
                debugPrint('[Imoveis][ERROR] insert despesa: $e');
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (res == true) {
      // Optionally refresh something here if needed
    }
  }

  // Detecta qual coluna é a chave primária no mapa retornado do Supabase
  String _idColumnFor(Map<String, dynamic> e) {
    if (e.containsKey('imovel_id')) return 'imovel_id';
    if (e.containsKey('id')) return 'id';
    if (e.containsKey('ID')) return 'ID';
    return 'imovel_id';
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

  Future<void> _openPlantas(List<String> plantas, {dynamic imovelId, String idColumn = 'id'}) async {
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
                                _openGaleria([
                                  p,
                                  ...items.where((x) => !_isPdf(x))
                                ], imovelId: imovelId, idColumn: idColumn, column: 'plantas');
                              }
                            },
                            child: Container(
                              width: 200,
                              height: 140,
                              color: Colors.grey.shade200,
                              child: Center(
                                child: isPdf
                                    ? const Icon(
                                        Icons.picture_as_pdf,
                                        size: 48,
                                        color: Colors.red,
                                      )
                                    : Image.network(
                                        p,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.broken_image),
                                      ),
                              ),
                            ),
                          ),
                          if (imovelId != null)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Excluir',
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
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fechar'),
                ),
              ],
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir arquivo'),
        content: const Text('Deseja realmente excluir este arquivo? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirm != true) return false;
    try {
      await _svc.removeFromArrayColumn(
        table: 'imoveis',
        id: imovelId,
        column: column,
        valueToRemove: url,
        idColumn: idColumn,
      );
      await _svc.deleteStorageObjectByPublicUrl(bucket: 'galeria', publicUrl: url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arquivo excluído')));
      }
      // refresh grid
      _refresh();
      return true;
    } catch (e) {
      debugPrint('[Imoveis][ERROR] delete media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao excluir: $e')));
      }
      return false;
    }
  }

  Future<void> _openGaleria(List<String> fotos, {dynamic imovelId, String idColumn = 'id', required String column}) async {
    if (fotos.isEmpty) return;
    int index = 0;
    final items = List<String>.from(fotos);
    // Use a PageController so navigation arrows actually change pages
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
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image),
                                  ),
                                ),
                              );
                            },
                          ),
                          Positioned(
                            left: 8,
                            top: 0,
                            bottom: 0,
                            child: IconButton(
                              icon: const Icon(Icons.chevron_left, size: 32),
                              onPressed: () {
                                if (index > 0) {
                                  controller.previousPage(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 0,
                            bottom: 0,
                            child: IconButton(
                              icon: const Icon(Icons.chevron_right, size: 32),
                              onPressed: () {
                                if (index < items.length - 1) {
                                  controller.nextPage(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                            ),
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
                          Text('Imagem ${items.isEmpty ? 0 : index + 1} de ${items.length}')
                          ,
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Fechar'),
                          ),
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
}
