import '../completion_shell.dart' show shellIdentifier, shellQuote;

/// Generates the Fish completion script for the command [name].
///
/// The completion requests are sent to the command as typed, or to
/// [program] if given (when [name] is a wrapper of it).
String fishCompletionScript(
  final String name,
  final String header, {
  final String? program,
}) {
  final fn = '__${shellIdentifier(name)}';
  return _template
      .replaceAll('__HEADER__', header)
      .replaceAll(
        '__PROGRAM__',
        program == null ? r'$words[1]' : shellQuote(program),
      )
      .replaceAll('__FN__', fn)
      .replaceAll('__EXE__', name);
}

const _template = r'''
# fish completion for __EXE__                               -*- shell-script -*-
#
__HEADER__

# Tests whether bit $argv[2] is set in directive $argv[1].
function __FN___directive_has
    test (math "floor($argv[1] / $argv[2]) % 2") -eq 1
end

function __FN___complete
    # The words before the cursor word, and the (possibly empty) cursor word.
    set -l words (commandline -opc)
    set -l current (commandline -ct)
    test (count $current) -eq 0; and set current ''

    set -l cmd __PROGRAM__
    set -l out ($cmd __complete $words[2..-1] "$current" 2>/dev/null)

    # The last line of the response is the directive, e.g. ':4'.
    set -l directive 0
    if test (count $out) -gt 0; and string match -qr '^:[0-9]+$' -- "$out[-1]"
        set directive (string sub -s 2 -- "$out[-1]")
        set -e out[-1]
    end

    if __FN___directive_has $directive 1
        return 1
    end

    # When completing `--option=value`, the response holds the bare values
    # which are inserted after the option prefix.
    set -l prefix ''
    set -l value "$current"
    if string match -qr -- '^-[^=]*=' "$current"
        set prefix (string match -r -- '^-[^=]*=' "$current")
        set value (string replace -r -- '^-[^=]*=' '' "$current")
    end

    if __FN___directive_has $directive 8
        # Files with one of the given extensions, and directories.
        set -l exts (string join '|' -- (string escape --style=regex -- $out))
        for path in (__fish_complete_path "$value")
            set -l name (string split -m1 \t -- $path)[1]
            if string match -qr -- '/$' "$name"; or string match -qr -- "\\.($exts)\$" "$name"
                printf '%s%s\n' "$prefix" "$path"
            end
        end
    else if __FN___directive_has $directive 16
        for path in (__fish_complete_directories "$value")
            printf '%s%s\n' "$prefix" "$path"
        end
    else
        for comp in $out
            printf '%s%s\n' "$prefix" "$comp"
        end
        if test (count $out) -eq 0; and not __FN___directive_has $directive 4
            for path in (__fish_complete_path "$value")
                printf '%s%s\n' "$prefix" "$path"
            end
        end
    end
end

complete -c __EXE__ -e
complete -c __EXE__ -f -a '(__FN___complete)'
''';
