# Stokio

Aplicativo Flutter para pequenos negócios acompanharem o estoque, as validades, as entradas e as saídas. O perfil e o estoque ficam armazenados no aparelho. O leitor usa a câmera ou permite digitar o código de barras manualmente.

## Estrutura do projeto

- `android/`, `ios/` e `web/` contêm a configuração de cada plataforma.
- `assets/images/` contém a imagem original do ícone do Stokio.
- `lib/` contém o aplicativo em Dart e `test/` contém os testes Flutter.

## Executar no Android

Com Flutter 3.47 ou superior, JDK 17 ou superior e o SDK do Android configurado, conecte um aparelho ou abra um emulador e execute na raiz do projeto:

```sh
flutter pub get
flutter run
```

## Importar uma contagem

Na tela **Estoque**, toque em **Importar lista de estoque**, cole o texto e confira a prévia. A importação aceita quantidades em unidades, caixas e fardos, inclui itens zerados e usa a última contagem quando o mesmo produto aparece mais de uma vez. Corrija no texto as linhas sinalizadas sem quantidade. Os produtos ficam agrupados por categoria no estoque.

Ao ler ou digitar um código de barras, o aplicativo abre o produto cadastrado. Se o código ainda estiver livre, escolha entre vincular a um produto sem código e cadastrar um novo.

## Recursos da versão 1.1

- Venda rápida por código ou busca, com carrinho e opção de desfazer.
- Fornecedores, lista de compras por fornecedor e pedido pelo WhatsApp.
- Inventário guiado, local do produto, preço de custo e resumo de margem e lucro.
- Exportação CSV de estoque e histórico, com filtros de movimentação por tipo.

A atualização do aplicativo Android conserva os dados locais. Backups anteriores do Movimenta também podem ser restaurados pelo Stokio.

## Compilar e testar

```sh
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
```

O APK fica em `build/app/outputs/flutter-apk/app-release.apk`. A configuração atual usa a chave de desenvolvimento para instalação direta. Para publicar na Play Store, configure uma chave de produção.
