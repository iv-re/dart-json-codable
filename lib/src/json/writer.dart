import 'dart:convert';
import 'dart:typed_data';

/// Interface for writing JSON data into UTF-8 bytes or strings.
abstract interface class JsonWriter {
  factory JsonWriter([int initialCapacity]) = _JsonWriterImpl;

  /// Encodes a root JSON object to UTF-8 bytes.
  static Uint8List encode(void Function(JsonWriter writer) block) {
    final writer = JsonWriter();
    block(writer);
    return writer.toBytes();
  }

  /// Encodes a root JSON array/list to UTF-8 bytes.
  static Uint8List encodeList<T>(
    Iterable<T>? items, {
    void Function(JsonWriter writer, T item)? mapper,
  }) {
    if (items == null) {
      return Uint8List.fromList(const [110, 117, 108, 108]);
    }
    final writer = _JsonWriterImpl._raw();
    writer._writeRootList(items, mapper: mapper);
    return writer.toBytes();
  }

  /// Writes a primitive [String] field by [key].
  void string(String key, String? value);

  /// Writes a primitive [int] field by [key].
  void integer(String key, int? value);

  /// Writes a primitive [double] field by [key].
  void float(String key, double? value);

  /// Writes a primitive [bool] field by [key].
  void boolean(String key, bool? value);

  /// Writes a nested object field by [key].
  void object(String key, void Function(JsonWriter writer) block);

  /// Writes a list field by [key].
  void list<T>(
    String key,
    Iterable<T>? items, {
    void Function(JsonWriter writer, T item)? mapper,
  });

  /// Writes a map field by [key].
  void map<V>(
    String key,
    Map<String, V>? items, {
    void Function(JsonWriter writer, V value)? mapper,
  });

  /// Returns the built UTF-8 bytes.
  Uint8List toBytes();
}

class _JsonWriterImpl implements JsonWriter {
  _JsonWriterImpl([int initialCapacity = 256])
    : _buffer = _ByteBuffer(initialCapacity) {
    _buffer.writeByte(123); // '{'
  }

  _JsonWriterImpl._raw([int initialCapacity = 256])
    : _buffer = _ByteBuffer(initialCapacity);

  static final Map<String, Uint8List> _firstKeyCache = {};
  static final Map<String, Uint8List> _nextKeyCache = {};

  final _ByteBuffer _buffer;
  bool _hasFields = false;
  bool _closed = false;

  void _writeRootList<T>(
    Iterable<T> items, {
    void Function(JsonWriter writer, T item)? mapper,
  }) {
    _buffer.writeByte(91); // '['
    var first = true;
    for (final item in items) {
      if (first) {
        first = false;
      } else {
        _buffer.writeByte(44); // ','
      }
      if (mapper != null) {
        _buffer.writeByte(123); // '{'
        final parentHasFields = _hasFields;
        _hasFields = false;
        mapper(this, item);
        _buffer.writeByte(125); // '}'
        _hasFields = parentHasFields;
      } else {
        _writeValue(item);
      }
    }
    _buffer.writeByte(93); // ']'
    _closed = true;
  }

  @pragma('vm:prefer-inline')
  void _writeKey(String key) {
    if (_hasFields) {
      var cached = _nextKeyCache[key];
      if (cached == null) {
        if (_nextKeyCache.length >= 512) _nextKeyCache.clear();
        cached = Uint8List.fromList(utf8.encode(',"$key":'));
        _nextKeyCache[key] = cached;
      }
      _buffer.writeBytes(cached);
    } else {
      _hasFields = true;
      var cached = _firstKeyCache[key];
      if (cached == null) {
        if (_firstKeyCache.length >= 512) _firstKeyCache.clear();
        cached = Uint8List.fromList(utf8.encode('"$key":'));
        _firstKeyCache[key] = cached;
      }
      _buffer.writeBytes(cached);
    }
  }

  @override
  void string(String key, String? value) {
    _writeKey(key);
    if (value == null) {
      _writeNull();
    } else {
      _writeEscapedString(value);
    }
  }

  @override
  void integer(String key, int? value) {
    _writeKey(key);
    if (value == null) {
      _writeNull();
    } else {
      _writeInteger(value);
    }
  }

  @override
  void float(String key, double? value) {
    _writeKey(key);
    if (value == null) {
      _writeNull();
    } else {
      _writeAsciiString(value.toString());
    }
  }

  @override
  void boolean(String key, bool? value) {
    _writeKey(key);
    if (value == null) {
      _writeNull();
    } else {
      _buffer.writeBytes(value ? _trueBytes : _falseBytes);
    }
  }

  @override
  void object(String key, void Function(JsonWriter writer) block) {
    _writeKey(key);
    _buffer.writeByte(123); // '{'
    final parentHasFields = _hasFields;
    _hasFields = false;
    block(this);
    _buffer.writeByte(125); // '}'
    _hasFields = parentHasFields;
  }

  @override
  void list<T>(
    String key,
    Iterable<T>? items, {
    void Function(JsonWriter writer, T item)? mapper,
  }) {
    _writeKey(key);
    if (items == null) {
      _writeNull();
      return;
    }
    _buffer.writeByte(91); // '['
    var first = true;
    for (final item in items) {
      if (first) {
        first = false;
      } else {
        _buffer.writeByte(44); // ','
      }
      if (mapper != null) {
        _buffer.writeByte(123); // '{'
        final parentHasFields = _hasFields;
        _hasFields = false;
        mapper(this, item);
        _buffer.writeByte(125); // '}'
        _hasFields = parentHasFields;
      } else {
        _writeValue(item);
      }
    }
    _buffer.writeByte(93); // ']'
  }

  @override
  void map<V>(
    String key,
    Map<String, V>? items, {
    void Function(JsonWriter writer, V value)? mapper,
  }) {
    _writeKey(key);
    if (items == null) {
      _writeNull();
      return;
    }
    _buffer.writeByte(123); // '{'
    final parentHasFields = _hasFields;
    _hasFields = false;

    if (mapper != null) {
      items.forEach((entryKey, entryValue) {
        _writeKey(entryKey);
        _buffer.writeByte(123); // '{'
        final innerHasFields = _hasFields;
        _hasFields = false;
        mapper(this, entryValue);
        _buffer.writeByte(125); // '}'
        _hasFields = innerHasFields;
      });
    } else {
      items.forEach((entryKey, entryValue) {
        _writeKey(entryKey);
        _writeValue(entryValue);
      });
    }

    _buffer.writeByte(125); // '}'
    _hasFields = parentHasFields;
  }

  void _writeNull() {
    _buffer.writeBytes(_nullBytes);
  }

  void _writeValue(Object? value) {
    if (value == null) {
      _writeNull();
    } else if (value is String) {
      _writeEscapedString(value);
    } else if (value is int) {
      _writeInteger(value);
    } else if (value is double) {
      _writeAsciiString(value.toString());
    } else if (value is bool) {
      _buffer.writeBytes(value ? _trueBytes : _falseBytes);
    } else {
      _buffer.writeBytes(utf8.encode(jsonEncode(value)));
    }
  }

  @pragma('vm:prefer-inline')
  void _writeEscapedString(String str) {
    _buffer.writeByte(34); // '"'
    var needsEscaping = false;
    final len = str.length;
    for (var i = 0; i < len; i++) {
      final c = str.codeUnitAt(i);
      if (c == 34 || c == 92 || c < 32 || c > 127) {
        needsEscaping = true;
        break;
      }
    }
    if (!needsEscaping) {
      _writeAsciiString(str);
    } else {
      _slowEscapeAndWrite(str);
    }
    _buffer.writeByte(34); // '"'
  }

  @pragma('vm:prefer-inline')
  void _writeAsciiString(String str) {
    final len = str.length;
    final targetLen = _buffer._length + len;
    if (targetLen > _buffer._bytes.length) {
      _buffer._grow(targetLen);
    }
    final bytes = _buffer._bytes;
    var offset = _buffer._length;
    for (var i = 0; i < len; i++) {
      bytes[offset++] = str.codeUnitAt(i);
    }
    _buffer._length = targetLen;
  }

  static const _digits2 =
      '0001020304050607080910111213141516171819'
      '2021222324252627282930313233343536373839'
      '4041424344454647484950515253545556575859'
      '6061626364656667686970717273747576777879'
      '8081828384858687888990919293949596979899';

  static const _hexDigits = [
    48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 97, 98, 99, 100, 101, 102
  ];

  void _writeInteger(int value) {
    if (value == 0) {
      _buffer.writeByte(48); // '0'
      return;
    }
    var v = value;
    if (v < 0) {
      _buffer.writeByte(45); // '-'
      v = -v;
    }
    var temp = v;
    var digits = 0;
    while (temp > 0) {
      digits++;
      temp ~/= 10;
    }
    final targetLen = _buffer._length + digits;
    if (targetLen > _buffer._bytes.length) {
      _buffer._grow(targetLen);
    }
    var pos = targetLen - 1;
    _buffer._length = targetLen;
    final bytes = _buffer._bytes;

    while (v >= 100) {
      final rem = v % 100;
      v ~/= 100;
      final idx = rem << 1;
      bytes[pos--] = _digits2.codeUnitAt(idx + 1);
      bytes[pos--] = _digits2.codeUnitAt(idx);
    }
    if (v < 10) {
      bytes[pos] = 48 + v;
    } else {
      final idx = v << 1;
      bytes[pos--] = _digits2.codeUnitAt(idx + 1);
      bytes[pos] = _digits2.codeUnitAt(idx);
    }
  }

  void _slowEscapeAndWrite(String str) {
    final len = str.length;
    for (var i = 0; i < len; i++) {
      final c = str.codeUnitAt(i);
      switch (c) {
        case 34: // "
          _buffer.writeByte(92);
          _buffer.writeByte(34);
        case 92: // \
          _buffer.writeByte(92);
          _buffer.writeByte(92);
        case 8: // \b
          _buffer.writeByte(92);
          _buffer.writeByte(98);
        case 12: // \f
          _buffer.writeByte(92);
          _buffer.writeByte(102);
        case 10: // \n
          _buffer.writeByte(92);
          _buffer.writeByte(110);
        case 13: // \r
          _buffer.writeByte(92);
          _buffer.writeByte(114);
        case 9: // \t
          _buffer.writeByte(92);
          _buffer.writeByte(116);
        default:
          if (c < 32) {
            _buffer.writeByte(92);
            _buffer.writeByte(117);
            _buffer.writeByte(48);
            _buffer.writeByte(48);
            _buffer.writeByte(_hexDigits[(c >> 4) & 0xF]);
            _buffer.writeByte(_hexDigits[c & 0xF]);
          } else if (c <= 127) {
            _buffer.writeByte(c);
          } else if (c <= 0x7FF) {
            _buffer.writeByte(0xC0 | (c >> 6));
            _buffer.writeByte(0x80 | (c & 0x3F));
          } else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < len) {
            final next = str.codeUnitAt(i + 1);
            if (next >= 0xDC00 && next <= 0xDFFF) {
              i++;
              final surrogate = 0x10000 + ((c & 0x3FF) << 10) + (next & 0x3FF);
              _buffer.writeByte(0xF0 | (surrogate >> 18));
              _buffer.writeByte(0x80 | ((surrogate >> 12) & 0x3F));
              _buffer.writeByte(0x80 | ((surrogate >> 6) & 0x3F));
              _buffer.writeByte(0x80 | (surrogate & 0x3F));
            } else {
              _buffer.writeByte(0xE0 | (c >> 12));
              _buffer.writeByte(0x80 | ((c >> 6) & 0x3F));
              _buffer.writeByte(0x80 | (c & 0x3F));
            }
          } else {
            _buffer.writeByte(0xE0 | (c >> 12));
            _buffer.writeByte(0x80 | ((c >> 6) & 0x3F));
            _buffer.writeByte(0x80 | (c & 0x3F));
          }
      }
    }
  }

  @override
  Uint8List toBytes() {
    if (!_closed) {
      _buffer.writeByte(125); // '}'
      _closed = true;
    }
    return _buffer.toBytes();
  }

  @override
  String toString() {
    return utf8.decode(toBytes());
  }
}

class _ByteBuffer {
  _ByteBuffer(int initialCapacity) : _bytes = Uint8List(initialCapacity);

  Uint8List _bytes;
  int _length = 0;

  @pragma('vm:prefer-inline')
  void writeByte(int byte) {
    if (_length >= _bytes.length) {
      _grow(_length + 1);
    }
    _bytes[_length++] = byte;
  }

  @pragma('vm:prefer-inline')
  void writeBytes(Uint8List bytes) {
    final newLen = _length + bytes.length;
    if (newLen > _bytes.length) {
      _grow(newLen);
    }
    _bytes.setRange(_length, newLen, bytes);
    _length = newLen;
  }

  void _grow(int minCapacity) {
    var newCap = _bytes.length * 2;
    if (newCap < minCapacity) {
      newCap = minCapacity;
    }
    final newBytes = Uint8List(newCap);
    newBytes.setRange(0, _length, _bytes);
    _bytes = newBytes;
  }

  Uint8List toBytes() {
    return Uint8List.sublistView(_bytes, 0, _length);
  }
}

final Uint8List _nullBytes = Uint8List.fromList(const [110, 117, 108, 108]);
final Uint8List _trueBytes = Uint8List.fromList(const [116, 114, 117, 101]);
final Uint8List _falseBytes = Uint8List.fromList(
  const [102, 97, 108, 115, 101],
);
