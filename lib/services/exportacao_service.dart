import 'dart:convert';
import 'dart:typed_data';

import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/utils/formatadores.dart';
import 'package:share_plus/share_plus.dart';

/// Exporta planilhas CSV (separador ";", abre direto no Excel em português).
class ExportacaoService {
  ExportacaoService._();

  static String _campo(Object? v) {
    final s = v?.toString() ?? '';
    if (s.contains(';') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String _linha(List<Object?> colunas) => colunas.map(_campo).join(';');

  static String _numero(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  static String csvEstoque() {
    final linhas = <String>[
      _linha([
        'Código',
        'Produto',
        'Categoria',
        'Local',
        'Fornecedor',
        'Quantidade',
        'Unidade',
        'Mínimo',
        'Custo',
        'Preço de venda',
        'Validade',
        'Valor em estoque',
      ]),
    ];
    for (final p in estoque.produtos) {
      linhas.add(
        _linha([
          p.codigoBarras ?? '',
          p.nome,
          p.categoria,
          p.local ?? '',
          estoque.fornecedorDe(p)?.nome ?? '',
          p.quantidade,
          p.unidade,
          p.minimo,
          _numero(p.custo),
          _numero(p.preco),
          p.validade == null ? '' : formatarData(p.validade!),
          _numero(p.valorEmEstoque),
        ]),
      );
    }
    return linhas.join('\r\n');
  }

  static String csvHistorico() {
    final linhas = <String>[
      _linha([
        'Data',
        'Hora',
        'Produto',
        'Tipo',
        'Motivo',
        'Variação',
        'Pagamento',
      ]),
    ];
    for (final m in estoque.historico) {
      final tipo = switch (m.tipo) {
        TipoMovimento.entrada => 'Entrada',
        TipoMovimento.saida => 'Saída',
        TipoMovimento.ajuste => 'Ajuste',
        TipoMovimento.cadastro => 'Cadastro',
      };
      linhas.add(
        _linha([
          formatarData(m.data),
          formatarHora(m.data),
          m.produtoNome,
          tipo,
          m.motivo ?? '',
          m.delta,
          m.pagamento ?? '',
        ]),
      );
    }
    return linhas.join('\r\n');
  }

  static Future<void> compartilhar(String nomeArquivo, String csv) async {
    // O BOM no começo faz o Excel reconhecer os acentos.
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));
    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: 'text/csv', name: nomeArquivo)],
      fileNameOverrides: [nomeArquivo],
      subject: nomeArquivo,
    );
  }
}
