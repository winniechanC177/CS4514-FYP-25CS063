import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' hide ModelResponse;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'database/database_helper.dart' as dbHelper;
import 'model/model_download.dart';
import 'model/model_response.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('.env file not found or failed to load: $e');
  }

  sherpa.initBindings();

  try {
    await FlutterGemma.initialize();
  } catch (e) {
    debugPrint('FlutterGemma.initialize() failed: $e');
  }

  await dbHelper.DatabaseHelper.instance.database;
  ModelResponse.initTtsOnce();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ModelResponse _modelResponse = ModelResponse();

  @override
  void dispose() {
    try {
      _modelResponse.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: ModelDownloader()),
      ),
    );
  }
}
