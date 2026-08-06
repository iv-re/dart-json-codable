import 'dart:convert';
import 'dart:typed_data';

/// Exception thrown by [JsonReader] when a field is present and non-null,
/// but its JSON token type does not match the expected type.
class JsonTypeMismatchException implements Exception {
  const JsonTypeMismatchException(
    this.key, {
    required this.expected,
    required this.actual,
  });

  /// The field key in the JSON object.
  final String key;

  /// The expected JSON type name (e.g. `'string'`, `'integer'`, `'float'`,
  /// `'boolean'`, `'object'`, `'list'`).
  final String expected;

  /// The actual JSON value or type encountered.
  final Object? actual;

  @override
  String toString() =>
      'JsonTypeMismatchException(key: "$key", expected: "$expected", '
      'actual: $actual)';
}

/// Exception thrown by [JsonReader] when encountering malformed JSON syntax.
class JsonSyntaxException implements Exception {
  const JsonSyntaxException(this.message, {this.offset});

  /// Error message describing the syntax violation.
  final String message;

  /// Optional byte offset where the error occurred.
  final int? offset;

  @override
  String toString() =>
      'JsonSyntaxException: $message'
      '${offset != null ? ' at offset $offset' : ''}';
}

/// A low-level JSON reader over UTF-8 encoded bytes.
///
/// Serves as the underlying data source for `_JsonObjectImpl`.
abstract interface class JsonReader {
  /// Creates a [JsonReader] over a UTF-8 byte buffer [bytes].
  factory JsonReader(
    Uint8List bytes, {
    int offset,
    int? length,
  }) = _JsonReaderImpl;

  /// Creates a [JsonReader] over an existing Dart [Map].
  factory JsonReader.fromMap(Map<String, Object?> map) = _MapJsonReader;

  /// Checks if [key] exists in the current JSON object.
  bool hasKey(String key);

  /// Checks if the value for [key] is explicitly `null`.
  bool isNull(String key);

  /// Reads a string value for [key].
  ///
  /// Returns `null` if key is missing or `null`.
  /// Throws [JsonTypeMismatchException] if value exists and is not a string.
  String? readString(String key);

  /// Reads an integer value for [key].
  ///
  /// Returns `null` if the key is missing or explicitly `null`.
  /// Throws [JsonTypeMismatchException] if value exists and is not an integer.
  int? readInt(String key);

  /// Reads a double value for [key].
  ///
  /// Returns `null` if the key is missing or explicitly `null`.
  /// Throws [JsonTypeMismatchException] if value exists and is not a float.
  double? readFloat(String key);

  /// Reads a boolean value for [key].
  ///
  /// Returns `null` if the key is missing or explicitly `null`.
  /// Throws [JsonTypeMismatchException] if value exists and is not a boolean.
  bool? readBool(String key);

  /// Dynamically determines the type and reads any value for [key]
  /// (`String`, `int`, `double`, `bool`, `List`, `Map`, or `null`).
  Object? readAny(String key);

  /// Reads a nested JSON object for [key] as a child [JsonReader].
  ///
  /// Returns `null` if the key is missing or explicitly `null`.
  /// Throws [JsonTypeMismatchException] if value exists and is not an object.
  JsonReader? readObject(String key);

  /// Reads a JSON array for [key] as a list of [T].
  ///
  /// If [decode] is provided, each element (as a child [JsonReader])
  /// is mapped using [decode].
  /// If [decode] is null:
  /// - If [T] is [JsonReader], returns a list of child [JsonReader]s.
  /// - Otherwise, returns a list of primitive [T] values.
  ///
  /// Returns `null` if the key is missing or explicitly `null`.
  /// Throws [JsonTypeMismatchException] if value exists and is not an array.
  List<T>? readList<T>(
    String key, [
    T Function(JsonReader reader)? decode,
  ]);

  /// Reads a JSON object for [key] as a map of `Map<String, V>`.
  ///
  /// If [decode] is provided, each value (as a child [JsonReader])
  /// is mapped using [decode].
  /// If [decode] is null:
  /// - If [V] is [JsonReader], returns a map of child [JsonReader]s.
  /// - Otherwise, returns a map of primitive [V] values.
  ///
  /// Returns `null` if the key is missing or explicitly `null`.
  /// Throws [JsonTypeMismatchException] if value exists and is not an object.
  Map<String, V>? readMap<V>(
    String key, [
    V Function(JsonReader reader)? decode,
  ]);
}

class _JsonReaderImpl implements JsonReader {
  _JsonReaderImpl(this.bytes, {this.offset = 0, int? length})
    : length = length ?? (bytes.length - offset);

  final Uint8List bytes;
  final int offset;
  final int length;

  Int32List?
  _entryData; // 5 ints per entry: keyStart, keyEnd, valStart, valEnd, keyHash
  Int32List? _hashTable;
  int _hashMask = 0;
  int _fieldCount = 0;
  int _lastEntryIndex = -1;

  int _scanPos = 0;
  bool _isInit = false;
  bool _isFullyIndexed = false;
  int? _endOffset;

  @pragma('vm:prefer-inline')
  int _getValStart(int idx) => _entryData![idx + 2];

  @pragma('vm:prefer-inline')
  int _getValEnd(int idx) => _entryData![idx + 3];

  void _initScan() {
    if (_isInit) return;
    _isInit = true;
    final end = offset + length;
    var p = _skipWhitespace(bytes, offset, end);
    if (p < end && bytes[p] == 123 /* '{' */ ) {
      p++; // Skip '{'
      _scanPos = _skipWhitespace(bytes, p, end);
      if (_scanPos < end && bytes[_scanPos] == 125 /* '}' */ ) {
        _isFullyIndexed = true;
        _endOffset = _scanPos + 1;
      }
    } else {
      _scanPos = p;
    }
  }

  int get endOffset {
    if (_endOffset != null) return _endOffset!;
    _skipToEnd();
    return _endOffset!;
  }

  void _skipToEnd() {
    if (_endOffset != null) return;
    final end = offset + length;
    _endOffset = _scanCompoundValueEnd(bytes, offset, end);
  }

  void _addIndexEntry(
    int keyStart,
    int keyEnd,
    int valStart,
    int valEnd,
    int keyHash,
  ) {
    var data = _entryData;
    if (data == null) {
      _entryData = data = Int32List(5 * 8); // 8 entries initially
    } else if (_fieldCount * 5 >= data.length) {
      final newData = Int32List(data.length * 2);
      newData.setRange(0, data.length, data);
      _entryData = data = newData;
    }

    final idx = _fieldCount * 5;
    data[idx] = keyStart;
    data[idx + 1] = keyEnd;
    data[idx + 2] = valStart;
    data[idx + 3] = valEnd;
    data[idx + 4] = keyHash;

    _fieldCount++;

    if (_fieldCount > 8) {
      final hTable = _hashTable;
      if (hTable == null || _fieldCount * 2 > hTable.length) {
        _buildHashTable();
      } else {
        var slot = keyHash & _hashMask;
        while (hTable[slot] != -1) {
          slot = (slot + 1) & _hashMask;
        }
        hTable[slot] = _fieldCount - 1;
      }
    }
  }

  void _buildHashTable() {
    var size = 16;
    while (size < _fieldCount * 2) {
      size <<= 1;
    }
    _hashMask = size - 1;
    final table = Int32List(size)..fillRange(0, size, -1);
    final data = _entryData!;

    for (var i = 0; i < _fieldCount; i++) {
      var slot = data[i * 5 + 4] & _hashMask;
      while (table[slot] != -1) {
        slot = (slot + 1) & _hashMask;
      }
      table[slot] = i;
    }
    _hashTable = table;
  }

  int _scanNextField(int targetHash, String targetKey) {
    if (!_isInit) _initScan();
    var p = _scanPos;
    final end = offset + length;

    if (p >= end || bytes[p] == 125 /* '}' */ ) {
      _isFullyIndexed = true;
      _endOffset = p < end ? p + 1 : end;
      return -1;
    }

    if (bytes[p] != 34 /* '"' */ ) {
      throw JsonSyntaxException('Expected string key in object', offset: p);
    }

    final keyStart = p + 1;
    final keyEnd = _scanStringEnd(bytes, keyStart, end);
    p = keyEnd + 1; // Skip closing quote

    p = _skipWhitespace(bytes, p, end);
    if (p >= end || bytes[p] != 58 /* ':' */ ) {
      throw JsonSyntaxException(
        'Expected ":" after key in object',
        offset: p < end ? p : end,
      );
    }
    p++; // Skip ':'

    p = _skipWhitespace(bytes, p, end);
    if (p >= end) {
      throw JsonSyntaxException(
        'Unexpected end of JSON after ":"',
        offset: end,
      );
    }

    final valStart = p;
    final valEnd = _scanValueEnd(bytes, p, end);
    p = valEnd;

    p = _skipWhitespace(bytes, p, end);
    if (p < end && bytes[p] == 44 /* ',' */ ) {
      p++; // Skip ','
      _scanPos = _skipWhitespace(bytes, p, end);
      if (_scanPos < end && bytes[_scanPos] == 125 /* '}' */ ) {
        throw JsonSyntaxException(
          'Unexpected trailing comma in object',
          offset: p - 1,
        );
      }
    } else if (p < end && bytes[p] == 125 /* '}' */ ) {
      _scanPos = p; // Stay on '}' so next iteration marks _isFullyIndexed
    } else if (p >= end) {
      throw JsonSyntaxException('Unclosed object, expected "}"', offset: end);
    } else {
      throw JsonSyntaxException(
        'Expected "," or "}" after field',
        offset: p,
      );
    }

    final keyHash = _hashKeyBytes(bytes, keyStart, keyEnd);
    _addIndexEntry(keyStart, keyEnd, valStart, valEnd, keyHash);

    final entryIdx = _fieldCount - 1;
    final slot = entryIdx * 5;

    if (keyHash == targetHash &&
        (keyEnd - keyStart) == targetKey.length &&
        _matchesKeyString(bytes, keyStart, keyEnd, targetKey)) {
      _lastEntryIndex = entryIdx;
      return slot;
    }

    return -1;
  }

  int _findEntryIndex(String key) {
    if (!_isInit) _initScan();
    final keyLen = key.length;

    // 1. Check existing indexed fields
    if (_fieldCount > 0) {
      final data = _entryData!;
      final nextIdx = _lastEntryIndex + 1;
      if (nextIdx < _fieldCount) {
        final slot = nextIdx * 5;
        final kStart = data[slot];
        final kEnd = data[slot + 1];
        if (kEnd - kStart == keyLen &&
            _matchesKeyString(bytes, kStart, kEnd, key)) {
          _lastEntryIndex = nextIdx;
          return slot;
        }
      }

      final h = _hashKeyString(key);
      final hTable = _hashTable;
      if (hTable != null) {
        var slot = h & _hashMask;
        while (true) {
          final entryIdx = hTable[slot];
          if (entryIdx == -1) break;
          if (data[entryIdx * 5 + 4] == h) {
            final eSlot = entryIdx * 5;
            final kStart = data[eSlot];
            final kEnd = data[eSlot + 1];
            if (kEnd - kStart == keyLen &&
                _matchesKeyString(bytes, kStart, kEnd, key)) {
              _lastEntryIndex = entryIdx;
              return eSlot;
            }
          }
          slot = (slot + 1) & _hashMask;
        }
      } else {
        for (var i = 0; i < _fieldCount; i++) {
          final eSlot = i * 5;
          if (data[eSlot + 4] == h) {
            final kStart = data[eSlot];
            final kEnd = data[eSlot + 1];
            if (kEnd - kStart == keyLen &&
                _matchesKeyString(bytes, kStart, kEnd, key)) {
              _lastEntryIndex = i;
              return eSlot;
            }
          }
        }
      }
    }

    // 2. Fast-path check for next unscanned field at _scanPos
    if (!_isFullyIndexed) {
      var p = _scanPos;
      final end = offset + length;
      if (p < end && bytes[p] == 34 /* '"' */ ) {
        final keyStart = p + 1;
        final keyEnd = _scanStringEnd(bytes, keyStart, end);
        if (keyEnd - keyStart == keyLen &&
            _matchesKeyString(bytes, keyStart, keyEnd, key)) {
          p = keyEnd + 1;
          p = _skipWhitespace(bytes, p, end);
          if (p < end && bytes[p] == 58 /* ':' */ ) {
            p++;
            p = _skipWhitespace(bytes, p, end);
            if (p < end) {
              final valStart = p;
              final valEnd = _scanValueEnd(bytes, p, end);
              p = _skipWhitespace(bytes, valEnd, end);
              if (p < end && bytes[p] == 44 /* ',' */ ) {
                p++;
                _scanPos = _skipWhitespace(bytes, p, end);
                if (_scanPos < end && bytes[_scanPos] == 125 /* '}' */ ) {
                  throw JsonSyntaxException(
                    'Unexpected trailing comma in object',
                    offset: p - 1,
                  );
                }
              } else if (p < end && bytes[p] == 125 /* '}' */ ) {
                _scanPos = p;
              } else if (p >= end) {
                throw JsonSyntaxException(
                  'Unclosed object, expected "}"',
                  offset: end,
                );
              } else {
                throw JsonSyntaxException(
                  'Expected "," or "}" after field',
                  offset: p,
                );
              }

              final keyHash = _hashKeyBytes(bytes, keyStart, keyEnd);
              _addIndexEntry(keyStart, keyEnd, valStart, valEnd, keyHash);
              final entryIdx = _fieldCount - 1;
              _lastEntryIndex = entryIdx;
              return entryIdx * 5;
            }
          }
        }
      }

      // 3. Fallback: scan remaining fields on demand
      final h = _hashKeyString(key);
      while (!_isFullyIndexed) {
        final slot = _scanNextField(h, key);
        if (slot != -1) return slot;
      }
    }

    return -1;
  }

  @override
  bool hasKey(String key) => _findEntryIndex(key) != -1;

  @override
  bool isNull(String key) {
    final idx = _findEntryIndex(key);
    if (idx == -1) return false;
    return _isNullBytes(bytes, _getValStart(idx), _getValEnd(idx));
  }

  @override
  String? readString(String key) {
    final idx = _findEntryIndex(key);
    if (idx == -1) return null;
    final vStart = _getValStart(idx);
    final vEnd = _getValEnd(idx);

    if (_isNullBytes(bytes, vStart, vEnd)) return null;

    if (bytes[vStart] != 34 /* '"' */ ) {
      throw JsonTypeMismatchException(
        key,
        expected: 'string',
        actual: readAny(key),
      );
    }
    return _parseString(bytes, vStart + 1, vEnd - 1);
  }

  @override
  int? readInt(String key) {
    final idx = _findEntryIndex(key);
    if (idx == -1) return null;
    final vStart = _getValStart(idx);
    final vEnd = _getValEnd(idx);

    if (_isNullBytes(bytes, vStart, vEnd)) return null;

    final firstByte = bytes[vStart];
    if (firstByte != 45 /* '-' */ && (firstByte < 48 || firstByte > 57)) {
      throw JsonTypeMismatchException(
        key,
        expected: 'integer',
        actual: readAny(key),
      );
    }
    return _parseInt(bytes, vStart, vEnd);
  }

  @override
  double? readFloat(String key) {
    final idx = _findEntryIndex(key);
    if (idx == -1) return null;
    final vStart = _getValStart(idx);
    final vEnd = _getValEnd(idx);

    if (_isNullBytes(bytes, vStart, vEnd)) return null;

    final firstByte = bytes[vStart];
    if (firstByte != 45 /* '-' */ && (firstByte < 48 || firstByte > 57)) {
      throw JsonTypeMismatchException(
        key,
        expected: 'float',
        actual: readAny(key),
      );
    }
    return _parseFloat(bytes, vStart, vEnd);
  }

  @override
  bool? readBool(String key) {
    final idx = _findEntryIndex(key);
    if (idx == -1) return null;
    final vStart = _getValStart(idx);
    final vEnd = _getValEnd(idx);

    if (_isNullBytes(bytes, vStart, vEnd)) return null;

    final len = vEnd - vStart;
    if (len == 4 &&
        bytes[vStart] == 116 /* 't' */ &&
        bytes[vStart + 1] == 114 /* 'r' */ &&
        bytes[vStart + 2] == 117 /* 'u' */ &&
        bytes[vStart + 3] == 101 /* 'e' */ ) {
      return true;
    }
    if (len == 5 &&
        bytes[vStart] == 102 /* 'f' */ &&
        bytes[vStart + 1] == 97 /* 'a' */ &&
        bytes[vStart + 2] == 108 /* 'l' */ &&
        bytes[vStart + 3] == 115 /* 's' */ &&
        bytes[vStart + 4] == 101 /* 'e' */ ) {
      return false;
    }

    throw JsonTypeMismatchException(
      key,
      expected: 'boolean',
      actual: readAny(key),
    );
  }

  @override
  Object? readAny(String key) {
    final idx = _findEntryIndex(key);
    if (idx == -1) return null;
    final vStart = _getValStart(idx);
    final vEnd = _getValEnd(idx);

    return _readAnyAt(bytes, vStart, vEnd);
  }

  @override
  JsonReader? readObject(String key) {
    final idx = _findEntryIndex(key);
    if (idx == -1) return null;
    final vStart = _getValStart(idx);
    final vEnd = _getValEnd(idx);

    if (_isNullBytes(bytes, vStart, vEnd)) return null;

    if (bytes[vStart] != 123 /* '{' */ ) {
      throw JsonTypeMismatchException(
        key,
        expected: 'object',
        actual: readAny(key),
      );
    }
    return _JsonReaderImpl(bytes, offset: vStart, length: vEnd - vStart);
  }

  @override
  List<T>? readList<T>(
    String key, [
    T Function(JsonReader reader)? decode,
  ]) {
    final int vStart;
    final int vEnd;
    if (key.isEmpty) {
      vStart = offset;
      vEnd = offset + length;
    } else {
      final idx = _findEntryIndex(key);
      if (idx == -1) return null;
      vStart = _getValStart(idx);
      vEnd = _getValEnd(idx);
    }

    if (_isNullBytes(bytes, vStart, vEnd)) return null;

    if (bytes[vStart] != 91 /* '[' */ ) {
      throw JsonTypeMismatchException(
        key,
        expected: 'list',
        actual: key.isEmpty ? 'invalid list' : readAny(key),
      );
    }

    final end = vEnd;
    var p = _skipWhitespace(bytes, vStart + 1, end);

    if (p < end && bytes[p] == 93 /* ']' */ ) {
      return <T>[];
    }

    final isReaderType = T == JsonReader;
    final result = <T>[];
    var closed = false;

    while (p < end) {
      p = _skipWhitespace(bytes, p, end);
      if (p >= end) break;
      if (bytes[p] == 93 /* ']' */ ) {
        closed = true;
        break;
      }

      if (decode != null || isReaderType) {
        if (bytes[p] != 123 /* '{' */ ) {
          final elemEnd = _scanValueEnd(bytes, p, end);
          throw JsonTypeMismatchException(
            key,
            expected: 'list of objects',
            actual: _readAnyAt(bytes, p, elemEnd),
          );
        }
        final childReader = _JsonReaderImpl(bytes, offset: p, length: end - p);
        if (decode != null) {
          result.add(decode(childReader));
        } else {
          result.add(childReader as T);
        }
        p = childReader.endOffset;
      } else if (T == int) {
        var isNegative = false;
        if (p < end && bytes[p] == 45 /* '-' */ ) {
          isNegative = true;
          p++;
        }
        if (p >= end || bytes[p] < 48 || bytes[p] > 57) {
          final elemEnd = _scanValueEnd(bytes, p, end);
          throw JsonTypeMismatchException(
            key,
            expected: 'integer',
            actual: _readAnyAt(bytes, p, elemEnd),
          );
        }
        var val = 0;
        while (p < end && bytes[p] >= 48 && bytes[p] <= 57) {
          val = val * 10 + (bytes[p] - 48);
          p++;
        }
        result.add((isNegative ? -val : val) as T);
      } else if (T == double) {
        final elemStart = p;
        final elemEnd = _scanValueEnd(bytes, p, end);
        p = elemEnd;

        final first = bytes[elemStart];
        if (first != 45 && (first < 48 || first > 57)) {
          throw JsonTypeMismatchException(
            key,
            expected: 'float',
            actual: _readAnyAt(bytes, elemStart, elemEnd),
          );
        }
        result.add(_parseFloat(bytes, elemStart, elemEnd) as T);
      } else if (T == String) {
        final elemStart = p;
        final elemEnd = _scanValueEnd(bytes, p, end);
        p = elemEnd;

        if (bytes[elemStart] != 34) {
          throw JsonTypeMismatchException(
            key,
            expected: 'string',
            actual: _readAnyAt(bytes, elemStart, elemEnd),
          );
        }
        result.add(_parseString(bytes, elemStart + 1, elemEnd - 1) as T);
      } else if (T == bool) {
        final elemStart = p;
        final elemEnd = _scanValueEnd(bytes, p, end);
        p = elemEnd;

        final len = elemEnd - elemStart;
        if (len == 4 && bytes[elemStart] == 116) {
          result.add(true as T);
        } else if (len == 5 && bytes[elemStart] == 102) {
          result.add(false as T);
        } else {
          throw JsonTypeMismatchException(
            key,
            expected: 'boolean',
            actual: _readAnyAt(bytes, elemStart, elemEnd),
          );
        }
      } else {
        final elemStart = p;
        final elemEnd = _scanValueEnd(bytes, p, end);
        p = elemEnd;

        final val = _readAnyAt(bytes, elemStart, elemEnd);
        if (val is! T) {
          throw JsonTypeMismatchException(
            key,
            expected: T.toString(),
            actual: val,
          );
        }
        result.add(val);
      }

      p = _skipWhitespace(bytes, p, end);
      if (p < end && bytes[p] == 44 /* ',' */ ) {
        p++;
        p = _skipWhitespace(bytes, p, end);
        if (p < end && bytes[p] == 93 /* ']' */ ) {
          throw JsonSyntaxException(
            'Unexpected trailing comma in array',
            offset: p - 1,
          );
        }
      } else if (p < end && bytes[p] == 93 /* ']' */ ) {
        closed = true;
        break;
      } else {
        throw JsonSyntaxException('Expected "," or "]" in array', offset: p);
      }
    }

    if (!closed) {
      throw JsonSyntaxException('Unclosed array, expected "]"', offset: end);
    }

    return result;
  }

  @override
  Map<String, V>? readMap<V>(
    String key, [
    V Function(JsonReader reader)? decode,
  ]) {
    final int vStart;
    final int vEnd;
    if (key.isEmpty) {
      vStart = offset;
      vEnd = offset + length;
    } else {
      final idx = _findEntryIndex(key);
      if (idx == -1) return null;
      vStart = _getValStart(idx);
      vEnd = _getValEnd(idx);
    }

    if (_isNullBytes(bytes, vStart, vEnd)) return null;

    if (bytes[vStart] != 123 /* '{' */ ) {
      throw JsonTypeMismatchException(
        key,
        expected: 'object',
        actual: key.isEmpty ? 'invalid map' : readAny(key),
      );
    }
    return _parseMapDirect<V>(bytes, vStart, vEnd, decode);
  }
}

@pragma('vm:prefer-inline')
int _skipWhitespace(Uint8List bytes, int offset, int end) {
  var p = offset;
  while (p < end && bytes[p] <= 32) {
    p++;
  }
  return p;
}

bool _lastStringIsSimpleAscii = false;

@pragma('vm:prefer-inline')
int _scanStringEnd(Uint8List bytes, int start, int end) {
  var p = start;
  var simple = true;

  while (p + 4 <= end) {
    var b = bytes[p];
    if (b == 34 /* '"' */ ) {
      _lastStringIsSimpleAscii = simple;
      return p;
    }
    if (b == 92 /* '\' */ || b >= 128) {
      if (b == 92) return _scanStringEndFallback(bytes, p, end);
      simple = false;
    }

    b = bytes[p + 1];
    if (b == 34) {
      _lastStringIsSimpleAscii = simple;
      return p + 1;
    }
    if (b == 92 || b >= 128) {
      if (b == 92) return _scanStringEndFallback(bytes, p + 1, end);
      simple = false;
    }

    b = bytes[p + 2];
    if (b == 34) {
      _lastStringIsSimpleAscii = simple;
      return p + 2;
    }
    if (b == 92 || b >= 128) {
      if (b == 92) return _scanStringEndFallback(bytes, p + 2, end);
      simple = false;
    }

    b = bytes[p + 3];
    if (b == 34) {
      _lastStringIsSimpleAscii = simple;
      return p + 3;
    }
    if (b == 92 || b >= 128) {
      if (b == 92) return _scanStringEndFallback(bytes, p + 3, end);
      simple = false;
    }

    p += 4;
  }

  while (p < end) {
    final b = bytes[p];
    if (b == 34 /* '"' */ ) {
      _lastStringIsSimpleAscii = simple;
      return p;
    }
    if (b == 92 || b >= 128) simple = false;
    if (b == 92) return _scanStringEndFallback(bytes, p, end);
    p++;
  }
  throw JsonSyntaxException('Unclosed string quote', offset: start - 1);
}

int _scanStringEndFallback(Uint8List bytes, int start, int end) {
  _lastStringIsSimpleAscii = false;
  var p = start;
  while (p < end) {
    final b = bytes[p];
    if (b == 34 /* '"' */ ) return p;
    if (b == 92 /* '\' */ ) p++;
    p++;
  }
  throw JsonSyntaxException('Unclosed string quote', offset: start - 1);
}

@pragma('vm:prefer-inline')
int _scanValueEnd(Uint8List bytes, int start, int end) {
  if (start >= end) {
    throw JsonSyntaxException('Unexpected end of input', offset: start);
  }

  final first = bytes[start];

  if (first == 44 /* ',' */ ||
      first == 125 /* '}' */ ||
      first == 93 /* ']' */ ) {
    throw JsonSyntaxException('Expected JSON value token', offset: start);
  }

  if (first == 34 /* '"' */ ) {
    return _scanStringEnd(bytes, start + 1, end) + 1;
  }

  if (first == 123 /* '{' */ || first == 91 /* '[' */ ) {
    return _scanCompoundValueEnd(bytes, start, end);
  }

  var p = start;
  while (p < end) {
    final b = bytes[p];
    if (b == 44 /* ',' */ ||
        b == 125 /* '}' */ ||
        b == 93 /* ']' */ ||
        b <= 32) {
      break;
    }
    p++;
  }
  return p;
}

int _scanCompoundValueEnd(Uint8List bytes, int start, int end) {
  final openChar = bytes[start];
  final closeChar = openChar == 123 /* '{' */ ? 125 /* '}' */ : 93 /* ']' */;
  var depth = 1;
  var p = start + 1;

  while (p < end && depth > 0) {
    final b = bytes[p];
    if (b == 34 /* '"' */ ) {
      p = _scanStringEnd(bytes, p + 1, end) + 1;
      continue;
    }
    if (b == openChar) {
      depth++;
    } else if (b == closeChar) {
      depth--;
    }
    p++;
  }

  if (depth > 0) {
    throw JsonSyntaxException(
      openChar == 123 ? 'Unclosed object "{"' : 'Unclosed array "["',
      offset: start,
    );
  }
  return p;
}

@pragma('vm:prefer-inline')
bool _matchesKeyString(Uint8List bytes, int start, int end, String key) {
  final len = end - start;
  if (len != key.length) return false;
  for (var i = 0; i < len; i++) {
    if (bytes[start + i] != key.codeUnitAt(i)) return false;
  }
  return true;
}

@pragma('vm:prefer-inline')
bool _isNullBytes(Uint8List bytes, int start, int end) {
  return (end - start == 4) &&
      bytes[start] == 110 /* 'n' */ &&
      bytes[start + 1] == 117 /* 'u' */ &&
      bytes[start + 2] == 108 /* 'l' */ &&
      bytes[start + 3] == 108 /* 'l' */;
}

int _parseInt(Uint8List bytes, int start, int end) {
  var p = start;
  var isNegative = false;
  if (p < end && bytes[p] == 45 /* '-' */ ) {
    isNegative = true;
    p++;
  }
  var value = 0;
  while (p < end) {
    final b = bytes[p];
    if (b < 48 || b > 57) {
      throw JsonSyntaxException('Invalid integer character', offset: p);
    }
    value = value * 10 + (b - 48);
    p++;
  }
  return isNegative ? -value : value;
}

double _parseFloat(Uint8List bytes, int start, int end) {
  var p = start;
  var isNegative = false;
  if (p < end && bytes[p] == 45 /* '-' */ ) {
    isNegative = true;
    p++;
  }

  var intVal = 0;
  var intDigits = 0;
  while (p < end) {
    final b = bytes[p];
    if (b >= 48 && b <= 57) {
      intVal = intVal * 10 + (b - 48);
      intDigits++;
      p++;
    } else {
      break;
    }
  }

  var fracVal = 0;
  var fracDigits = 0;
  var fracDiv = 1.0;
  if (p < end && bytes[p] == 46 /* '.' */ ) {
    p++; // Skip '.'
    while (p < end) {
      final b = bytes[p];
      if (b >= 48 && b <= 57) {
        fracVal = fracVal * 10 + (b - 48);
        fracDiv *= 10.0;
        fracDigits++;
        p++;
      } else {
        break;
      }
    }
  }

  var expVal = 0;
  var isExpNeg = false;
  if (p < end && (bytes[p] == 101 /* 'e' */ || bytes[p] == 69 /* 'E' */ )) {
    p++;
    if (p < end && bytes[p] == 45 /* '-' */ ) {
      isExpNeg = true;
      p++;
    } else if (p < end && bytes[p] == 43 /* '+' */ ) {
      p++;
    }
    while (p < end && bytes[p] >= 48 && bytes[p] <= 57) {
      expVal = expVal * 10 + (bytes[p] - 48);
      p++;
    }
  }

  final validDigits =
      (intDigits > 0 || fracDigits > 0) && (intDigits + fracDigits <= 17);
  if (p == end && validDigits) {
    var res = intVal + (fracVal / fracDiv);
    if (isNegative) res = -res;
    if (expVal != 0) {
      final mult = _pow10(expVal);
      res = isExpNeg ? res / mult : res * mult;
    }
    return res;
  }

  final str = String.fromCharCodes(bytes, start, end);
  final val = double.tryParse(str);
  if (val == null) {
    throw JsonSyntaxException('Invalid float format "$str"', offset: start);
  }
  return val;
}

const _pow10Lookup = <double>[
  1,
  10,
  100,
  1000,
  10000,
  100000,
  1000000,
  10000000,
  100000000,
  1000000000,
  10000000000,
  100000000000,
  1000000000000,
  10000000000000,
  100000000000000,
  1000000000000000,
  10000000000000000,
  100000000000000000,
  1000000000000000000,
  10000000000000000000,
];

double _pow10(int exp) {
  if (exp >= 0 && exp < _pow10Lookup.length) return _pow10Lookup[exp];
  return double.parse('1e$exp');
}

@pragma('vm:prefer-inline')
String _parseString(Uint8List bytes, int start, int end) {
  if (_lastStringIsSimpleAscii) {
    return String.fromCharCodes(bytes, start, end);
  }
  return _parseStringSlow(bytes, start, end);
}

String _parseStringSlow(Uint8List bytes, int start, int end) {
  var hasEscapes = false;
  var isAscii = true;
  var i = start;

  while (i + 4 <= end) {
    final b0 = bytes[i];
    final b1 = bytes[i + 1];
    final b2 = bytes[i + 2];
    final b3 = bytes[i + 3];
    if (b0 == 92 || b1 == 92 || b2 == 92 || b3 == 92) {
      hasEscapes = true;
      break;
    }
    if ((b0 | b1 | b2 | b3) >= 128) {
      isAscii = false;
    }
    i += 4;
  }

  if (!hasEscapes) {
    while (i < end) {
      final b = bytes[i];
      if (b == 92) {
        hasEscapes = true;
        break;
      }
      if (b >= 128) isAscii = false;
      i++;
    }
  }

  if (!hasEscapes) {
    if (isAscii) {
      return String.fromCharCodes(bytes, start, end);
    }
    return utf8.decode(Uint8List.sublistView(bytes, start, end));
  }

  return _parseEscapedString(bytes, start, end);
}

String _parseEscapedString(Uint8List bytes, int start, int end) {
  final outBytes = Uint8List(end - start);
  var outPos = 0;
  var p = start;
  var isAscii = true;

  while (p < end) {
    final b = bytes[p];
    if (b == 92 /* '\' */ ) {
      p++;
      if (p >= end) {
        throw JsonSyntaxException('Unterminated escape sequence', offset: p);
      }
      final esc = bytes[p];
      switch (esc) {
        case 34:
          outBytes[outPos++] = 34; // '"'
        case 92:
          outBytes[outPos++] = 92; // '\'
        case 47:
          outBytes[outPos++] = 47; // '/'
        case 98:
          outBytes[outPos++] = 8; // '\b'
        case 102:
          outBytes[outPos++] = 12; // '\f'
        case 110:
          outBytes[outPos++] = 10; // '\n'
        case 114:
          outBytes[outPos++] = 13; // '\r'
        case 116:
          outBytes[outPos++] = 9; // '\t'
        case 117: // 'u'
          if (p + 4 >= end) {
            throw JsonSyntaxException(
              'Incomplete unicode escape',
              offset: p,
            );
          }
          var codePoint = _parseHex4(bytes, p + 1);
          p += 4;
          if (codePoint >= 0xD800 &&
              codePoint <= 0xDBFF &&
              p + 6 < end &&
              bytes[p + 1] == 92 &&
              bytes[p + 2] == 117) {
            final lowUnit = _parseHex4(bytes, p + 3);
            if (lowUnit >= 0xDC00 && lowUnit <= 0xDFFF) {
              p += 6;
              codePoint =
                  0x10000 + ((codePoint & 0x3FF) << 10) + (lowUnit & 0x3FF);
            }
          }
          if (codePoint > 0x7F) isAscii = false;
          outPos = _appendUtf8(outBytes, outPos, codePoint);
        default:
          throw JsonSyntaxException(
            'Unknown escape character \\${String.fromCharCode(esc)}',
            offset: p,
          );
      }
    } else {
      if (b >= 128) isAscii = false;
      outBytes[outPos++] = b;
    }
    p++;
  }

  if (isAscii) {
    return String.fromCharCodes(outBytes, 0, outPos);
  }
  return utf8.decode(Uint8List.sublistView(outBytes, 0, outPos));
}

@pragma('vm:prefer-inline')
int _appendUtf8(Uint8List out, int pos, int codePoint) {
  var p = pos;
  if (codePoint <= 0x7F) {
    out[p++] = codePoint;
  } else if (codePoint <= 0x7FF) {
    out[p++] = 0xC0 | (codePoint >> 6);
    out[p++] = 0x80 | (codePoint & 0x3F);
  } else if (codePoint <= 0xFFFF) {
    out[p++] = 0xE0 | (codePoint >> 12);
    out[p++] = 0x80 | ((codePoint >> 6) & 0x3F);
    out[p++] = 0x80 | (codePoint & 0x3F);
  } else {
    out[p++] = 0xF0 | (codePoint >> 18);
    out[p++] = 0x80 | ((codePoint >> 12) & 0x3F);
    out[p++] = 0x80 | ((codePoint >> 6) & 0x3F);
    out[p++] = 0x80 | (codePoint & 0x3F);
  }
  return p;
}

int _parseHex4(Uint8List bytes, int p) {
  var result = 0;
  for (var i = 0; i < 4; i++) {
    final b = bytes[p + i];
    final digit = (b <= 57 && b >= 48)
        ? b - 48
        : (b >= 65 && b <= 70) || (b >= 97 && b <= 102)
        ? (b | 0x20) - 87
        : -1;
    if (digit < 0) {
      throw JsonSyntaxException('Invalid hex digit', offset: p + i);
    }
    result = (result << 4) | digit;
  }
  return result;
}

@pragma('vm:prefer-inline')
int _hashKeyBytes(Uint8List bytes, int start, int end) {
  var h = 5381;
  for (var i = start; i < end; i++) {
    h = ((h << 5) + h) ^ bytes[i];
  }
  return h & 0x7FFFFFFF;
}

@pragma('vm:prefer-inline')
int _hashKeyString(String key) {
  var h = 5381;
  final len = key.length;
  for (var i = 0; i < len; i++) {
    h = ((h << 5) + h) ^ key.codeUnitAt(i);
  }
  return h & 0x7FFFFFFF;
}

Object? _readAnyAt(Uint8List bytes, int start, int end) {
  if (start >= end) return null;
  if (_isNullBytes(bytes, start, end)) return null;

  final first = bytes[start];

  if (first == 34 /* '"' */ ) {
    return _parseString(bytes, start + 1, end - 1);
  }

  if (first == 116 /* 't' */ || first == 102 /* 'f' */ ) {
    final len = end - start;
    if (len == 4 &&
        bytes[start] == 116 &&
        bytes[start + 1] == 114 &&
        bytes[start + 2] == 117 &&
        bytes[start + 3] == 101) {
      return true;
    }
    if (len == 5 &&
        bytes[start] == 102 &&
        bytes[start + 1] == 97 &&
        bytes[start + 2] == 108 &&
        bytes[start + 3] == 115 &&
        bytes[start + 4] == 101) {
      return false;
    }
    throw JsonSyntaxException(
      'Invalid boolean literal',
      offset: start,
    );
  }

  if (first == 45 /* '-' */ || (first >= 48 && first <= 57)) {
    var isFloat = false;
    for (var i = start; i < end; i++) {
      final b = bytes[i];
      if (b == 46 /* '.' */ || b == 101 /* 'e' */ || b == 69 /* 'E' */ ) {
        isFloat = true;
        break;
      }
    }
    if (isFloat) {
      return _parseFloat(bytes, start, end);
    } else {
      return _parseInt(bytes, start, end);
    }
  }

  if (first == 123 /* '{' */ ) {
    return _parseObjectDirect(bytes, start, end);
  }

  if (first == 91 /* '[' */ ) {
    return _parseListDirect(bytes, start, end);
  }

  throw JsonSyntaxException('Unknown JSON token', offset: start);
}

Map<String, Object?> _parseObjectDirect(
  Uint8List bytes,
  int start,
  int end,
) {
  var p = _skipWhitespace(bytes, start + 1, end);
  final map = <String, Object?>{};
  if (p < end && bytes[p] == 125 /* '}' */ ) {
    return map;
  }

  while (p < end) {
    p = _skipWhitespace(bytes, p, end);
    if (p >= end || bytes[p] != 34 /* '"' */ ) {
      throw JsonSyntaxException('Expected string key in object', offset: p);
    }
    final keyStart = p + 1;
    final keyEnd = _scanStringEnd(bytes, keyStart, end);
    p = keyEnd + 1;

    final key = _parseString(bytes, keyStart, keyEnd);

    p = _skipWhitespace(bytes, p, end);
    if (p >= end || bytes[p] != 58 /* ':' */ ) {
      throw JsonSyntaxException('Expected ":" after key in object', offset: p);
    }
    p++;

    p = _skipWhitespace(bytes, p, end);
    final valStart = p;
    final valEnd = _scanValueEnd(bytes, p, end);
    p = valEnd;

    map[key] = _readAnyAt(bytes, valStart, valEnd);

    p = _skipWhitespace(bytes, p, end);
    if (p < end && bytes[p] == 44 /* ',' */ ) {
      p++;
    } else if (p < end && bytes[p] == 125 /* '}' */ ) {
      break;
    } else {
      throw JsonSyntaxException('Expected "," or "}" after field', offset: p);
    }
  }
  return map;
}

List<Object?> _parseListDirect(Uint8List bytes, int start, int end) {
  var p = _skipWhitespace(bytes, start + 1, end);
  final list = <Object?>[];
  if (p < end && bytes[p] == 93 /* ']' */ ) {
    return list;
  }

  while (p < end) {
    p = _skipWhitespace(bytes, p, end);
    if (p >= end || bytes[p] == 93 /* ']' */ ) break;

    final elemStart = p;
    final elemEnd = _scanValueEnd(bytes, p, end);
    p = elemEnd;

    list.add(_readAnyAt(bytes, elemStart, elemEnd));

    p = _skipWhitespace(bytes, p, end);
    if (p < end && bytes[p] == 44 /* ',' */ ) {
      p++;
    } else if (p < end && bytes[p] == 93 /* ']' */ ) {
      break;
    } else {
      throw JsonSyntaxException('Expected "," or "]" in array', offset: p);
    }
  }
  return list;
}

Map<String, V> _parseMapDirect<V>(
  Uint8List bytes,
  int start,
  int end, [
  V Function(JsonReader reader)? decode,
]) {
  var p = _skipWhitespace(bytes, start + 1, end);
  final result = <String, V>{};
  if (p < end && bytes[p] == 125 /* '}' */ ) {
    return result;
  }

  final isReaderType = V == JsonReader;

  while (p < end) {
    p = _skipWhitespace(bytes, p, end);
    if (p >= end || bytes[p] != 34 /* '"' */ ) {
      throw JsonSyntaxException('Expected string key in map', offset: p);
    }
    final keyStart = p + 1;
    final keyEnd = _scanStringEnd(bytes, keyStart, end);
    p = keyEnd + 1;

    final mapKey = _parseString(bytes, keyStart, keyEnd);

    p = _skipWhitespace(bytes, p, end);
    if (p >= end || bytes[p] != 58 /* ':' */ ) {
      throw JsonSyntaxException('Expected ":" after key in map', offset: p);
    }
    p++;

    p = _skipWhitespace(bytes, p, end);
    final vStart = p;
    final vEnd = _scanValueEnd(bytes, p, end);
    p = vEnd;

    if (decode != null || isReaderType) {
      if (bytes[vStart] != 123 /* '{' */ ) {
        throw JsonTypeMismatchException(
          mapKey,
          expected: 'object',
          actual: _readAnyAt(bytes, vStart, vEnd),
        );
      }
      final childReader = _JsonReaderImpl(
        bytes,
        offset: vStart,
        length: vEnd - vStart,
      );
      if (decode != null) {
        result[mapKey] = decode(childReader);
      } else {
        result[mapKey] = childReader as V;
      }
    } else if (V == int) {
      final first = bytes[vStart];
      if (first != 45 && (first < 48 || first > 57)) {
        throw JsonTypeMismatchException(
          mapKey,
          expected: 'integer',
          actual: _readAnyAt(bytes, vStart, vEnd),
        );
      }
      result[mapKey] = _parseInt(bytes, vStart, vEnd) as V;
    } else if (V == double) {
      final first = bytes[vStart];
      if (first != 45 && (first < 48 || first > 57)) {
        throw JsonTypeMismatchException(
          mapKey,
          expected: 'float',
          actual: _readAnyAt(bytes, vStart, vEnd),
        );
      }
      result[mapKey] = _parseFloat(bytes, vStart, vEnd) as V;
    } else if (V == String) {
      if (bytes[vStart] != 34) {
        throw JsonTypeMismatchException(
          mapKey,
          expected: 'string',
          actual: _readAnyAt(bytes, vStart, vEnd),
        );
      }
      result[mapKey] = _parseString(bytes, vStart + 1, vEnd - 1) as V;
    } else if (V == bool) {
      final len = vEnd - vStart;
      if (len == 4 && bytes[vStart] == 116) {
        result[mapKey] = true as V;
      } else if (len == 5 && bytes[vStart] == 102) {
        result[mapKey] = false as V;
      } else {
        throw JsonTypeMismatchException(
          mapKey,
          expected: 'boolean',
          actual: _readAnyAt(bytes, vStart, vEnd),
        );
      }
    } else {
      final val = _readAnyAt(bytes, vStart, vEnd);
      if (val is! V) {
        throw JsonTypeMismatchException(
          mapKey,
          expected: V.toString().toLowerCase(),
          actual: val,
        );
      }
      result[mapKey] = val;
    }

    p = _skipWhitespace(bytes, p, end);
    if (p < end && bytes[p] == 44 /* ',' */ ) {
      p++;
    } else if (p < end && bytes[p] == 125 /* '}' */ ) {
      break;
    } else {
      throw JsonSyntaxException('Expected "," or "}" after field', offset: p);
    }
  }
  return result;
}

class _MapJsonReader implements JsonReader {
  _MapJsonReader(this._map);

  final Map<String, Object?> _map;

  @override
  bool hasKey(String key) => _map.containsKey(key);

  @override
  bool isNull(String key) => _map.containsKey(key) && _map[key] == null;

  @override
  String? readString(String key) {
    final val = _map[key];
    if (val == null) return null;
    if (val is! String) {
      throw JsonTypeMismatchException(
        key,
        expected: 'string',
        actual: val,
      );
    }
    return val;
  }

  @override
  int? readInt(String key) {
    final val = _map[key];
    if (val == null) return null;
    if (val is! int) {
      throw JsonTypeMismatchException(
        key,
        expected: 'int',
        actual: val,
      );
    }
    return val;
  }

  @override
  double? readFloat(String key) {
    final val = _map[key];
    if (val == null) return null;
    if (val is! num) {
      throw JsonTypeMismatchException(
        key,
        expected: 'double',
        actual: val,
      );
    }
    return val.toDouble();
  }

  @override
  bool? readBool(String key) {
    final val = _map[key];
    if (val == null) return null;
    if (val is! bool) {
      throw JsonTypeMismatchException(
        key,
        expected: 'bool',
        actual: val,
      );
    }
    return val;
  }

  @override
  Object? readAny(String key) => _map[key];

  @override
  JsonReader? readObject(String key) {
    final val = _map[key];
    if (val == null) return null;
    if (val is! Map) {
      throw JsonTypeMismatchException(
        key,
        expected: 'map',
        actual: val,
      );
    }
    return _MapJsonReader(val.cast<String, Object?>());
  }

  @override
  List<T>? readList<T>(
    String key, [
    T Function(JsonReader reader)? decode,
  ]) {
    final val = _map[key];
    if (val == null) return null;
    if (val is! List) {
      throw JsonTypeMismatchException(
        key,
        expected: 'list',
        actual: val,
      );
    }
    final isReaderType = T == JsonReader;
    return val.map((e) {
      if (decode != null || isReaderType) {
        if (e is! Map) {
          throw JsonTypeMismatchException(
            key,
            expected: 'map',
            actual: e,
          );
        }
        final childReader = _MapJsonReader(e.cast<String, Object?>());
        if (decode != null) {
          return decode(childReader);
        } else {
          return childReader as T;
        }
      } else {
        if (e is! T) {
          throw JsonTypeMismatchException(
            key,
            expected: T.toString(),
            actual: e,
          );
        }
        return e;
      }
    }).toList();
  }

  @override
  Map<String, V>? readMap<V>(
    String key, [
    V Function(JsonReader reader)? decode,
  ]) {
    final val = _map[key];
    if (val == null) return null;
    if (val is! Map) {
      throw JsonTypeMismatchException(
        key,
        expected: 'map',
        actual: val,
      );
    }
    final isReaderType = V == JsonReader;
    final res = <String, V>{};
    for (final entry in val.entries) {
      final k = entry.key.toString();
      final v = entry.value;
      if (decode != null || isReaderType) {
        if (v is! Map) {
          throw JsonTypeMismatchException(
            key,
            expected: 'map',
            actual: v,
          );
        }
        final childReader = _MapJsonReader(v.cast<String, Object?>());
        if (decode != null) {
          res[k] = decode(childReader);
        } else {
          res[k] = childReader as V;
        }
      } else {
        if (v is! V) {
          throw JsonTypeMismatchException(
            key,
            expected: V.toString(),
            actual: v,
          );
        }
        res[k] = v;
      }
    }
    return res;
  }
}
