/// Generates a Carapace spec for the command [name].
///
/// The spec bridges to the `__complete` request of [program] (the
/// executable, which [name] is or wraps) via Carapace's Cobra bridge (the
/// request protocol is the same), so it needs to be installed only once in
/// the Carapace specs directory.
/// See https://carapace-sh.github.io/carapace-bin/spec.html.
String carapaceCompletionSpec(
  final String name,
  final String header, {
  required final String program,
  final String? description,
}) {
  final summary = description?.trim().split('\n').first.trim();
  final buffer = StringBuffer()
    ..writeln('# carapace spec for $name')
    ..writeln('#')
    ..writeln(header)
    ..writeln('name: ${_yamlString(name)}');
  if (summary != null && summary.isNotEmpty) {
    buffer.writeln('description: ${_yamlString(summary)}');
  }
  buffer
    ..writeln('parsing: disabled')
    ..writeln('completion:')
    ..writeln('  positionalany:')
    ..writeln('    - ${_yamlString('\$carapace.bridge.Cobra([$program])')}');
  return buffer.toString();
}

/// A double-quoted YAML scalar.
String _yamlString(final String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n');
  return '"$escaped"';
}
