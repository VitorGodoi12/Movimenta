import 'package:stokio/theme/tema_preferencia.dart';
import 'package:flutter/material.dart';
import 'package:stokio/app.dart';
import 'package:stokio/services/notificacoes.dart';
import 'package:stokio/services/armazenamento.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/perfil_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Armazenamento.iniciar();
  TemaPreferencia.carregar();
  await perfil.carregar();
  await estoque.carregar();
  Notificacoes.iniciar();
  runApp(const StokioApp());
}
