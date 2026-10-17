import '../../config.dart'
    show UsageException, CommandUsageException, CommandDefinition;
import 'command_runner.dart' show CommandRunner;
// import 'usage_printer.dart' show StandardUsagePrinter;
import 'usage_sinks.dart';

class UsageOutputHandler {
  final UsageSinks sinks;
  // final UsagePrinter usagePrinter;
  final UsageExceptionSettings exceptionSettings;

  final UsageExceptionHandler? _standardExceptionHandler;
  final List<UsageExceptionHandler>? _additionalExceptionHandlers;

  List<UsageExceptionHandler> get exceptionHandlers => [
    ...?_additionalExceptionHandlers,
    ?_standardExceptionHandler,
  ];

  /// The provided exception handlers are added before the standard exception handlers.
  const UsageOutputHandler({
    this.sinks = const UsageSinks(),
    // this.usagePrinter = const StandardUsagePrinter(),
    this.exceptionSettings = const UsageExceptionSettings(),
    final List<UsageExceptionHandler>? addExceptionHandlers,
  }) : _standardExceptionHandler = standardUsageExceptionHandler,
       _additionalExceptionHandlers = addExceptionHandlers;

  /// Replaces the standard exception handlers with the given exception handlers.
  const UsageOutputHandler.replace({
    this.sinks = const UsageSinks(),
    // this.usagePrinter = const StandardUsagePrinter(),
    this.exceptionSettings = const UsageExceptionSettings(),
    required final List<UsageExceptionHandler> exceptionHandlers,
  }) : _standardExceptionHandler = null,
       _additionalExceptionHandlers = exceptionHandlers;

  /// Writes [command]'s usage to [sink], or to standard output when omitted.
  void printUsage(
    final CommandDefinition command, {
    final StringSink? sink,
  }) {
    (sink ?? sinks.out).write(command.usage);
  }

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

class UsageExceptionSettings {
  /// Set to true for [CommandRunner.execute] to not throw [UsageException]
  /// on parsing and configuration input errors.
  final bool noUsageException;

  /// Set to true for [CommandRunner.execute] to not print usage guidance on
  /// parsing and configuration input errors.
  final bool noUsageExceptionOutput;

  const UsageExceptionSettings({
    final bool? noUsageException,
    final bool? noUsageExceptionOutput,
  }) : noUsageException = noUsageException ?? false,
       noUsageExceptionOutput = noUsageExceptionOutput ?? false;
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
  final UsageExceptionPrinter exceptionPrinter;

  const StandardUsageExceptionHandler({
    this.exceptionPrinter = const StandardUsageExceptionPrinter(),
  });

  UsageException? onUsageException(
    final UsageException exception,
    final UsageOutputHandler usageOutput, {
    required final CommandDefinition? fromCommand,
  }) {
    if (!usageOutput.exceptionSettings.noUsageExceptionOutput) {
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
/// formatting of a usage exception printed to [UsageSinks.err].
abstract interface class UsageExceptionPrinter {
  /// Prints a usage exception to [UsageSinks.err].
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
/// default layout and formatting of a usage exception printed to [UsageSinks.err].
class StandardUsageExceptionPrinter implements UsageExceptionPrinter {
  const StandardUsageExceptionPrinter();

  @override
  void printException(
    final UsageException exception, {
    required final UsageOutputHandler usageOutput,
    required final CommandDefinition? fromCommand,
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
