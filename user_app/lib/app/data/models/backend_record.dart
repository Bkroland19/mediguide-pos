import 'dart:convert';

abstract class Jsonable {
  Map<String, dynamic> toJson();
}

class RecordModel implements Jsonable {
  Map<String, dynamic> data;

  RecordModel([Map<String, dynamic>? data]) : data = data ?? {};

  static RecordModel fromJson(Map<String, dynamic> json) => RecordModel(json);

  String get id => get<String>('id', '');
  set id(String val) => data['id'] = val;

  String get collectionId => get<String>('collectionId', '');

  String get collectionName => get<String>('collectionName', '');

  String get created => get<String>('created', '');

  String get updated => get<String>('updated', '');

  T get<T>(String fieldNameOrPath, [T? defaultValue]) {
    final value = _extract(data, fieldNameOrPath);
    if (value == null) {
      if (defaultValue != null) return defaultValue;
      if (_isNullableType<T>()) return null as T;
      return _emptyValue<T>();
    }
    return _coerce<T>(value, defaultValue);
  }

  void set(String fieldName, dynamic value) {
    data[fieldName] = value;
  }

  String getStringValue(String fieldNameOrPath, [String? defaultValue]) {
    return get<String>(fieldNameOrPath, defaultValue ?? '');
  }

  List<T> getListValue<T>(String fieldNameOrPath, [List<T>? defaultValue]) {
    return get<List<T>>(fieldNameOrPath, defaultValue ?? <T>[]);
  }

  bool getBoolValue(String fieldNameOrPath, [bool? defaultValue]) {
    return get<bool>(fieldNameOrPath, defaultValue ?? false);
  }

  int getIntValue(String fieldNameOrPath, [int? defaultValue]) {
    return get<int>(fieldNameOrPath, defaultValue ?? 0);
  }

  double getDoubleValue(String fieldNameOrPath, [double? defaultValue]) {
    return get<double>(fieldNameOrPath, defaultValue ?? 0.0);
  }

  @override
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(data);

  @override
  String toString() => jsonEncode(data);
}

class ResultList<M extends Jsonable> implements Jsonable {
  int page;
  int perPage;
  int totalItems;
  int totalPages;
  List<M> items;

  ResultList({
    this.page = 0,
    this.perPage = 0,
    this.totalItems = 0,
    this.totalPages = 0,
    this.items = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
    'page': page,
    'perPage': perPage,
    'totalItems': totalItems,
    'totalPages': totalPages,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class ClientException implements Exception {
  final Uri? url;
  final bool isAbort;
  final int statusCode;
  final Map<String, dynamic> response;
  final dynamic originalError;

  ClientException({
    this.url,
    this.isAbort = false,
    this.statusCode = 0,
    this.response = const {},
    this.originalError,
  });

  @override
  String toString() {
    final errorData = <String, dynamic>{
      'url': url?.toString(),
      'isAbort': isAbort,
      'statusCode': statusCode,
      'response': response,
      'originalError': originalError,
    };
    return 'ClientException: $errorData';
  }
}

class AuthMethodsList {
  const AuthMethodsList();
}

class RecordSubscriptionEvent {
  final String action;
  final RecordModel? record;

  const RecordSubscriptionEvent({required this.action, this.record});
}

dynamic _extract(dynamic source, String path) {
  final segments = path.split('.');
  dynamic current = source;

  for (final segment in segments) {
    if (current is Map) {
      if (!current.containsKey(segment)) return null;
      current = current[segment];
      continue;
    }
    if (current is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= current.length) return null;
      current = current[index];
      continue;
    }
    return null;
  }

  return current;
}

T _coerce<T>(dynamic value, T? defaultValue) {
  if (value is T) return value;

  final target = _normalizeTargetType<T>();

  if (target == 'String') {
    return value.toString() as T;
  }
  if (target == 'bool') {
    if (value is bool) return value as T;
    if (value is num) return (value != 0) as T;
    final normalized = value.toString().trim().toLowerCase();
    return (normalized == 'true' ||
            normalized == '1' ||
            normalized == 'yes' ||
            normalized == 'on')
        as T;
  }
  if (target == 'int') {
    if (value is int) return value as T;
    if (value is num) return value.toInt() as T;
    return (int.tryParse(value.toString()) ?? (defaultValue as int? ?? 0)) as T;
  }
  if (target == 'double') {
    if (value is double) return value as T;
    if (value is num) return value.toDouble() as T;
    return (double.tryParse(value.toString()) ??
            (defaultValue as double? ?? 0.0))
        as T;
  }
  if (target == 'List<String>') {
    if (value is Iterable) {
      return value.map((entry) => entry.toString()).toList() as T;
    }
    return (defaultValue ?? <String>[]) as T;
  }
  if (target == 'List<dynamic>' ||
      target == 'List<Object?>' ||
      target == 'List') {
    if (value is Iterable) {
      return List<dynamic>.from(value) as T;
    }
    return (defaultValue ?? <dynamic>[]) as T;
  }
  if (target.startsWith('List<')) {
    if (value is Iterable) {
      return List<dynamic>.from(value) as T;
    }
    return (defaultValue ?? <dynamic>[]) as T;
  }
  if (target == 'Map<String, dynamic>' || target == 'Map<String,dynamic>') {
    if (value is Map<String, dynamic>) return value as T;
    if (value is Map) return Map<String, dynamic>.from(value) as T;
    return (defaultValue ?? <String, dynamic>{}) as T;
  }

  return value as T;
}

T _emptyValue<T>() {
  final target = _normalizeTargetType<T>();
  switch (target) {
    case 'String':
      return '' as T;
    case 'bool':
      return false as T;
    case 'int':
      return 0 as T;
    case 'double':
      return 0.0 as T;
    case 'List<String>':
    case 'List<dynamic>':
    case 'List<Object?>':
    case 'List':
      return <dynamic>[] as T;
    case 'Map<String, dynamic>':
    case 'Map<String,dynamic>':
      return <String, dynamic>{} as T;
    default:
      throw StateError('No default value available for type $target');
  }
}

bool _isNullableType<T>() => T.toString().endsWith('?');

String _normalizeTargetType<T>() {
  final target = T.toString();
  return _isNullableType<T>() ? target.substring(0, target.length - 1) : target;
}
