import 'dart:convert';

import 'package:drift/drift.dart';

/// Encodes a composition's role-id-to-count map (e.g. `{"loup_garou": 2}`)
/// as a JSON string column. A single denormalized column is simpler than a
/// join table for a composition of a dozen or so role entries.
class RoleCountsConverter extends TypeConverter<Map<String, int>, String> {
  const RoleCountsConverter();

  @override
  Map<String, int> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as Map<String, dynamic>).cast<String, int>();

  @override
  String toSql(Map<String, int> value) => jsonEncode(value);
}
