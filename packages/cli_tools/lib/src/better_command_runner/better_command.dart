import 'dart:async' show FutureOr;

import 'package:config/command.dart';
import 'package:config/config.dart';

import 'better_command_runner.dart';

/// An extension of [Command] with additional features.
///
/// The [BetterCommand] class uses the config library to provide
/// a more enhanced command line interface for running commands and handling
/// command line arguments, environment variables, and configuration.
abstract class BetterCommand<O extends OptionDefinition, T>
    extends BridgeCommand<O, T> {
  static const _defaultMessageOutput = MessageOutput(usageLogger: print);

  final MessageOutput? _messageOutput;

  /// Creates a new instance of [BetterCommand].
  ///
  /// - [options] is a list of options, empty by default.
  ///
  /// [messageOutput] is optional and will default to the
  /// value of the command runner (if any).
  ///
  /// ## Options
  ///
  /// To define a bespoke set of options, it is recommended to define
  /// a proper options enum. It can included any of the default options
  /// as well as any custom options. Example:
  ///
  /// ```dart
  /// enum BespokeOption<V> implements OptionDefinition<V> {
  ///   name(StringOption(
  ///     argName: 'name',
  ///     allowedValues: ['serverpod', 'stockholm'],
  ///     defaultsTo: 'serverpod',
  ///   )),
  ///   age(IntOption(argName: 'age', helpText: 'Required age', min: 0, max: 100));
  ///
  ///   const BespokeOption(this.option);
  ///
  ///   @override
  ///   final ConfigOptionBase<V> option;
  /// }
  /// ```
  BetterCommand({
    super.options = const [],
    @Deprecated('Unused, use usageOutput in BetterCommandRunner')
    final MessageOutput? messageOutput = _defaultMessageOutput,
    @Deprecated('Unused, use wrapTextColumn parameter in BetterCommandRunner')
    final int? wrapTextColumn,
    @Deprecated('Unused, see BetterCommandRunner')
    final Map<String, String>? env,
  }) : _messageOutput = messageOutput;

  @Deprecated('Unused, see usageOutput parameter in BetterCommandRunner')
  MessageOutput? get messageOutput {
    if (_messageOutput != _defaultMessageOutput) {
      return _messageOutput;
    }
    if (runner case final BetterCommandRunner<O, T> runner) {
      return runner.messageOutput;
    }
    return _messageOutput;
  }

  /// Runs this command.
  /// The default implementation runs the command subclass via [runWithConfig].
  @override
  FutureOr<T?> run(final CommandContext<O, T> context) {
    final config = context.config;
    return runWithConfig(config);
  }

  /// Runs this command with the resolved configuration (option values).
  /// Subclasses should override this method.
  FutureOr<T?> runWithConfig(final Configuration<O> commandConfig);
}
