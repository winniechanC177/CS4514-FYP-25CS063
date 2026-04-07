import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../home/home_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ModelDownloader extends StatefulWidget {
  const ModelDownloader({super.key});

  @override
  State<ModelDownloader> createState() => _ModelDownloaderState();
}

class _ModelDownloaderState extends State<ModelDownloader> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _downloadModel();
    });
  }

  Future<void> _downloadModel() async {
    final token = dotenv.env['HF_TOKEN'] ?? '';
    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
    ).fromNetwork(
      "https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task",
      token: token,
    ).withProgress((progress) {
      if (mounted) {
        setState(() => _progress = progress.toDouble());
      }
    }).install();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Progress: ${(_progress).toStringAsFixed(1)}%'),
    );
  }
}

class NextPage extends StatelessWidget {
  const NextPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Download Complete!')),
    );
  }
}
