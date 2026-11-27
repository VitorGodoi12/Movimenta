import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class MercadoFirebase {
  static bool ativo = false;
  static String? erroInicializacao;
  static const habilitado = bool.fromEnvironment('MOVIMENTA_FIREBASE');
  static const emulador = bool.fromEnvironment('MOVIMENTA_FIREBASE_EMULADOR');
  static const hostEmulador = String.fromEnvironment(
    'MOVIMENTA_FIREBASE_HOST',
    defaultValue: '10.0.2.2',
  );

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get banco => FirebaseFirestore.instance;
  static FirebaseFunctions get funcoes => FirebaseFunctions.instance;

  static Future<void> iniciar() async {
    if (!habilitado) return;
    try {
      await Firebase.initializeApp(
        options: emulador
            ? const FirebaseOptions(
                apiKey: 'demo-key',
                appId: '1:1234567890:android:0123456789abcdef',
                messagingSenderId: '1234567890',
                projectId: 'demo-movimenta',
              )
            : null,
      );
      if (emulador) {
        await auth.useAuthEmulator(hostEmulador, 9099);
        banco.useFirestoreEmulator(hostEmulador, 8080);
        funcoes.useFunctionsEmulator(hostEmulador, 5001);
      }
      ativo = true;
    } on Exception catch (erro) {
      erroInicializacao = erro.toString();
    }
  }

  static Future<void> entrarGoogle() async {
    if (kIsWeb) {
      await auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    await GoogleSignIn.instance.initialize();
    final conta = await GoogleSignIn.instance.authenticate();
    final token = conta.authentication.idToken;
    if (token == null)
      throw StateError('O Google não retornou uma credencial.');
    await auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: token),
    );
  }

  static Future<dynamic> chamar(
    String operacao,
    Map<String, dynamic> dados,
  ) async => (await funcoes.httpsCallable(operacao).call<dynamic>(dados)).data;

  static DocumentReference<Map<String, dynamic>> usuario(String uid) =>
      banco.collection('users').doc(uid);

  static DocumentReference<Map<String, dynamic>> mercado(String id) =>
      banco.collection('mercados').doc(id);
}
