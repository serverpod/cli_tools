import '../../config.dart'
    show UsageException, CommandUsageException, CommandDefinition;
import 'command_runner.dart' show CommandRunner;
import 'output_sinks.dart';

/// The settings and behavior for the usage output -
/// controls the help output and the usage exception output.
class UsageOutputHandler {
  final OutputSinks sinks;
  final UsageExceptionSettings exceptionSettings;

  final UsageExceptionHandler? _standardExceptionHandler;
  final List<UsageExceptionHandler> _additionalExceptionHandlers;

  List<UsageExceptionHandler> get exceptionHandlers => [
    ..._additionalExceptionHandlers,
    ?_standardExceptionHandler,
  ];

  /// The provided exception handlers are added before the standard exception handlers.
  ///
  /// The handler keeps its own growable copy of that list, so
  /// [addUsageExceptionHandler] works on every instance, including one
  /// constructed with no handlers.
  UsageOutputHandler({
    this.sinks = const OutputSinks(),
    this.exceptionSettings = const UsageExceptionSettings(),
    final Iterable<UsageExceptionHandler>? addExceptionHandlers,
  }) : _standardExceptionHandler = standardUsageExceptionHandler,
       _additionalExceptionHandlers = List.of(
         addExceptionHandlers ?? const <UsageExceptionHandler>[],
       );

  /// Replaces the standard exception handlers with the given exception handlers.
  UsageOutputHandler.replace({
    this.sinks = const OutputSinks(),
    this.exceptionSettings = const UsageExceptionSettings(),
    required final Iterable<UsageExceptionHandler> exceptionHandlers,
  }) : _standardExceptionHandler = null,
       _additionalExceptionHandlers = List.of(exceptionHandlers);

  /// Adds [handler] after the handlers already registered and before the
  /// standard handler.
  void addUsageExceptionHandler(final UsageExceptionHandler handler) {
    _additionalExceptionHandlers.add(handler);
  }

  /// Writes [command]'s usage to [sink], or to [sinks.out] when omitted
  /// (which is stdout unless overridden).
  void printUsage(
    final CommandDefinition command, {
    final StringSink? sink,
  }) {
    (sink ?? sinks.out).write(command.usage);
  }

  /// Handles a usage exception by invoking the registered exception handlers.
  /// Returns the exception if it shall be rethrown, or null if it is suppressed.
  UsageException? onUsageException(
    UsageException exception, {
    required final CommandDefinition? fromCommand,
  }) {
    for (final handler in exceptionHandlers) {
      final e = handler(exception, this, fromCommand: fromCommand);
      if (e == null) return null;
      exception = e;
    }
    return exception;
  }
}

////////////////////////
// UsageException handling and printing
////////////////////////

class UsageExceptionSettings {
  /// Set to true for [CommandRunner.run] to not throw [UsageException]
  /// on parsing and configuration input errors.
  final bool noUsageException;

  /// Set to true for [CommandRunner.run] to not print usage guidance on
  /// parsing and configuration input errors.
  final bool noUsageExceptionOutput;

  /// The printer for the usage exception output.
  final UsageExceptionPrinter exceptionPrinter;

  const UsageExceptionSettings({
    final bool? noUsageException,
    final bool? noUsageExceptionOutput,
    final UsageExceptionPrinter? exceptionPrinter,
  }) : noUsageException = noUsageException ?? false,
       noUsageExceptionOutput = noUsageExceptionOutput ?? false,
       exceptionPrinter =
           exceptionPrinter ?? const StandardUsageExceptionPrinter();
}

typedef UsageExceptionHandler =
    UsageException? Function(
      UsageException exception,
      UsageOutputHandler usageOutput, {
      required CommandDefinition? fromCommand,
    });

UsageException? standardUsageExceptionHandler(
  final UsageException exception,
  final UsageOutputHandler usageOutput, {
  required final CommandDefinition? fromCommand,
}) {
  const handler = StandardUsageExceptionHandler();
  return handler.onUsageException(
    exception,
    usageOutput,
    fromCommand: fromCommand,
  );
}

class StandardUsageExceptionHandler {
  const StandardUsageExceptionHandler();

  UsageException? onUsageException(
    final UsageException exception,
    final UsageOutputHandler usageOutput, {
    required final CommandDefinition? fromCommand,
  }) {
    if (!usageOutput.exceptionSettings.noUsageExceptionOutput) {
      final exceptionPrinter = usageOutput.exceptionSettings.exceptionPrinter;
      exceptionPrinter.printException(
        exception,
        usageOutput: usageOutput,
        fromCommand: fromCommand,
      );
    }
    if (usageOutput.exceptionSettings.noUsageException) {
      return null;
    }
    return exception;
  }
}

abstract class UsageExceptions {
  static UsageExceptionHandler simpleHandler(
    final void Function(
      UsageException exception,
      UsageOutputHandler usageOutput,
      CommandDefinition? fromCommand,
    )
    handler,
  ) {
    return (
      final UsageException exception,
      final UsageOutputHandler usageOutput, {
      required final CommandDefinition? fromCommand,
    }) {
      handler(exception, usageOutput, fromCommand);
      return exception;
    };
  }
}

/// Interface of a usage exception printer, which implements the layout and
/// formatting of a usage exception printed to [OutputSinks.err].
abstract interface class UsageExceptionPrinter {
  /// Prints a usage exception to [OutputSinks.err].
  ///
  /// If [exception] is a [CommandUsageException] (this is the expected normal
  /// case), the usage for its command is printed.
  /// If it is not, the [usage] field of the [UsageException] is printed,
  /// along with the [fromCommand] usage if provided.
  /// In other words [fromCommand] is only used as a fallback if the exception
  /// is not a [CommandUsageException].
  void printException(
    final UsageException exception, {
    required final UsageOutputHandler usageOutput,
    required final CommandDefinition? fromCommand,
  });
}

/// The standard implementation of [UsageExceptionPrinter] which implements the
/// default layout and formatting of a usage exception printed to [OutputSinks.err].
class StandardUsageExceptionPrinter implements UsageExceptionPrinter {
  const StandardUsageExceptionPrinter();

  @override
  void printException(
    final UsageException exception, {
    required final UsageOutputHandler usageOutput,
    final CommandDefinition? fromCommand,
  }) {
    usageOutput.sinks.err.writeln(exception.message);
    usageOutput.sinks.err.writeln('');

    if (exception is CommandUsageException) {
      usageOutput.printUsage(
        exception.command,
        sink: usageOutput.sinks.err,
      );
    } else {
      if (exception.usage.isNotEmpty) {
        usageOutput.sinks.err.writeln(exception.usage);
      }
      if (fromCommand != null) {
        if (exception.usage.isNotEmpty) usageOutput.sinks.err.writeln('---');
        usageOutput.printUsage(fromCommand, sink: usageOutput.sinks.err);
      }
    }
  }
}
