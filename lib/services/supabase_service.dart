import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;

  SupabaseClient get client => Supabase.instance.client;

  // Utils básicos com logs para facilitar debug
  Future<List<Map<String, dynamic>>> list(String table,
      {Map<String, dynamic>? filters, int limit = 50}) async {
    debugPrint('[SupabaseService] list => table=$table, filters=$filters');
    final query = client.from(table).select().limit(limit);
    try {
      final data = await query;
      return (data as List).cast<Map<String, dynamic>>();
    } catch (e, st) {
      debugPrint('[SupabaseService][ERROR] list: $e');
      debugPrint('$st');
      rethrow;
    }

  }

  // ===== Storage helpers =====
  Future<void> deleteStorageObjectByPath({
    required String bucket,
    required String path,
  }) async {
    try {
      debugPrint('[SupabaseService] deleteStorageObjectByPath => bucket=$bucket, path=$path');
      await client.storage.from(bucket).remove([path]);
    } catch (e, st) {
      debugPrint('[SupabaseService][ERROR] deleteStorageObjectByPath: $e');
      debugPrint('$st');
    }
  }

  

  String _inferContentType(String path, [String? fallback]) {
    final p = path.toLowerCase();
    if (p.endsWith('.html') || p.endsWith('.htm')) return 'text/html; charset=utf-8';
    if (p.endsWith('.css')) return 'text/css; charset=utf-8';
    if (p.endsWith('.js')) return 'application/javascript; charset=utf-8';
    if (p.endsWith('.json')) return 'application/json; charset=utf-8';
    if (p.endsWith('.svg')) return 'image/svg+xml';
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'image/jpeg';
    if (p.endsWith('.webp')) return 'image/webp';
    return fallback ?? 'application/octet-stream';
  }

  Future<Map<String, dynamic>> insert(String table, Map<String, dynamic> values) async {
    debugPrint('[SupabaseService] insert => table=$table, values=$values');
    try {
      // Try to get a single row back in a resilient way (web can vary)
      final sel = client.from(table).insert(values).select();
      final maybe = await sel.maybeSingle();
      if (maybe != null) {
        return Map<String, dynamic>.from(maybe);
      }
      // Fallback: fetch the most recent row for the current user if possible, else just query last inserted by created_at
      // Note: This is a best-effort fallback when the backend doesn't return the inserted row.
      try {
        final list = await client.from(table).select().order('created_at', ascending: false).limit(1);
        if (list.isNotEmpty) {
          return Map<String, dynamic>.from(list.first as Map);
        }
      } catch (_) {}
      throw StateError('Insert succeeded but no row was returned');
    } catch (e, st) {
      debugPrint('[SupabaseService][ERROR] insert: $e');
      debugPrint('$st');
      // Enum fallback: if enum imovel_status rejects our value, retry without 'status' to let DB default
      final msg = e.toString();
      final hasEnumErr = msg.contains('imovel_status') && msg.contains('invalid input value');
      if (hasEnumErr && values.containsKey('status')) {
        try {
          final retry = Map<String, dynamic>.from(values);
          retry.remove('status');
          debugPrint('[SupabaseService][WARN] insert retry without status due to enum mismatch');
          final sel = client.from(table).insert(retry).select();
          final maybe = await sel.maybeSingle();
          if (maybe != null) {
            return Map<String, dynamic>.from(maybe);
          }
          final list = await client.from(table).select().order('created_at', ascending: false).limit(1);
          if (list.isNotEmpty) {
            return Map<String, dynamic>.from(list.first as Map);
          }
        } catch (e2, st2) {
          debugPrint('[SupabaseService][ERROR] insert retry failed: $e2');
          debugPrint('$st2');
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateById(String table, dynamic id, Map<String, dynamic> values) async {
    return updateBy(table: table, id: id, values: values);
  }

  Future<Map<String, dynamic>> updateBy({
    required String table,
    required dynamic id,
    required Map<String, dynamic> values,
    String idColumn = 'id',
  }) async {
    debugPrint('[SupabaseService] updateBy => table=$table, $idColumn=$id, values=$values');
    try {
      final sel = client.from(table).update(values).eq(idColumn, id).select();
      final maybe = await sel.maybeSingle();
      if (maybe != null) {
        return Map<String, dynamic>.from(maybe);
      }
      // Fallback: query the row by id
      final fetched = await client.from(table).select().eq(idColumn, id).maybeSingle();
      if (fetched != null) {
        return Map<String, dynamic>.from(fetched);
      }
      throw StateError('Update succeeded but no row was returned');
    } catch (e, st) {
      debugPrint('[SupabaseService][ERROR] updateBy: $e');
      debugPrint('$st');
      // Enum fallback similar to insert
      final msg = e.toString();
      final hasEnumErr = msg.contains('imovel_status') && msg.contains('invalid input value');
      if (hasEnumErr && values.containsKey('status')) {
        try {
          final retry = Map<String, dynamic>.from(values);
          retry.remove('status');
          debugPrint('[SupabaseService][WARN] updateBy retry without status due to enum mismatch');
          final sel = client.from(table).update(retry).eq(idColumn, id).select();
          final maybe = await sel.maybeSingle();
          if (maybe != null) {
            return Map<String, dynamic>.from(maybe);
          }
          final fetched = await client.from(table).select().eq(idColumn, id).maybeSingle();
          if (fetched != null) {
            return Map<String, dynamic>.from(fetched);
          }
        } catch (e2, st2) {
          debugPrint('[SupabaseService][ERROR] updateBy retry failed: $e2');
          debugPrint('$st2');
        }
      }
      rethrow;
    }
  }

  Future<void> softDeleteById(String table, dynamic id, {String idColumn = 'id'}) async {
    debugPrint('[SupabaseService] softDeleteById => table=$table, $idColumn=$id');
    try {
      await client.from(table).update({'deleted_at': DateTime.now().toIso8601String()}).eq(idColumn, id);
    } catch (e, st) {
      debugPrint('[SupabaseService][ERROR] softDeleteById: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ===== Usuários / Perfis =====
  Future<void> setAuthUserMetadata({required String nome, required String perfil}) async {
    try {
      await client.auth.updateUser(
        UserAttributes(data: {
          'nome': nome,
          'perfil': perfil,
        }),
      );
      debugPrint('[SupabaseService] setAuthUserMetadata OK');
    } catch (e) {
      debugPrint('[SupabaseService][ERROR] setAuthUserMetadata: $e');
    }
  }

  Future<void> upsertUsuarioRow({
    required String userId,
    required String nome,
    required String email,
  }) async {
    try {
      // Tenta detectar se a tabela existe consultando 1 registro filtrado
      final existing = await client.from('usuarios').select().eq('user_ID', userId).maybeSingle();
      if (existing != null) {
        await client.from('usuarios').update({
          'Nome': nome,
          'e - mail': email,
        }).eq('user_ID', userId);
        debugPrint('[SupabaseService] usuarios updated for $userId');
        return;
      }
      // Insere novo
      await client.from('usuarios').insert({
        'user_ID': userId,
        'Nome': nome,
        'e - mail': email,
      });
      debugPrint('[SupabaseService] usuarios inserted for $userId');
    } catch (e) {
      // Se falhar por nome de coluna divergente (ex: "e - mail"), apenas loga
      debugPrint('[SupabaseService][WARN] upsertUsuarioRow failed: $e');
    }
  }

  Future<void> deleteById(String table, dynamic id, {String idColumn = 'id'}) async {
    debugPrint('[SupabaseService] deleteById => table=$table, $idColumn=$id');
    try {
      await client.from(table).delete().eq(idColumn, id);
    } catch (e, st) {
      debugPrint('[SupabaseService][ERROR] deleteById: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ===== Storage helpers =====
  Future<String> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String? contentType,
    String? cacheControl,
    bool upsert = true,
    bool deleteBeforeUpload = false,
    Map<String, String>? upsertHeaders,
  }) async {
    final inferred = contentType ?? _inferContentType(path);
    debugPrint('[SupabaseService] uploadBytes => bucket=$bucket, path=$path, bytes=${bytes.length}, ct=$inferred');
    final storage = client.storage.from(bucket);

    // Para garantir headers corretos em HTML público, removemos o arquivo antes de reenviar
    if (deleteBeforeUpload || inferred.startsWith('text/html')) {
      try {
        await storage.remove([path]);
      } catch (_) {}
    }

    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: inferred,
        upsert: upsert,
        cacheControl: cacheControl ?? '3600',
      ),
    );
    
    // Aplicar headers adicionais se fornecidos
    if (upsertHeaders != null && upsertHeaders.isNotEmpty) {
      try {
        // Não há método direto para atualizar apenas os headers, então precisamos
        // fazer upload novamente com os headers corretos
        await storage.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: upsertHeaders['content-type'] ?? inferred,
            upsert: true,
            cacheControl: cacheControl ?? '3600',
          ),
        );
        debugPrint('[SupabaseService] Headers atualizados para $path: ${upsertHeaders['content-type']}');
      } catch (e) {
        debugPrint('[SupabaseService][ERROR] Falha ao atualizar headers: $e');
      }
    }
    final url = storage.getPublicUrl(path);
    return url;
  }

  Future<void> appendToArrayColumn({
    required String table,
    required dynamic id,
    required String column,
    required List<dynamic> valuesToAppend,
    String idColumn = 'id',
  }) async {
    debugPrint('[SupabaseService] appendToArrayColumn => table=$table, $idColumn=$id, column=$column, +${valuesToAppend.length}');
    final current = await client.from(table).select(column).eq(idColumn, id).maybeSingle();
    List<dynamic> arr = [];
    if (current != null && current[column] is List) {
      arr = List<dynamic>.from(current[column]);
    }
    arr.addAll(valuesToAppend);
    // Some tables may not have 'updated_at'. Try with it, fallback without.
    try {
      await client
          .from(table)
          .update({column: arr, 'updated_at': DateTime.now().toIso8601String()})
          .eq(idColumn, id);
    } catch (e) {
      debugPrint('[SupabaseService][WARN] appendToArrayColumn without updated_at due to error: $e');
      await client.from(table).update({column: arr}).eq(idColumn, id);
    }
  }

  Future<void> removeFromArrayColumn({
    required String table,
    required dynamic id,
    required String column,
    required dynamic valueToRemove,
    String idColumn = 'id',
  }) async {
    debugPrint('[SupabaseService] removeFromArrayColumn => table=$table, $idColumn=$id, column=$column, value=$valueToRemove');
    final current = await client.from(table).select(column).eq(idColumn, id).maybeSingle();
    List<dynamic> arr = [];
    if (current != null && current[column] is List) {
      arr = List<dynamic>.from(current[column]);
    }
    arr.removeWhere((e) => e == valueToRemove);
    try {
      await client
          .from(table)
          .update({column: arr, 'updated_at': DateTime.now().toIso8601String()})
          .eq(idColumn, id);
    } catch (e) {
      debugPrint('[SupabaseService][WARN] removeFromArrayColumn without updated_at due to error: $e');
      await client.from(table).update({column: arr}).eq(idColumn, id);
    }
  }

  // Delete a storage object using its public URL for a given bucket
  Future<void> deleteStorageObjectByPublicUrl({
    required String bucket,
    required String publicUrl,
  }) async {
    try {
      // Public URL pattern: https://<host>/storage/v1/object/public/{bucket}/{path}
      final marker = '/storage/v1/object/public/' + bucket + '/';
      final idx = publicUrl.indexOf(marker);
      if (idx == -1) {
        debugPrint('[SupabaseService][WARN] deleteStorageObjectByPublicUrl: URL não parece pública deste bucket: ' + publicUrl);
        return;
      }
      final path = publicUrl.substring(idx + marker.length);
      debugPrint('[SupabaseService] deleteStorageObject => bucket=$bucket, path=$path');
      await client.storage.from(bucket).remove([path]);
    } catch (e, st) {
      debugPrint('[SupabaseService][ERROR] deleteStorageObjectByPublicUrl: $e');
      debugPrint('$st');
    }
  }
  
  // Adiciona um link de compartilhamento ao array share_links do imóvel
  Future<void> addShareLink({
    required dynamic imovelId,
    required String shareLink,
    String idColumn = 'id',
  }) async {
    debugPrint('[SupabaseService] addShareLink => imovelId=$imovelId, shareLink=$shareLink');
    try {
      await appendToArrayColumn(
        table: 'imoveis',
        id: imovelId,
        column: 'share_links',
        valuesToAppend: [shareLink],
        idColumn: 'imovel_id',
      );
      debugPrint('[SupabaseService] Link adicionado na coluna share_links');
    } catch (e, st) {
      debugPrint('[SupabaseService][ERROR] addShareLink: $e');
      debugPrint('$st');
      rethrow;
    }
  }
  
  // Remove um link de compartilhamento do array share_links do imóvel
  Future<void> removeShareLink({
    required dynamic imovelId,
    required String shareLink,
    String idColumn = 'id',
  }) async {
    debugPrint('[SupabaseService] removeShareLink => imovelId=$imovelId, shareLink=$shareLink');
    try {
      await removeFromArrayColumn(
        table: 'imoveis',
        id: imovelId,
        column: 'share_links',
        valueToRemove: shareLink,
        idColumn: 'imovel_id',
      );
      debugPrint('[SupabaseService] Link removido da coluna share_links');
    } catch (e, st) {
      debugPrint('[SupabaseService][ERROR] removeShareLink: $e');
      debugPrint('$st');
      rethrow;
    }
  }
  
  // Obtém todos os links de compartilhamento de um imóvel
  Future<List<String>> getShareLinks({
    required dynamic imovelId,
    String idColumn = 'id',
  }) async {
    debugPrint('[SupabaseService] getShareLinks => imovelId=$imovelId');
    try {
      // Tentar primeiro com id, depois com imovel_id se falhar
      Map<String, dynamic>? result;
      
      // Usar a coluna share_links correta
      result = await client.from('imoveis').select('share_links').eq('imovel_id', imovelId).maybeSingle();
      debugPrint('[SupabaseService] Busca share_links funcionou');
      
      if (result != null && result['share_links'] is List) {
        final shareLinks = List<String>.from(result['share_links']);
        debugPrint('[SupabaseService] Links encontrados: $shareLinks');
        return shareLinks;
      }
      return [];
    } catch (e, st) {
      debugPrint('[SupabaseService][ERROR] getShareLinks: $e');
      debugPrint('$st');
      return [];
    }
  }
}
