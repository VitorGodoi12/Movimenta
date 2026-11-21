import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stokio/models/fornecedor.dart';
import 'package:stokio/models/movimentacao.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/services/armazenamento.dart';
import 'package:stokio/services/backup_service.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/importacao_estoque.dart';

void main() {
  late EstoqueService servico;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Armazenamento.iniciar();
    servico = EstoqueService();
    addTearDown(servico.dispose);
  });

  test(
    'Converte caixas, preserva lotes e baixa o que vence primeiro',
    () async {
      final antes = DateTime(2030, 2, 2);
      final depois = DateTime(2030, 3, 3);
      final produto = Produto(
        id: 'p',
        nome: 'Suco',
        categoria: 'Bebidas',
        quantidade: 3,
        minimo: 0,
        preco: 4,
        validade: antes,
      );
      servico.adicionar(produto);
      final item = interpretarListaEstoque('{ Bebidas }\n2 cx Suco')
          .itens
          .single;
      expect(servico.fatorImportacao(item), 0);
      await servico.importarContagem([item.comFator(12)]);
      expect(servico.fatorImportacao(item), 12);
      expect(produto.quantidade, 24);
      expect(produto.lotes[antes], 3);

      servico.movimentar(produto, TipoMovimento.entrada, 5, validade: depois);
      final venda = servico.registrarVenda([
        ItemVenda(produto, 4),
      ], pagamento: 'Pix');
      expect(Movimentacao.fromJson(venda.single.toJson()).pagamento, 'Pix');
      expect(produto.lotes[antes], isNull);
      expect(produto.lotes[depois], 4);
      expect(produto.quantidade, 25);
      servico.desfazerVarias(venda);
      expect(produto.lotes[antes], 3);
      expect(produto.lotes[depois], 5);
      final reaberto = Produto.fromJson(produto.toJson());
      expect(reaberto.quantidade, 29);
      expect(reaberto.lotes, produto.lotes);
    },
  );

  test('Sugere reposição antecipada pelo ritmo de vendas e prazo', () {
    servico.adicionarFornecedor(
      Fornecedor(id: 'f', nome: 'Entrega', prazoDias: 8),
    );
    final produto = Produto(
      id: 'p',
      nome: 'Suco',
      categoria: 'Bebidas',
      quantidade: 40,
      minimo: 1,
      preco: 4,
      fornecedorId: 'f',
    );
    servico.adicionar(produto);
    servico.registrarVenda([ItemVenda(produto, 30)]);
    expect(produto.quantidade, 10);
    expect(servico.listaCompras.single.sugerido, 5);
  });

  test('Valida um backup antigo sem aplicar no estoque atual', () {
    final backup = jsonEncode({
      'app': 'movimenta',
      'perfil': {'cliente': null},
      'estoque': {'produtos': [], 'historico': [], 'fornecedores': []},
    });
    expect(BackupService.testar(backup).produtos, 0);
    expect(
      () => BackupService.testar('{"app":"stokio"}'),
      throwsA(isA<TypeError>()),
    );
  });
}
