import 'dart:io';

import 'package:json_codable/json_codable.dart';

import 'benchmarks.dart';
import 'dataset_generator.dart';

void main() {
  stdout.writeln('=' * 80);
  stdout.writeln(
    '        json_codable Performance Benchmark Suite (benchmark_harness)',
  );
  stdout.writeln('=' * 80);
  final sdkVersion = Platform.version.split(' ').first;
  stdout.writeln('Environment: Dart SDK $sdkVersion');
  stdout.writeln('Preparing real-world datasets...');

  final authData = BenchmarkDataset.authResponse();
  final profileData = BenchmarkDataset.userProfile();
  final productFeed = BenchmarkDataset.productFeed();
  final logEvents = BenchmarkDataset.logEvents();
  final syncDump = BenchmarkDataset.syncDump();

  stdout.writeln('Datasets initialized successfully:');
  stdout.writeln('  - ${authData.name}: ${authData.byteSize} bytes');
  stdout.writeln('  - ${profileData.name}: ${profileData.byteSize} bytes');
  stdout.writeln('  - ${productFeed.name}: ${productFeed.byteSize} bytes');
  stdout.writeln('  - ${logEvents.name}: ${logEvents.byteSize} bytes');
  stdout.writeln('  - ${syncDump.name}: ${syncDump.byteSize} bytes');
  stdout.writeln('-' * 80);

  final emitter = SilentEmitter();

  // Run Encoding Benchmarks
  stdout.writeln('\n>>> Running ENCODING Benchmarks...');

  final encodingResults = <BenchmarkResult>[
    _measureEncoding<AuthResponseModel>(authData, emitter),
    _measureEncoding<UserProfileModel>(profileData, emitter),
    _measureEncoding<ProductModel>(productFeed, emitter),
    _measureEncoding<LogEventModel>(logEvents, emitter),
    _measureEncoding<SyncItemModel>(syncDump, emitter),
  ];

  _printTable(
    'ENCODING PERFORMANCE (dart:convert Fused vs JsonWriter)',
    encodingResults,
  );

  // Run Decoding Benchmarks
  stdout.writeln('\n>>> Running DECODING Benchmarks...');

  final decodingResults = <BenchmarkResult>[
    _measureDecoding<AuthResponseModel>(
      authData,
      AuthResponseModel.fromDartMap,
      AuthResponseModel.fromJsonReader,
      emitter,
    ),
    _measureDecoding<UserProfileModel>(
      profileData,
      UserProfileModel.fromDartMap,
      UserProfileModel.fromJsonReader,
      emitter,
    ),
    _measureDecoding<ProductModel>(
      productFeed,
      ProductModel.fromDartMap,
      ProductModel.fromJsonReader,
      emitter,
    ),
    _measureDecoding<LogEventModel>(
      logEvents,
      LogEventModel.fromDartMap,
      LogEventModel.fromJsonReader,
      emitter,
    ),
    _measureDecoding<SyncItemModel>(
      syncDump,
      SyncItemModel.fromDartMap,
      SyncItemModel.fromJsonReader,
      emitter,
    ),
  ];

  _printTable(
    'DECODING PERFORMANCE (dart:convert Fused vs JsonReader)',
    decodingResults,
  );

  stdout.writeln('\n${'=' * 80}');
  stdout.writeln('Benchmark execution completed cleanly.');
  stdout.writeln('=' * 80);
}

BenchmarkResult _measureEncoding<T extends ToJson>(
  BenchmarkDataset<T> dataset,
  SilentEmitter emitter,
) {
  stdout.write('  [Encoding] Measuring ${dataset.name}... ');

  final stdBench = EncodingStdBenchmark(dataset, emitter);
  stdBench.report();
  final stdUs = emitter.value;

  final codableBench = EncodingJsonWriterBenchmark<T>(dataset, emitter);
  codableBench.report();
  final codableUs = emitter.value;

  stdout.writeln('Done.');

  return BenchmarkResult(
    scenarioName: dataset.name,
    task: 'Encoding',
    byteSize: dataset.byteSize,
    stdUs: stdUs,
    codableUs: codableUs,
  );
}

BenchmarkResult _measureDecoding<T extends ToJson>(
  BenchmarkDataset<T> dataset,
  T Function(Map<String, Object?> map) stdMapper,
  T Function(JsonReader reader) codableMapper,
  SilentEmitter emitter,
) {
  stdout.write('  [Decoding] Measuring ${dataset.name}... ');

  final stdBench = DecodingStdBenchmark<T>(dataset, stdMapper, emitter);
  stdBench.report();
  final stdUs = emitter.value;

  final codableBench = DecodingJsonReaderBenchmark<T>(
    dataset,
    codableMapper,
    emitter,
  );
  codableBench.report();
  final codableUs = emitter.value;

  stdout.writeln('Done.');

  return BenchmarkResult(
    scenarioName: dataset.name,
    task: 'Decoding',
    byteSize: dataset.byteSize,
    stdUs: stdUs,
    codableUs: codableUs,
  );
}

void _printTable(String title, List<BenchmarkResult> results) {
  stdout.writeln('\n=== $title ===\n');
  stdout.writeln(
    '| Payload Scenario | Payload Size | Dart std (us) | '
    'json_codable (us) | std (MB/s) | codable (MB/s) | Speedup Ratio |',
  );
  stdout.writeln(
    '|:-----------------|:-------------|--------------:|'
    '------------------:|-----------:|---------------:|--------------:|',
  );

  for (final res in results) {
    final speedupStr = res.speedup >= 1.0
        ? '\x1B[32m${res.speedup.toStringAsFixed(2)}x FASTER\x1B[0m'
        : '\x1B[31m${(1 / res.speedup).toStringAsFixed(2)}x slower\x1B[0m';

    final sizeStr = _formatSize(res.byteSize);
    final stdMbStr = res.stdMbPerSec >= 1.0
        ? res.stdMbPerSec.toStringAsFixed(1)
        : res.stdMbPerSec.toStringAsFixed(3);
    final codableMbStr = res.codableMbPerSec >= 1.0
        ? res.codableMbPerSec.toStringAsFixed(1)
        : res.codableMbPerSec.toStringAsFixed(3);

    final namePadded = res.scenarioName.padRight(16);
    final sizePadded = sizeStr.padLeft(12);
    final stdUsPadded = res.stdUs.toStringAsFixed(1).padLeft(13);
    final codableUsPadded = res.codableUs.toStringAsFixed(1).padLeft(17);
    final stdMbPadded = stdMbStr.padLeft(10);
    final codableMbPadded = codableMbStr.padLeft(14);
    final speedupPadded = speedupStr.padLeft(13);

    stdout.writeln(
      '| $namePadded | $sizePadded | $stdUsPadded | $codableUsPadded | '
      '$stdMbPadded | $codableMbPadded | $speedupPadded |',
    );
  }
}

String _formatSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  } else if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
