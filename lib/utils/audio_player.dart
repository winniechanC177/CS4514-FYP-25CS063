import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

class AudioPlayer extends StatefulWidget {
  final Int16List soundData;

  const AudioPlayer({super.key, required this.soundData});

  @override
  AudioPlayerState createState() => AudioPlayerState();
}

class AudioPlayerState extends State<AudioPlayer> {
  static const int sampleRate = 24000;
  bool _isPlaying = false;
  Timer? _stopTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    FlutterPcmSound.release();
    super.dispose();
  }

  void _initializePlayer() {
    FlutterPcmSound.setLogLevel(LogLevel.error);
    FlutterPcmSound.setup(sampleRate: sampleRate, channelCount: 1);
    FlutterPcmSound.setFeedThreshold(sampleRate ~/ 10);
    FlutterPcmSound.setFeedCallback((_) {});
  }

  Future<void> _play() async {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);

    FlutterPcmSound.start();
    await FlutterPcmSound.feed(PcmArrayInt16.fromList(widget.soundData));

    final durationMs = (widget.soundData.length / sampleRate * 1000).round();
    _stopTimer?.cancel();
    _stopTimer = Timer(Duration(milliseconds: durationMs), _stop);
  }

  void _stop() {
    if (!_isPlaying) return;
    _stopTimer?.cancel();
    FlutterPcmSound.release();
    _initializePlayer();
    setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isPlaying ? _stop : _play,
      child: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
    );
  }
}
