// Returns help text for commands similar to `name`, in sorted order.
import 'dart:collection' show SplayTreeSet;
import 'dart:math' as math;

import 'command_definition.dart';

String similarCommandSuggestions(
  final String name,
  final Iterable<CommandDefinition> commands,
  final int suggestionDistanceLimit,
) {
  final candidates = similarCommands(name, commands, suggestionDistanceLimit);
  if (candidates.isEmpty) return '';
  return ' (Did you mean ${candidates.map((final command) => command.name).join(', ')}?)';
}

List<CommandDefinition> similarCommands(
  final String name,
  final Iterable<CommandDefinition> commands,
  final int suggestionDistanceLimit,
) {
  if (suggestionDistanceLimit <= 0) return [];
  final distances = <CommandDefinition, int>{};
  final candidates = SplayTreeSet<CommandDefinition>(
    (final a, final b) => distances[a]! - distances[b]!,
  );
  for (final command in commands) {
    if (command.usageDefinition.hidden) continue;
    for (final alias in [
      command.name,
      ...command.aliasesDefinition.aliases,
      ...command.aliasesDefinition.suggestionAliases,
    ]) {
      final distance = _editDistance(name, alias);
      if (distance <= suggestionDistanceLimit) {
        distances[command] = math.min(distances[command] ?? distance, distance);
        candidates.add(command);
      }
    }
  }
  return candidates.toList();
}

/// Returns the edit distance between `from` and `to`.
//
/// Allows for edits, deletes, substitutions, and swaps all as single cost.
///
/// See https://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance#Optimal_string_alignment_distance
int _editDistance(String from, String to) {
  // Add a space in front to mimic indexing by 1 instead of 0.
  from = ' $from';
  to = ' $to';
  final distances = [
    for (var i = 0; i < from.length; i++)
      [
        for (var j = 0; j < to.length; j++)
          if (i == 0) j else if (j == 0) i else 0,
      ],
  ];

  for (var i = 1; i < from.length; i++) {
    for (var j = 1; j < to.length; j++) {
      // Removals from `from`.
      var min = distances[i - 1][j] + 1;
      // Additions to `from`.
      min = math.min(min, distances[i][j - 1] + 1);
      // Substitutions (and equality).
      min = math.min(
        min,
        distances[i - 1][j - 1] +
            // Cost is zero if substitution was not actually necessary.
            (from[i] == to[j] ? 0 : 1),
      );
      // Allows for basic swaps, but no additional edits of swapped regions.
      if (i > 1 && j > 1 && from[i] == to[j - 1] && from[i - 1] == to[j]) {
        min = math.min(min, distances[i - 2][j - 2] + 1);
      }
      distances[i][j] = min;
    }
  }

  return distances.last.last;
}
