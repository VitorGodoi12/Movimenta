import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokio/app.dart';
import 'package:stokio/screens/estoque/estoque_screen.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/armazenamento.dart';
import 'package:stokio/services/perfil_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Cria o perfil local e abre o estoque', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Armazenamento.iniciar();
    await perfil.carregar();
    await tester.pumpWidget(const StokioApp());
    await tester.pumpAndSettle();

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Vitor');
    await tester.enterText(campos.at(1), 'Loja Teste');
    final comecar = find.text('Começar a usar');
    await tester.ensureVisible(comecar);
    await tester.tap(comecar);
    await tester.pumpAndSettle();

    expect(find.text('Começar a usar'), findsNothing);
    await tester.tap(find.text('Estoque'));
    await tester.pumpAndSettle();
    expect(find.text('Estoque'), findsWidgets);
    await tester.tap(find.text('Vender'));
    await tester.pumpAndSettle();
    expect(find.text('Finalizar venda'), findsOneWidget);
    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    expect(find.text('Configurações e backup'), findsOneWidget);

    final perfilRecarregado = PerfilService();
    addTearDown(perfilRecarregado.dispose);
    await perfilRecarregado.carregar();
    expect(perfilRecarregado.cliente?.estabelecimento, 'Loja Teste');
  });

  testWidgets('Confere uma lista e importa pelo menu do estoque', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Armazenamento.iniciar();
    await tester.pumpWidget(const MaterialApp(home: EstoqueScreen()));
    await tester.tap(find.byTooltip('Importar lista de estoque'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '1 cx salsicha\n0 X Itaipava 350',
    );
    await tester.tap(find.text('Conferir lista'));
    await tester.pumpAndSettle();

    expect(estoque.produtos, isEmpty);
    expect(find.text('Bebidas'), findsOneWidget);
    expect(find.text('Salgados e congelados'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '12');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar 2 produtos'));
    await tester.pumpAndSettle();
    expect(estoque.produtos, hasLength(2));
    expect(
      estoque.produtos.firstWhere((p) => p.nome == 'salsicha').quantidade,
      12,
    );
    expect(find.text('Bebidas'), findsWidgets);
    expect(find.text('Salgados e congelados'), findsWidgets);
  });
}
