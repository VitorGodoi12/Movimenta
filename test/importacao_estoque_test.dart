import 'package:flutter_test/flutter_test.dart';
import 'package:movimenta/models/produto.dart';
import 'package:movimenta/services/armazenamento.dart';
import 'package:movimenta/services/estoque_service.dart';
import 'package:movimenta/services/importacao_estoque.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Mantém itens de mesmo nome em categorias diferentes', () {
    final lista = interpretarListaEstoque(
      '{ Bebidas }\n1 X Laranja\n{ Hortifruti }\n5 X Laranja',
    );
    expect(lista.itens.map((item) => item.quantidade), [1, 5]);
    expect(lista.repetidos, isEmpty);
  });

  test(
    'Interpreta unidades, zeros, categorias e variações de uma lista colada',
    () {
      final lista = interpretarListaEstoque(r'''
10 x Itaipava 350\
4 x Petra 269\
2 X Petra 350\
1 X zero álcool It \
5 cx defumada \
1 cx salsicha \
{ NOVO ESTOQUE}
&#x20;\* REFRIGERANTES \*
&#x20; { COCA }
&#x20; \* 8 X RET COCA
&#x20; \* 0 DELL VALE 1L LARANJA
{ MONSTER }
* 2 x preto zero
SUCO VIG
* O X MORANGO
* Águas *
{ 500ml }
* 7 x Crystal
\--------------------------------------
{ 1,5 ml }
* 3 x Crystal
{ ÁGUA SANITÁRIA }
1 LITROS
* 4 X SUPER CAND. 1L
{ SABÃO 🫧 PÓ }
* 1 X OMO CX 700G
{ DETERGENTES }
NAO TEM NADA
{ LIMPEZA EM GERAL }
* SACOS LIXO 100L
{ MERCEARIA EM GERAL }
* 1 X ÁGUA QUADRA COCO 1L
* 1 CX MILHO LATA FUJINI
{ CERVEJAS }
* 0 X ITAIPAVA SEM ÁLCOOL
* 5 X ITAIPAVA 350ML
* 2 X PETRA 269
* 4 X PETRA 350
{ PAPEL HIGIÊNICO }
* 7 FARDO BOB 12 ROLOS
{ LEITES }
* 1 cx LEITE CONS. ITALAC
8 cx Qualy 500 c/sal
5 cx Qualy 250 c/ sal
''');

      final itens = {for (final item in lista.itens) item.nome: item};
      expect(itens['ITAIPAVA 350ML']?.quantidade, 5);
      expect(itens['ITAIPAVA SEM ÁLCOOL']?.quantidade, 0);
      expect(itens['PETRA 269']?.quantidade, 2);
      expect(itens['PETRA 350']?.quantidade, 4);
      expect(itens['defumada']?.categoria, 'Salgados e congelados');
      expect(itens['salsicha']?.unidade, 'cx');
      expect(itens['DELL VALE 1L LARANJA']?.quantidade, 0);
      expect(itens['Monster preto zero']?.categoria, 'Bebidas');
      expect(itens['Suco Vig MORANGO']?.quantidade, 0);
      expect(itens['Crystal 500ml']?.quantidade, 7);
      expect(itens['Crystal 1,5 ml']?.quantidade, 3);
      expect(itens['SUPER CAND. 1L']?.categoria, 'Produtos de limpeza');
      expect(itens['OMO CX 700G']?.categoria, 'Produtos de limpeza');
      expect(itens['ÁGUA QUADRA COCO 1L']?.categoria, 'Mercearia');
      expect(itens['MILHO LATA FUJINI']?.unidade, 'cx');
      expect(itens['BOB 12 ROLOS']?.unidade, 'fardo');
      expect(itens['BOB 12 ROLOS']?.categoria, 'Higiene');
      expect(itens['Qualy 500 c/sal']?.categoria, 'Laticínios');
      expect(itens['Qualy 250 c/ sal']?.quantidade, 5);
      expect(lista.repetidos, hasLength(4));
      expect(lista.pendencias, ['SACOS LIXO 100L']);
    },
  );

  test(
    'Reimporta contagem sem duplicar e preserva preço e código de barras',
    () async {
      SharedPreferences.setMockInitialValues({});
      await Armazenamento.iniciar();
      final servico = EstoqueService();
      addTearDown(servico.dispose);
      servico.adicionar(
        Produto(
          id: 'cadastrado',
          nome: 'Itaipava 350',
          categoria: 'Bebidas',
          quantidade: 10,
          minimo: 2,
          preco: 5,
          codigoBarras: '7891234567890',
        ),
      );
      final lista = interpretarListaEstoque(
        '0 X ITAIPAVA 350ML\n1 cx salsicha',
      );
      await servico.importarContagem(lista.itens);
      await servico.importarContagem(lista.itens);

      final recarregado = EstoqueService();
      addTearDown(recarregado.dispose);
      await recarregado.carregar();
      final produto = recarregado.porCodigo('7891234567890');
      expect(recarregado.produtos, hasLength(2));
      expect(recarregado.historico, hasLength(3));
      expect(produto?.id, 'cadastrado');
      expect(produto?.quantidade, 0);
      expect(produto?.preco, 5);
      expect(produto?.minimo, 2);
    },
  );
}
