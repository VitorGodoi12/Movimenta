# Configuração e teste do Movimenta no Android

## Modo local

Com Java 21 configurado no JAVA_HOME, execute na raiz:

    flutter pub get
    dart format lib test
    flutter analyze --no-fatal-infos
    flutter test
    flutter build apk --release

O APK comum usa o modo local e preserva o armazenamento do aparelho. A ficha usa os códigos do catálogo embarcado, a consulta online e o OCR do ML Kit no Android. A captura usa a câmera traseira do sistema. O leitor ao vivo oferece enquadramento e lanterna.

## Vincular o Firebase

1. Instale Flutter e Android SDK. Use Java 21 para a compilação Android e os emuladores e Node.js 22 para as Functions.
2. Instale e autentique as ferramentas:

       npm install -g firebase-tools
       firebase login
       dart pub global activate flutterfire_cli

3. Crie ou use um projeto autorizado no Firebase Console e cadastre o Android com o pacote com.vitorgodoi.movimenta. Execute na raiz:

       flutter pub get
       flutterfire configure --project=ID_DO_PROJETO --platforms=android --android-package-name=com.vitorgodoi.movimenta

4. Verifique android/app/google-services.json e o plugin com.google.gms.google-services no módulo Android. Se o CLI não ajustar o Gradle, siga o assistente Console → Adicionar app Android → Adicionar SDK.
5. Em **Authentication → Sign-in method**, habilite **E-mail/senha** e **Google** e informe o e-mail de suporte. Usuários de e-mail precisam confirmar a caixa postal antes de criar ou ingressar em um mercado.

### SHA-1 para Google

Na pasta android, no Windows, execute:

    .\gradlew.bat signingReport

No Linux ou macOS:

    ./gradlew signingReport

Em **Configurações do projeto → Geral → Seus apps → Android → Impressões digitais**, cadastre o SHA-1 do certificado que assina o APK. Use o certificado debug para flutter run. Use o certificado de distribuição para o APK efetivamente entregue. A compilação atual de instalação direta utiliza a assinatura debug também no build release. Em distribuição pela Play Store, use o certificado de assinatura do app mostrado no Play Console. Cadastre também SHA-256 conforme a configuração do projeto. Depois de ativar Google ou alterar assinaturas, baixe novamente google-services.json e execute flutterfire configure antes de recompilar. Guarde chaves de conta de serviço fora do app.

### Regras, Functions e seeder

Crie um Firestore no modo de produção. As Functions usam a região padrão us-central1 e a implantação pode exigir faturamento ativo. Execute:

    npm ci --prefix firebase/functions
    firebase deploy --project ID_DO_PROJETO --only firestore:rules
    firebase deploy --project ID_DO_PROJETO --only functions

Verifique a carga:

    node firebase/functions/seed.js ID_DO_PROJETO --dry-run

Para gravar, autorize Application Default Credentials com permissão no projeto, por exemplo com gcloud auth application-default login em uma sessão controlada, e execute:

    node firebase/functions/seed.js ID_DO_PROJETO --confirmar

A transação só preenche o catálogo vazio e protege registros existentes. Os códigos e nomes foram selecionados do CSV fornecido. O dry-run verifica unicidade e dígito de controle. A confirmação independente da marca e apresentação com fabricantes não integra o dry-run.

Compile o modo compartilhado somente após configurar o projeto Android:

    flutter run --dart-define=MOVIMENTA_FIREBASE=true
    flutter build apk --release --dart-define=MOVIMENTA_FIREBASE=true

### Testar com Firebase Emulator

    npm ci --prefix firebase/functions
    firebase emulators:exec --project demo-movimenta --only auth,firestore,functions "node firebase/functions/emulador.test.js"

Para conectar o app Android aos emuladores em execução:

    firebase emulators:start --project demo-movimenta --only auth,firestore,functions
    flutter run --dart-define=MOVIMENTA_FIREBASE=true --dart-define=MOVIMENTA_FIREBASE_EMULADOR=true

O Android Emulator acessa o host por 10.0.2.2. Use MOVIMENTA_FIREBASE_HOST se precisar de outro endereço. Google real requer um projeto configurado e uma assinatura cadastrada.

## Verificar a atualização em um Android

1. Faça um backup da instalação anterior. Instale o APK atualizado sobre ela e confira códigos, quantidades, validades e os locais Loja e Estoque. O modo compartilhado mantém seus dados anteriores separados, em **Estoque deste aparelho**, acessível ao dono. Nenhuma migração automática envia dados locais à nuvem.
2. Teste e-mail/senha, recuperação e Google. Crie um mercado, copie o convite, solicite acesso em outra conta e aprove em **Minha Equipe**. Confira que a conta só vê seu mercado.
3. Em **Nova entrada**, use o catálogo, bipe ou fotografe a embalagem. Converta dois fardos com seis unidades em doze unidades. Confira se o código corresponde à unidade ou à caixa.
4. Fotografe a validade e uma etiqueta com preço normal e de atacado. Escolha os valores, confirme uma entrada e confira os lotes. Repita com outra validade e confirme que o lote anterior permanece.
5. No Android, autorize a câmera para o leitor e a captura. Teste sem rede: confira a indicação de entrada pendente, reconecte e toque em Sincronizar. A reapresentação do mesmo identificador não incrementa o estoque duas vezes.
