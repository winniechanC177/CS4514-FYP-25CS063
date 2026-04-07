import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../model/model_response.dart' as modelResponse;
import '../types/language_choose.dart';
import 'bleu_score.dart';
import 'bleu_dataset.dart';

int _currentRssBytes() => ProcessInfo.currentRss;

String _fmtMb(int bytes) =>
    '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

class _PeakSampler {
  int _peak = _currentRssBytes();
  late final Timer _timer;

  _PeakSampler({int intervalMs = 200}) {
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      final c = _currentRssBytes();
      if (c > _peak) _peak = c;
    });
  }

  int stop() {
    _timer.cancel();
    return _peak;
  }
}

class BenchmarkResult {
  final TranslationSample sample;
  final String hypothesis;
  final int latencyMs;
  final double bleu;
  final int peakRamBytes;

  const BenchmarkResult({
    required this.sample,
    required this.hypothesis,
    required this.latencyMs,
    required this.bleu,
    required this.peakRamBytes,
  });
}

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  final _model = modelResponse.ModelResponse();
  final List<BenchmarkResult> _results = [];
  bool _running = false;
  int _currentIndex = 0;
  String? _currentSource;
  bool _useMemory = true;
  bool? _resultsUsedMemory;

  String _short(String s, [int n = 80]) =>
      s.length <= n ? s : '${s.substring(0, n)}...';

  Future<void> _runBenchmark() async {
    final useMemory = _useMemory;
    setState(() {
      _results.clear();
      _running = true;
      _currentIndex = 0;
      _currentSource = null;
      _resultsUsedMemory = null;
    });

    for (int i = 0; i < allDatasets.length; i++) {
      if (!mounted) break;
      final sample = allDatasets[i];
      setState(() {
        _currentIndex = i + 1;
        _currentSource = sample.source;
      });

      final srcLang = LanguageChoose.tryParse(sample.language) ?? LanguageChoose.english;
      final dstLang = LanguageChoose.tryParse(sample.convLanguage) ?? LanguageChoose.chineseTraditional;

      final peakSampler = _PeakSampler();
      final sw = Stopwatch()..start();

      debugPrint('Benchmark ${i + 1}/${allDatasets.length}: "${_short(sample.source)}"');

      final hyp = await _model.translateResponse(
        srcLang,
        dstLang,
        sample.source,
        translationMemory: useMemory ? null : '',
      );

      sw.stop();
      final peakRam = peakSampler.stop();

      final bleu = BleuScore.sentenceBleu(
        hyp, sample.references, maxN: 2, language: sample.convLanguage,
      );

      if (!mounted) break;
      setState(() {
        _results.add(BenchmarkResult(
          sample: sample,
          hypothesis: hyp,
          latencyMs: sw.elapsedMilliseconds,
          bleu: bleu,
          peakRamBytes: peakRam,
        ));
      });
    }

    if (mounted) {
      setState(() {
      _running = false;
      _resultsUsedMemory = useMemory;
    });
    }
  }


  double get _corpusBleu {
    if (_results.isEmpty) return 0;
    return BleuScore.corpusBleu(
      _results.map((r) => r.hypothesis).toList(),
      _results.map((r) => r.sample.references).toList(),
      maxN: 2,
    );
  }

  double get _avgLatency => _results.isEmpty
      ? 0
      : _results.map((r) => r.latencyMs).reduce((a, b) => a + b) / _results.length;

  int get _totalMs => _results.isEmpty
      ? 0
      : _results.map((r) => r.latencyMs).reduce((a, b) => a + b);

  int get _avgPeakRam => _results.isEmpty
      ? 0
      : (_results.map((r) => r.peakRamBytes).reduce((a, b) => a + b) / _results.length).round();

  Map<String, List<BenchmarkResult>> get _byLanguagePair {
    final map = <String, List<BenchmarkResult>>{};
    for (final r in _results) {
      map.putIfAbsent('${r.sample.language} → ${r.sample.convLanguage}', () => []).add(r);
    }
    return map;
  }

  double _pairCorpusBleu(List<BenchmarkResult> results) {
    if (results.isEmpty) return 0;
    return BleuScore.corpusBleu(
      results.map((r) => r.hypothesis).toList(),
      results.map((r) => r.sample.references).toList(),
      maxN: 2,
      language: results.first.sample.convLanguage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = allDatasets.length;
    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: _running
          ? null
          : FloatingActionButton(
              onPressed: _runBenchmark,
              tooltip: 'Run benchmark',
              child: const Icon(Icons.play_arrow),
            ),
      body: Column(
        children: [
          if (!_running)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('Translation memory'),
                  const Spacer(),
                  Switch(
                    value: _useMemory,
                    onChanged: (v) => setState(() => _useMemory = v),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _useMemory ? 'On' : 'Off',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

          if (_running) ...[
            LinearProgressIndicator(value: _currentIndex / total),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text('Running $_currentIndex / $total',
                      style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  if (_currentSource != null)
                    Flexible(
                      child: Text('"$_currentSource"',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          ],

          if (_results.isEmpty && !_running)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Press ▶ to run the benchmark\n'
                      '${allDatasets.length} samples · EN→JA + EN→ZH\n'
                      'Measures: time · RAM',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

          if (_results.isNotEmpty)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _SummaryCard(
                    corpusBleu: _corpusBleu,
                    avgLatency: _avgLatency,
                    totalMs: _totalMs,
                    sampleCount: _results.length,
                    avgPeakRamBytes: _avgPeakRam,
                    byPair: _byLanguagePair,
                    pairCorpusBleu: _pairCorpusBleu,
                    usedMemory: _resultsUsedMemory,
                  ),
                  const SizedBox(height: 12),
                  ..._results.map((r) => _SampleRow(result: r)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


class _SummaryCard extends StatelessWidget {
  final double corpusBleu;
  final double avgLatency;
  final int totalMs;
  final int sampleCount;
  final int avgPeakRamBytes;
  final Map<String, List<BenchmarkResult>> byPair;
  final double Function(List<BenchmarkResult>) pairCorpusBleu;
  final bool? usedMemory;

  const _SummaryCard({
    required this.corpusBleu,
    required this.avgLatency,
    required this.totalMs,
    required this.sampleCount,
    required this.avgPeakRamBytes,
    required this.byPair,
    required this.pairCorpusBleu,
    required this.usedMemory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Summary ($sampleCount samples)',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                if (usedMemory != null)
                  Chip(
                    label: Text(usedMemory! ? 'Memory On' : 'Memory Off',
                        style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: usedMemory!
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                  ),
              ],
            ),
            const Divider(),
            _StatRow('Corpus BLEU-2', '${BleuScore.format(corpusBleu)}%'),
            _StatRow('Avg latency',   '${avgLatency.toStringAsFixed(0)} ms'),
            _StatRow('Total time',    '$totalMs ms  (${(totalMs / 1000).toStringAsFixed(1)} s)'),
            _StatRow('Avg peak RAM',  _fmtMb(avgPeakRamBytes)),
            const SizedBox(height: 8),
            ...byPair.entries.map((e) {
              final pBleu = pairCorpusBleu(e.value);
              final pAvg  = e.value.map((r) => r.latencyMs).reduce((a, b) => a + b) / e.value.length;
              return _StatRow(
                '${e.key}  (${e.value.length})',
                'BLEU ${BleuScore.format(pBleu)}%  ·  ${pAvg.toStringAsFixed(0)} ms',
              );
            }),
          ],
        ),
      ),
    );
  }
}


class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}


class _SampleRow extends StatelessWidget {
  final BenchmarkResult result;
  const _SampleRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(result.sample.source,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Text(
                  '${result.sample.language} → ${result.sample.convLanguage}',
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(result.hypothesis, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Ref: ${result.sample.references.join(' / ')}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              'BLEU ${BleuScore.format(result.bleu)}%  ·  '
              '${result.latencyMs} ms  ·  '
              '${_fmtMb(result.peakRamBytes)} peak',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
