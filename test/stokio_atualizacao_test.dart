import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stokio/models/fornecedor.dart';
import 'package:stokio/services/armazenamento.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/importacao_estoque.dart';

void main() {
  test(
    'Carrega estoque anterior e mantém o fornecedor após importar',
    () async {
      SharedPreferences.setMockInitialValues({
        'movimenta_estoque_v1': jsonEncode({
          'produtos': [
            {
              'id': 'p1',
              'nome': 'Itaipava 350',
              'categoria': 'Bebidas',
              'quantidade': 8,
              'minimo': 1,
              'preco': 5.0,
              'codigoBarras': '7891000100103',
            },
          ],
          'historico': [],
        }),
      });
      await Armazenamento.iniciar();
      final servico = EstoqueService();
      addTearDown(servico.dispose);
      await servico.carregar();

      final produto = servico.produtos.single;
      expect(produto.custo, 0);
      expect(produto.local, isNull);
      produto.fornecedorId = 'f1';
      servico.adicionarFornecedor(
        Fornecedor(id: 'f1', nome: 'Distribuidora', telefone: '11999999999'),
      );
      await servico.importarContagem(
        interpretarListaEstoque('4 X ITAIPAVA 350ML').itens,
      );

      final reaberto = EstoqueService();
      addTearDown(reaberto.dispose);
      await reaberto.carregar();
      final salvo = reaberto.porCodigo('7891000100103')!;
      expect(salvo.quantidade, 4);
      expect(reaberto.fornecedorDe(salvo)?.nome, 'Distribuidora');

      final venda = reaberto.registrarVenda([ItemVenda(salvo, 2)]);
      expect(salvo.quantidade, 2);
      expect(venda, hasLength(1));
      reaberto.desfazerVarias(venda);
      expect(salvo.quantidade, 4);

      final contagem = reaberto.aplicarContagens({'p1': 1});
      expect(salvo.quantidade, 1);
      reaberto.desfazerVarias(contagem);
      expect(salvo.quantidade, 4);
      expect(reaberto.registrarVenda([ItemVenda(salvo, 5)]), isEmpty);
      expect(salvo.quantidade, 4);
    },
  );
}
