import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLocalStorage();
  runApp(const CoinListView());
}
