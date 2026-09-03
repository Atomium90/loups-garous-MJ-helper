import 'dart:convert';

import 'package:drift/drift.dart';

/// Encodes a plain list of strings (e.g. the Voleur's two reserve role ids,
/// `["chasseur", "villageois"]`) as a JSON-array string column. Same shape as
/// [RoleCountsConverter] - a single denormalized column beats a join table for
/// a fixed-size list.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
