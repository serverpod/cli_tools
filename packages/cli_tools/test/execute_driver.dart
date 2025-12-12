import 'dart:io';

import 'package:cli_tools/execute.dart';

void main(final List<String> args) async => exit(await execute(args.join(' ')));
