import 'package:flutter/material.dart';
import 'package:stokio/app.dart';
import 'package:stokio/services/armazenamento.dart';
import 'package:stokio/services/estoque_service.dart';
import 'package:stokio/services/perfil_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Armazenamento.iniciar();
  await perfil.carregar();
  await estoque.carregar();
  runApp(const StokioApp());
}
