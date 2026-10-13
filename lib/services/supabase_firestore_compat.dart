import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class FirebaseException implements Exception {
  final String plugin;
  final String code;
  final String? message;
  const FirebaseException({
    this.plugin = 'supabase',
    this.code = 'database',
    this.message,
  });
}

class Timestamp {
  final DateTime _value;
  Timestamp.fromDate(DateTime value) : _value = value;
  DateTime toDate() => _value;
}

class ServerTimestampValue {
  const ServerTimestampValue();
}

class DeleteFieldValue {
  const DeleteFieldValue();
}

class IncrementFieldValue {
  final num amount;
  const IncrementFieldValue(this.amount);
}

class FieldValue {
  static ServerTimestampValue serverTimestamp() => const ServerTimestampValue();
  static DeleteFieldValue delete() => const DeleteFieldValue();
  static IncrementFieldValue increment(num value) => IncrementFieldValue(value);
}

class SetOptions {
  final bool merge;
  const SetOptions({this.merge = false});
}

class FirebaseFirestore {
  FirebaseFirestore._();
  static final instance = FirebaseFirestore._();
  final SupabaseClient _client = Supabase.instance.client;

  CollectionReference<Map<String, dynamic>> collection(String name) =>
      CollectionReference<Map<String, dynamic>>._(_client, name);

  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) action,
  ) async {
    final transaction = Transaction();
    final result = await action(transaction);
    await transaction._commit();
    return result;
  }

  WriteBatch batch() => WriteBatch();
}

class Query<T> {
  final SupabaseClient _client;
  final String table;
  final List<({String field, Object? value})> _filters;
  final int? _limit;

  Query._(this._client, this.table, [this._filters = const [], this._limit]);

  Query<T> where(String field, {Object? isEqualTo}) => Query<T>._(
    _client,
    table,
    [..._filters, (field: field, value: isEqualTo)],
    _limit,
  );

  Query<T> limit(int value) => Query<T>._(_client, table, _filters, value);

  Future<QuerySnapshot<T>> get() async {
    final rows = await _client.from(table).select('id,data');
    final docs = <QueryDocumentSnapshot<T>>[];
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final data = _decodeMap(
        Map<String, dynamic>.from(row['data'] as Map? ?? const {}),
      );
      final matches = _filters.every(
        (f) => _valuesEqual(data[f.field], f.value),
      );
      if (!matches) {
        continue;
      }
      docs.add(
        QueryDocumentSnapshot<T>._(
          row['id'].toString(),
          data as T,
          DocumentReference<T>._(_client, table, row['id'].toString()),
        ),
      );
      if (_limit != null && docs.length >= _limit) {
        break;
      }
    }
    return QuerySnapshot<T>(docs);
  }

  Stream<QuerySnapshot<T>> snapshots() async* {
    yield await get();
    await for (final _ in Stream<void>.periodic(const Duration(seconds: 2))) {
      yield await get();
    }
  }
}

class CollectionReference<T> extends Query<T> {
  // ignore: use_super_parameters
  CollectionReference._(SupabaseClient client, String table)
    : super._(client, table);

  DocumentReference<T> doc([String? id]) =>
      DocumentReference<T>._(_client, table, id ?? _newId());

  Future<DocumentReference<T>> add(Map<String, dynamic> data) async {
    final ref = doc();
    await ref.set(data as T);
    return ref;
  }
}

class DocumentReference<T> {
  final SupabaseClient _client;
  final String table;
  final String id;
  DocumentReference._(this._client, this.table, this.id);

  Future<DocumentSnapshot<T>> get() async {
    final rows = await _client
        .from(table)
        .select('id,data')
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) {
      return DocumentSnapshot<T>._(id, null, this);
    }
    final row = Map<String, dynamic>.from(rows.first);
    final data = _decodeMap(
      Map<String, dynamic>.from(row['data'] as Map? ?? const {}),
    );
    return DocumentSnapshot<T>._(id, data as T, this);
  }

  Future<void> set(T data, [SetOptions? options]) async {
    final map = Map<String, dynamic>.from(data as Map);
    final existing = await get();
    final base = options?.merge == true
        ? existing.data() as Map<String, dynamic>?
        : null;
    final processed = _applyValues(map, base);
    await _client.from(table).upsert({'id': id, 'data': processed});
  }

  Future<void> update(Map<String, dynamic> values) async {
    final existing = await get();
    if (!existing.exists) {
      throw StateError('Document $table/$id does not exist.');
    }
    final current = Map<String, dynamic>.from(existing.data() as Map);
    final processed = _applyValues(values, current);
    final rows = await _client
        .from(table)
        .update({'data': processed})
        .eq('id', id)
        .select('id,data');
    if (rows.isEmpty) {
      throw StateError(
        'Update failed for $table/$id. The row was not changed.',
      );
    }
  }

  Future<void> delete() => _client.from(table).delete().eq('id', id);
}

class DocumentSnapshot<T> {
  final String id;
  final T? _data;
  final DocumentReference<T> reference;
  DocumentSnapshot._(this.id, this._data, this.reference);
  bool get exists => _data != null;
  T? data() => _data;
}

class QueryDocumentSnapshot<T> extends DocumentSnapshot<T> {
  // ignore: use_super_parameters
  QueryDocumentSnapshot._(String id, T data, DocumentReference<T> reference)
    : super._(id, data, reference);
  @override
  T data() => super.data() as T;
}

class QuerySnapshot<T> {
  final List<QueryDocumentSnapshot<T>> docs;
  QuerySnapshot(this.docs);
}

class Transaction {
  final List<Future<void> Function()> _operations = [];
  Future<DocumentSnapshot<T>> get<T>(DocumentReference<T> ref) => ref.get();
  void set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) =>
      _operations.add(() => ref.set(data, options));
  Future<void> _commit() async {
    for (final operation in _operations) {
      await operation();
    }
  }
}

class WriteBatch {
  final List<Future<void> Function()> _operations = [];
  void set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) =>
      _operations.add(() => ref.set(data, options));
  void delete<T>(DocumentReference<T> ref) => _operations.add(ref.delete);
  Future<void> commit() async {
    for (final operation in _operations) {
      await operation();
    }
  }
}

bool _valuesEqual(Object? a, Object? b) {
  if (a is Timestamp) {
    a = a.toDate();
  }
  if (b is Timestamp) {
    b = b.toDate();
  }
  return a == b;
}

Map<String, dynamic> _applyValues(
  Map<String, dynamic> updates,
  Map<String, dynamic>? existing,
) {
  final result = Map<String, dynamic>.from(existing ?? const {});
  for (final entry in updates.entries) {
    final value = entry.value;
    if (value is DeleteFieldValue) {
      result.remove(entry.key);
    } else if (value is ServerTimestampValue) {
      result[entry.key] = DateTime.now().toUtc().toIso8601String();
    } else if (value is IncrementFieldValue) {
      result[entry.key] = ((result[entry.key] as num?) ?? 0) + value.amount;
    } else if (value is Timestamp) {
      result[entry.key] = value.toDate().toUtc().toIso8601String();
    } else {
      result[entry.key] = _encodeValue(value);
    }
  }
  // Existing documents are decoded for Flutter compatibility, so fields such
  // as created_at may already be Timestamp objects. Supabase JSONB can only
  // receive JSON-encodable values. Normalize the complete merged document,
  // not only the fields changed in this update.
  return Map<String, dynamic>.from(_encodeValue(result) as Map);
}

Object? _encodeValue(Object? value) {
  if (value is Timestamp) {
    return value.toDate().toUtc().toIso8601String();
  }
  if (value is List) {
    return value.map(_encodeValue).toList();
  }
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _encodeValue(v)));
  }
  return value;
}

Map<String, dynamic> _decodeMap(Map<String, dynamic> source) {
  return source.map((key, value) {
    if (value is Map) {
      return MapEntry(key, _decodeMap(Map<String, dynamic>.from(value)));
    }
    if (value is List) {
      return MapEntry(
        key,
        value
            .map((e) => e is Map ? _decodeMap(Map<String, dynamic>.from(e)) : e)
            .toList(),
      );
    }
    if (value is String &&
        (key.endsWith('_at') ||
            key == 'timestamp' ||
            key == 'created_at' ||
            key == 'updated_at' ||
            key == 'expires_at' ||
            key == 'closed_at')) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return MapEntry(key, Timestamp.fromDate(parsed.toLocal()));
      }
    }
    return MapEntry(key, value);
  });
}

String _newId() {
  final r = Random.secure();
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final random = List.generate(
    12,
    (_) => r.nextInt(36).toRadixString(36),
  ).join();
  return '$time$random';
}
