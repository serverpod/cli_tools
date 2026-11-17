import 'dart:async' show FutureOr;

import '../../config.dart' show OptionDefinition;
import 'command_context.dart';

/// ActionOptionMixin can be added to an option definition to make CommandRunner
/// run it as an "action option" when it is specified on the command line.
mixin ActionOptionMixin {
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
