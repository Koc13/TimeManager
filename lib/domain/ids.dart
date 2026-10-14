import 'dart:math';

final _random = Random.secure();
const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// A short random ID with a type prefix, e.g. `t_3fq8kz2m`.
///
/// Prefixes: t_ task, g_ goal, h_ habit, s_ session, l_ goal log,
/// r_ recurring template. 36^8 ≈ 2.8e12 values, plenty for one person.
String newId(String prefix) =>
    '${prefix}_${List.generate(8, (_) => _alphabet[_random.nextInt(_alphabet.length)]).join()}';
