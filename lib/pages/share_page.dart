import 'package:flutter/material.dart';
import '../utils/format.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SharePage extends StatefulWidget {
  const SharePage({super.key});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  Map<String, dynamic>? _imovel;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Suporta /share?i=123 e também /#/share?i=123 (hash strategy)
      String? idParam = Uri.base.queryParameters['i'];
      if (idParam == null || idParam.isEmpty) {
        final frag = Uri.base.fragment; // ex: "/share?i=123"
        if (frag.isNotEmpty) {
          final fragUri = Uri.parse(frag.startsWith('/') ? frag : '/$frag');
          idParam = fragUri.queryParameters['i'];
        }
      }
      final imovelId = int.tryParse((idParam ?? '').trim());
      // opcional: telefone passado no link ?p=5599999999999
      String? phone = Uri.base.queryParameters['p'];
      if (phone == null || phone.isEmpty) {
        final frag = Uri.base.fragment;
        if (frag.isNotEmpty) {
          final fragUri = Uri.parse(frag.startsWith('/') ? frag : '/$frag');
          phone = fragUri.queryParameters['p'];
        }
      }
      if (imovelId == null) {
        setState(() {
          _error = 'Link inválido';
          _loading = false;
        });
        return;
      }
      final client = Supabase.instance.client;
      // Buscar somente campos necessários; requer política pública (publico=true)
      final res = await client
          .from('imoveis')
          .select('tipo,endereco,valor_aluguel,condominio,iptu,descricao,status,fotos_divulgacao')
          .eq('imovel_id', imovelId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _imovel = {
            ...?res,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
          };
          _loading = false;
        });
      }

      // Analytics básico (best-effort): registra uma visualização se a tabela existir
      try {
        await client.from('share_events').insert({
          'imovel_id': imovelId,
          'ts': DateTime.now().toIso8601String(),
          'url': Uri.base.toString(),
        });
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível carregar o imóvel';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error!)),
      );
    }
    final e = _imovel ?? {};
    final List fotos = (e['fotos_divulgacao'] as List?) ?? const [];
    final String? phone = (e['phone'] as String?);
    final kPrimary = const Color(0xFFA4D65E);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header simplificado sem CTA; moveremos os botões para o footer
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [kPrimary, const Color(0xFF8BC34A)]),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        (e['tipo'] ?? 'Imóvel').toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if ((e['endereco'] ?? '').toString().isNotEmpty)
                        Text(
                          '📍 ${e['endereco']}',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40)),
                        child: Text(
                          '💰 ${formatBrl(e['valor_aluguel'])}/mês',
                          style: TextStyle(color: kPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _infoCard('📋 Informações', [
                      if ((e['tipo'] ?? '').toString().isNotEmpty)
                        _row('Tipo', e['tipo'].toString()),
                      if ((e['endereco'] ?? '').toString().isNotEmpty)
                        _row('Endereço', e['endereco'].toString()),
                      _row('Aluguel', formatBrl(e['valor_aluguel'])),
                      if (e['condominio'] != null) _row('Condomínio', formatBrl(e['condominio'])),
                      if (e['iptu'] != null) _row('IPTU', formatBrl(e['iptu'])),
                      _row('Status', (e['status'] ?? 'disponivel').toString().toUpperCase()),
                    ]),
                    if ((e['descricao'] ?? '').toString().isNotEmpty)
                      _infoCard('📝 Descrição', [
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            e['descricao'].toString(),
                            style: const TextStyle(fontSize: 16, height: 1.6),
                          ),
                        )
                      ]),
                  ],
                ),
                const SizedBox(height: 16),
                if (fotos.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📸 Galeria de Fotos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, c) {
                            final cross = c.maxWidth < 500 ? 2 : 3;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cross,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1.4,
                              ),
                              itemCount: fotos.length,
                              itemBuilder: (_, i) => ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  fotos[i].toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFEAEAEA),
                                    child: const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [kPrimary, const Color(0xFF8BC34A)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('📞 Interessado no Imóvel?',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('Entre em contato para agendar uma visita!',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () async {
                              final msg = Uri.encodeComponent('Olá! Tenho interesse no imóvel: ${(e['tipo'] ?? 'Imóvel')} - ${(e['endereco'] ?? '')}');
                              final String waUrl = phone != null && phone.isNotEmpty
                                  ? 'https://wa.me/$phone?text=$msg&utm_source=share_page&utm_medium=whatsapp'
                                  : 'https://wa.me/?text=$msg&utm_source=share_page&utm_medium=whatsapp';
                              final uri = Uri.parse(waUrl);
                              await launchUrl(uri, webOnlyWindowName: '_blank');
                            },
                            icon: const Icon(Icons.chat),
                            label: const Text('Conversar no WhatsApp'),
                          ),
                          if (phone != null && phone.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse('tel:$phone');
                                await launchUrl(uri);
                              },
                              icon: const Icon(Icons.call),
                              label: const Text('Ligar'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text('🏠 Sistema de Gestão Imobiliária',
                      style: TextStyle(color: Colors.black54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Container(
      width: 480,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}


