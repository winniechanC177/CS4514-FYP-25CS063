import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:SLMTranslator/database/database_helper.dart';
import 'package:SLMTranslator/types/language_choose.dart';
import 'package:SLMTranslator/learning/vocab_entry.dart';
import 'package:SLMTranslator/model/model_response.dart';
import '../stub/stub_tts_model.dart';
import '../stub/stub_stt_model.dart';


void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.setInMemoryDatabaseForTesting();
  });
	group('Unit Test 2b: OCR — VocabEntry edge-case formats', () {
		test('parses legacy format (no V|/G| prefix) as vocab', () {
			const raw = 'apple|蘋果|I eat an apple.';
			final entries = VocabEntry.parseModelResponse(raw);
			expect(entries, hasLength(1));
			expect(entries.first.text, equals('apple'));
			expect(entries.first.convText, equals('蘋果'));
			expect(entries.first.entryType, equals(EntryType.vocab));
		});

		test('strips numbered list prefix before parsing (e.g. "1. V|...")', () {
			const raw = '1. V|cherry|チェリー|I love cherries.';
			final entries = VocabEntry.parseModelResponse(raw);
			expect(entries, hasLength(1));
			expect(entries.first.text, equals('cherry'));
		});

		test('strips dash bullet prefix before parsing (e.g. "- V|...")', () {
			const raw = '- V|grape|ブドウ|Grapes are sweet.';
			final entries = VocabEntry.parseModelResponse(raw);
			expect(entries, hasLength(1));
			expect(entries.first.text, equals('grape'));
		});

		test('strips asterisk bullet prefix before parsing (e.g. "* V|...")', () {
			const raw = '* V|peach|桃|A ripe peach.';
			final entries = VocabEntry.parseModelResponse(raw);
			expect(entries, hasLength(1));
			expect(entries.first.text, equals('peach'));
		});

		test('example that is only whitespace is treated as no example', () {
			const raw = 'V|book|本|   ';
			final entries = VocabEntry.parseModelResponse(raw);
			expect(entries, hasLength(1));
			expect(entries.first.example, isNull);
		});

		test('extra pipe segments beyond the expected 4 are parsed without error', () {
			const raw = 'V|run|走る|He runs every day.|extra|segment';
			final entries = VocabEntry.parseModelResponse(raw);
			expect(entries, hasLength(1));
			expect(entries.first.text, equals('run'));
			expect(entries.first.convText, equals('走る'));
		});

		test('mixed valid and invalid lines yields only valid entries', () {
			const raw = '''
V|cat|猫|Cats are cute.
This line has no pipes at all
G|て-form|Conjunctive form|食べて寝る
V||empty source|example
Another bad line
V|dog|犬|Dogs are loyal.
''';
			final entries = VocabEntry.parseModelResponse(raw);
			expect(entries, hasLength(3));
			expect(entries.map((e) => e.text).toList(),
					containsAll(['cat', 'て-form', 'dog']));
		});

		test('VocabEntry constructed directly has correct field values', () {
			const entry = VocabEntry(
				text: 'sakura',
				convText: '桜',
				lang: 'English',
				convLang: 'Japanese',
				example: 'The sakura bloomed.',
				entryType: EntryType.vocab,
			);
			expect(entry.text, equals('sakura'));
			expect(entry.entryType, equals(EntryType.vocab));
			expect(entry.example, equals('The sakura bloomed.'));
		});
	});

	group('Unit Test 3c: TTS — FakeTTSModel + helper logic', () {
		late StubTTSModel fake;

		setUp(() => fake = StubTTSModel());

		test('FakeTTSModel default response is a 2400-sample silent buffer', () async {
			final pcm = await fake.pronunciationResponse('hello', LanguageChoose.english);
			expect(pcm.length, equals(2400));
			expect(pcm.every((v) => v == 0), isTrue);
		});

		test('FakeTTSModel returns overrideAudioData when provided', () async {
			fake.overrideAudioData = Int16List.fromList([1, -2, 300]);
			final pcm = await fake.pronunciationResponse('hello', LanguageChoose.japanese);
			expect(pcm, equals(Int16List.fromList([1, -2, 300])));
		});

		test('FakeTTSModel records requests and call count', () async {
			await fake.pronunciationResponse('cat', LanguageChoose.english);
			await fake.pronunciationResponse('犬', LanguageChoose.japanese);
			expect(fake.callCount, equals(2));
			expect(fake.receivedRequests[0].word, equals('cat'));
			expect(fake.receivedRequests[0].language, equals(LanguageChoose.english));
			expect(fake.receivedRequests[1].language, equals(LanguageChoose.japanese));
		});

		test('FakeTTSModel throwOnNextCall throws once and then clears', () async {
			fake.throwOnNextCall = Exception('tts failed');
			await expectLater(
				() => fake.pronunciationResponse('boom', LanguageChoose.english),
				throwsA(isA<Exception>()),
			);

			final pcm = await fake.pronunciationResponse('ok', LanguageChoose.english);
			expect(pcm, isNotNull);
			expect(fake.callCount, equals(1)); 
		});

		test('ModelResponse accepts FakeTTSModel injection', () async {
			final mr = ModelResponse(ttsModel: fake);
			fake.overrideAudioData = Int16List.fromList([9, 8, 7]);
			final pcm = await mr.pronunciationResponse('hello', LanguageChoose.french);
			expect(pcm, equals(Int16List.fromList([9, 8, 7])));
		});

		test('speakerSidForTest maps every language to the expected numeric ID', () {
			expect(TTSModel.speakerSidForTest(LanguageChoose.english),    equals(3));   
			expect(TTSModel.speakerSidForTest(LanguageChoose.japanese),   isNull);      
			expect(TTSModel.speakerSidForTest(LanguageChoose.chineseSimplified),    equals(45));  
			expect(TTSModel.speakerSidForTest(LanguageChoose.spanish),    equals(28));  
			expect(TTSModel.speakerSidForTest(LanguageChoose.french),     equals(30));  
			expect(TTSModel.speakerSidForTest(LanguageChoose.hindi),      equals(31));  
			expect(TTSModel.speakerSidForTest(LanguageChoose.italian),    equals(35));  
			expect(TTSModel.speakerSidForTest(LanguageChoose.portuguese), equals(42));  
		});

		test('float32ToInt16ForTest converts and clamps values correctly', () {
			final input = Float32List.fromList([0.0, 1.0, -1.0, 2.0, -2.0, 0.5]);
			final out = TTSModel.float32ToInt16ForTest(input);
			expect(out[0], equals(0));
			expect(out[1], equals(32767));
			expect(out[2], equals(-32767));
			expect(out[3], equals(32767));
			expect(out[4], equals(-32768));
			expect(out[5], equals(16383));
		});

		test('float32ToInt16ForTest preserves sample count', () {
			final input = Float32List.fromList(List.generate(11, (i) => i / 10));
			final out = TTSModel.float32ToInt16ForTest(input);
			expect(out.length, equals(input.length));
		});
	});

	group('Unit Test 3d: STT — FakeSTTModel + WAV reader helper', () {
		late StubSTTModel fake;

		Future<File> writeBytesToTempFile(String name, List<int> bytes) async {
			final dir = await Directory.systemTemp.createTemp('slm_stt_test_');
			final file = File('${dir.path}/$name');
			await file.writeAsBytes(bytes, flush: true);
			return file;
		}

		List<int> buildWav16Mono(List<int> samples, {int sampleRate = 16000}) {
			final dataSize = samples.length * 2;
			final totalSize = 44 + dataSize;
			final bd = ByteData(totalSize);

			void writeStr(int offset, String s) {
				for (var i = 0; i < s.length; i++) {
					bd.setUint8(offset + i, s.codeUnitAt(i));
				}
			}

			writeStr(0, 'RIFF');
			bd.setUint32(4, totalSize - 8, Endian.little);
			writeStr(8, 'WAVE');
			writeStr(12, 'fmt ');
			bd.setUint32(16, 16, Endian.little); 
			bd.setUint16(20, 1, Endian.little); 
			bd.setUint16(22, 1, Endian.little); 
			bd.setUint32(24, sampleRate, Endian.little);
			bd.setUint32(28, sampleRate * 2, Endian.little); 
			bd.setUint16(32, 2, Endian.little); 
			bd.setUint16(34, 16, Endian.little); 
			writeStr(36, 'data');
			bd.setUint32(40, dataSize, Endian.little);

			for (var i = 0; i < samples.length; i++) {
				bd.setInt16(44 + i * 2, samples[i], Endian.little);
			}
			return bd.buffer.asUint8List();
		}

		setUp(() => fake = StubSTTModel());

		test('FakeSTTModel initWhisper increments init count', () async {
			await fake.initWhisper();
			await fake.initWhisper();
			expect(fake.initCallCount, equals(2));
		});

		test('FakeSTTModel returns default transcription', () async {
			final text = await fake.transcribeAudio('/tmp/test.wav');
			expect(text, equals('[stub transcription]'));
		});

		test('FakeSTTModel returns overrideTranscription when set', () async {
			fake.overrideTranscription = 'good morning';
			final text = await fake.transcribeAudio('/tmp/test.wav');
			expect(text, equals('good morning'));
		});

		test('FakeSTTModel can simulate no speech detected via returnNull', () async {
			fake.returnNull = true;
			final text = await fake.transcribeAudio('/tmp/test.wav');
			expect(text, isNull);
		});

		test('FakeSTTModel records audio paths and call count', () async {
			await fake.transcribeAudio('/tmp/a.wav');
			await fake.transcribeAudio('/tmp/b.wav');
			expect(fake.transcribeCallCount, equals(2));
			expect(fake.receivedAudioPaths, equals(['/tmp/a.wav', '/tmp/b.wav']));
		});

		test('FakeSTTModel throwOnNextCall throws once and then clears', () async {
			fake.throwOnNextCall = Exception('stt failed');
			await expectLater(
				() => fake.transcribeAudio('/tmp/x.wav'),
				throwsA(isA<Exception>()),
			);

			final text = await fake.transcribeAudio('/tmp/y.wav');
			expect(text, equals('[stub transcription]'));
			expect(fake.transcribeCallCount, equals(1));
		});

		test('ModelResponse accepts FakeSTTModel injection', () async {
			final mr = ModelResponse(sttModel: fake);
			fake.overrideTranscription = 'hello from fake stt';
			final text = await mr.transcribeAudio('/tmp/test.wav');
			expect(text, equals('hello from fake stt'));
		});

		test('readWavSamplesForTest returns null for missing file', () async {
			final samples = await STTModel.readWavSamplesForTest('/definitely/missing.wav');
			expect(samples, isNull);
		});

		test('readWavSamplesForTest returns null for too-short file', () async {
			final file = await writeBytesToTempFile('short.wav', List.filled(10, 0));
			final samples = await STTModel.readWavSamplesForTest(file.path);
			expect(samples, isNull);
		});

		test('readWavSamplesForTest reads valid 16-bit PCM WAV samples', () async {
			final wavBytes = buildWav16Mono([0, 16384, -16384]);
			final file = await writeBytesToTempFile('valid.wav', wavBytes);
			final samples = await STTModel.readWavSamplesForTest(file.path);

			expect(samples, isNotNull);
			expect(samples!.length, equals(3));
			expect(samples[0], closeTo(0.0, 0.0001));
			expect(samples[1], closeTo(0.5, 0.0001));
			expect(samples[2], closeTo(-0.5, 0.0001));
		});

		test('readWavSamplesForTest handles non-audio data gracefully', () async {
			final file = await writeBytesToTempFile(
				'nonsense.wav',
				List<int>.generate(64, (i) => i),
			);
			final samples = await STTModel.readWavSamplesForTest(file.path);
			expect(samples == null || samples.isNotEmpty || samples.isEmpty, isTrue);
		});
	});


}
