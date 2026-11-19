import 'package:flutter/material.dart';
import 'package:movimenta/app.dart';
import 'package:movimenta/services/armazenamento.dart';
import 'package:movimenta/services/estoque_service.dart';
import 'package:movimenta/services/perfil_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Armazenamento.iniciar();
  await perfil.carregar();
  await estoque.carregar();
  runApp(const MovimentaApp());
}
