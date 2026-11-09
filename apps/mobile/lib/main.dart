import 'package:flutter/material.dart';

import 'api.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const base = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://127.0.0.1:4317',
  );
  runApp(BilloApp(api: HttpBilloApi(base)));
}
