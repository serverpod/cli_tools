import 'dart:async' show FutureOr;

import '../../config.dart' show ActionOptionDefinition, OptionDefinition;
import 'command_context.dart';

/// ActionOptionMixin can be added to an option definition to make CommandRunner
/// run it as an "action option" when it is specified on the command line.
///
/// As a convenience, access the full option object via the inherited [option]
/// getter.
mixin ActionOptionMixin<V> implements ActionOptionDefinition<V> {
  /// Whether this action option takes the place of a subcommand, so that it
  /// is a usage error to write a subcommand or another exclusive action
  /// option after it on the command line.
  ///
  /// True by default. `--help` is not exclusive: it can be written anywhere
  /// on the command line.
  @override
  bool get isExclusive => true;

  /// Whether this action option accepts a partial command line,
  /// i.e. runs even if the command line is incomplete.
  ///
  /// True by default for action options.
  ///
  /// {@macro acceptsPartialCommandLine}
  bool get acceptsPartialCommandLine => true;

  /// Runs this action option.
  /// [context] is the context of the command that defined this action option.
  FutureOr<R?> run<O extends OptionDefinition, R>(
    final CommandContext<O, R> context,
  );
}
