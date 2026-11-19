# Movimenta

Aplicativo Flutter para pequenos negócios acompanharem o estoque, as validades, as entradas e as saídas. O perfil e o estoque ficam armazenados no aparelho. O leitor usa a câmera ou permite digitar o código de barras manualmente.

## Executar no Android

Com Flutter 3.47 ou superior, JDK 17 ou superior e o SDK do Android configurado, conecte um aparelho ou abra um emulador e execute na raiz do projeto:

```sh
flutter pub get
flutter run
```

## Compilar e testar

```sh
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
```

O APK fica em `build/app/outputs/flutter-apk/app-release.apk`. A configuração atual usa a chave de desenvolvimento para instalação direta. Para publicar na Play Store, configure uma chave de produção.
