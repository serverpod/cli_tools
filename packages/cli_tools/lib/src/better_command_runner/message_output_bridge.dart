import 'package:config/command.dart'
    show UsageExceptionPrinter, UsageOutputHandler;
import 'package:config/config.dart' show UsageException, CommandDefinition;

import 'better_command_runner.dart' show MessageOutput;

class BridgeUsagePrinter implements StringSink {
  final MessageOutput messageOutput;

  const BridgeUsagePrinter(this.messageOutput);

  @override
  void write(final Object? object) {
    messageOutput.logUsage('$object');
  }

  @override
  void writeAll(final Iterable objects, [final String separator = '']) {
    messageOutput.logUsage(objects.join(separator));
  }

  @override
  void writeln([final Object? object = '']) {
    messageOutput.logUsage('$object\n');
  }

  @override
  void writeCharCode(final int charCode) {
    throw UnimplementedError('writeCharCode unsupported by BridgeUsagePrinter');
  }
}

/// The standard implementation of [UsageExceptionPrinter] which implements the
/// default layout and formatting of a usage exception printed to [UsageSinks.err].
class BridgeUsageExceptionPrinter implements UsageExceptionPrinter {
  final MessageOutput messageOutput;

  const BridgeUsageExceptionPrinter(this.messageOutput);

  @override
  void printException(
    final UsageException exception, {
    required final UsageOutputHandler usageOutput,
    required final CommandDefinition? fromCommand,
  }) {
    messageOutput.logUsageException(exception);
  }
}
