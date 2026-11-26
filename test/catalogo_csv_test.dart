import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stokio/screens/estoque/produto_form_screen.dart';
import 'package:stokio/services/armazenamento.dart';
import 'package:stokio/services/catalogo_local.dart';
import 'package:stokio/utils/codigo_produto.dart';

void main() {
  testWidgets('Pré-preenche o cadastro pelo GTIN da planilha sem internet', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Armazenamento.iniciar();
    const codigo = '7896005801512';
    final gs1 = codigoDeProduto('https://id.gs1.org/01/07896005801512');
    expect(gs1, '07896005801512');
    final doBanco = await tester.runAsync(() => CatalogoLocal.buscar(gs1!));
    expect(doBanco?.nome, 'Café 3 corações ext forte 250 g');

    await tester.pumpWidget(
      const MaterialApp(home: ProdutoFormScreen(codigoInicial: codigo)),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    final nome = find.widgetWithText(TextFormField, 'Nome do produto');
    expect(tester.widget<TextFormField>(nome).controller?.text, doBanco?.nome);
    expect(find.text('Buscar no catálogo online'), findsNothing);
  });
}
