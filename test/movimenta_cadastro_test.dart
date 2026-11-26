import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/services/catalogo_local.dart';
import 'package:stokio/widgets/campo_data.dart';

void main() {
  testWidgets('Digita uma validade brasileira sem abrir o calendário', (
    tester,
  ) async {
    DateTime? data;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampoData(
            rotulo: 'Validade',
            valor: null,
            aoMudar: (nova) => data = nova,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '25022027');
    expect(find.text('25/02/2027'), findsOneWidget);
    expect(data, DateTime(2027, 2, 25));
    await tester.enterText(find.byType(TextFormField), '31022027');
    expect(data, isNull);
  });

  test('Persiste os dois saldos sem duplicar produtos', () {
    final p = Produto(
      id: '1',
      nome: 'Café',
      categoria: 'Cafés',
      quantidade: 10,
      minimo: 2,
      preco: 15,
      saldoLoja: 4,
    );
    final salvo = Produto.fromJson(p.toJson());
    expect((salvo.saldoEstoque, salvo.saldoLoja), (6, 4));
    salvo.distribuirSaldo(6);
    expect((salvo.quantidade, salvo.saldoEstoque, salvo.saldoLoja), (10, 4, 6));
  });

  test('Normaliza o nome e a medida da sugestão', () {
    expect(
      CatalogoLocal.formatarNome('REFRIGERANTE COLA', '2L'),
      'REFRIGERANTE COLA 2 L',
    );
    expect(CatalogoLocal.formatarNome('CAFÉ 500G', '500 g'), 'CAFÉ 500 G');
  });
}
