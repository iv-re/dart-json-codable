import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:json_codable/json_codable.dart';

import 'dataset_generator.dart';

/// Captures benchmark measurement results.
class BenchmarkResult {
  BenchmarkResult({
    required this.scenarioName,
    required this.task,
    required this.byteSize,
    required this.stdUs,
    required this.codableUs,
  });

  final String scenarioName;
  final String task;
  final int byteSize;
  final double stdUs;
  final double codableUs;

  double get speedup => stdUs / codableUs;
  double get stdOpsPerSec => 1000000.0 / stdUs;
  double get codableOpsPerSec => 1000000.0 / codableUs;

  double get stdMbPerSec => (byteSize / (1024 * 1024)) / (stdUs / 1000000.0);
  double get codableMbPerSec =>
      (byteSize / (1024 * 1024)) / (codableUs / 1000000.0);
}

/// Utility for tracking score outputs without printing standard
/// benchmark_harness lines directly.
class SilentEmitter implements ScoreEmitter {
  double value = 0;

  @override
  void emit(String testName, double value) {
    this.value = value;
  }
}

// -----------------------------------------------------------------------------
// ENCODING BENCHMARKS (json.encoder.fuse(utf8.encoder) vs JsonWriter)
// -----------------------------------------------------------------------------

class EncodingStdBenchmark extends BenchmarkBase {
  EncodingStdBenchmark(this.dataset, SilentEmitter emitter)
    : super('StdEncoding_${dataset.name}', emitter: emitter);

  final BenchmarkDataset<ToJson> dataset;

  @override
  void run() {
    stdJsonEncoder.convert(dataset.dartMap);
  }
}

class EncodingJsonWriterBenchmark<T extends ToJson> extends BenchmarkBase {
  EncodingJsonWriterBenchmark(this.dataset, SilentEmitter emitter)
    : super('JsonWriterEncoding_${dataset.name}', emitter: emitter);

  final BenchmarkDataset<T> dataset;

  @override
  void run() {
    final model = dataset.singleModel;
    final list = dataset.modelList;
    if (model != null) {
      JsonWriter.encode(model.toJson);
    } else if (list != null) {
      JsonWriter.encode(
        (w) => w.list<T>(
          'items',
          list,
          mapper: (w, item) => item.toJson(w),
        ),
      );
    }
  }
}

// -----------------------------------------------------------------------------
// DECODING BENCHMARKS (utf8.decoder.fuse(json.decoder) vs JsonReader)
// -----------------------------------------------------------------------------

class DecodingStdBenchmark<T extends ToJson> extends BenchmarkBase {
  DecodingStdBenchmark(this.dataset, this.mapper, SilentEmitter emitter)
    : super('StdDecoding_${dataset.name}', emitter: emitter);

  final BenchmarkDataset<T> dataset;
  final T Function(Map<String, Object?> map) mapper;

  @override
  void run() {
    final decoded =
        stdJsonDecoder.convert(dataset.utf8Bytes) as Map<String, dynamic>?;
    if (decoded == null) return;

    if (dataset.singleModel != null) {
      mapper(decoded);
    } else {
      final list = decoded['items'] as List<Object?>?;
      if (list == null) return;

      for (var i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>?;
        if (item != null) {
          mapper(item);
        }
      }
    }
  }
}

class DecodingJsonReaderBenchmark<T extends ToJson> extends BenchmarkBase {
  DecodingJsonReaderBenchmark(this.dataset, this.mapper, SilentEmitter emitter)
    : super('JsonReaderDecoding_${dataset.name}', emitter: emitter);

  final BenchmarkDataset<T> dataset;
  final T Function(JsonReader reader) mapper;

  @override
  void run() {
    final reader = JsonReader(dataset.utf8Bytes);
    if (dataset.singleModel != null) {
      mapper(reader);
    } else {
      reader.readList<T>('items', mapper);
    }
  }
}
