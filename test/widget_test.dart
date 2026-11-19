import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movimenta/app.dart';
import 'package:movimenta/services/armazenamento.dart';
import 'package:movimenta/services/perfil_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Cria o perfil local e abre o estoque', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Armazenamento.iniciar();
    await perfil.carregar();
    await tester.pumpWidget(const MovimentaApp());
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

    final perfilRecarregado = PerfilService();
    addTearDown(perfilRecarregado.dispose);
    await perfilRecarregado.carregar();
    expect(perfilRecarregado.cliente?.estabelecimento, 'Loja Teste');
  });
}
