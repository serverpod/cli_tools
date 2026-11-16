import '../completion_shell.dart' show shellIdentifier, shellQuote, shellWord;

/// Generates the Bash completion script for the command [name].
///
/// The completion requests are sent to the command as typed, or to
/// [program] if given (when [name] is a wrapper of it).
///
/// Works with Bash 4.4+ fully, and degrades gracefully on Bash 3.2 (macOS):
/// there `compopt` is unavailable so the no-space and no-sort directives
/// are ignored. The bash-completion package is used when loaded
/// (`_init_completion`, `_filedir`) but is not required.
String bashCompletionScript(
  final String name,
  final String header, {
  final String? program,
}) {
  final fn = '__${shellIdentifier(name)}';
  return _template
      .replaceAll('__HEADER__', header)
      .replaceAll(
        '__PROGRAM__',
        program == null ? r'${words[0]}' : shellQuote(program),
      )
      .replaceAll('__FN__', fn)
      // The command name as an argument of `complete`: one word.
      .replaceAll('__EXE_WORD__', shellWord(name))
      .replaceAll('__EXE__', name);
}

const _template = r'''
# bash completion for __EXE__                               -*- shell-script -*-
#
__HEADER__

# Minimal replacement for _init_completion of the bash-completion package:
# sets words, cword and cur without treating '=' and ':' as word breaks.
__FN___init_completion()
{
    local i word prev=''
    words=()
    cword=0
    for ((i = 0; i < ${#COMP_WORDS[@]}; i++)); do
        word=${COMP_WORDS[i]}
        if ((i > 0)) && [[ $word == [=:] || $prev == [=:] ]]; then
            words[${#words[@]}-1]+=$word
        else
            words+=("$word")
        fi
        ((i == COMP_CWORD)) && cword=$((${#words[@]} - 1))
        prev=$word
    done
    cur=${words[cword]}
}

# The filename after a leading file-redirection operator, if $1 is one.
# Prints nothing and returns 0 for a bare operator (`>`, `2>`, `>>`).
# Returns 1 for ordinary words and for here-documents (`<<`, `<<<`).
# Kept in agreement with the redirection handling in the completion engine.
__FN___redirect_rest()
{
    case $1 in
        '<<<'*|'<<'*) return 1 ;;
    esac
    local re='^((\{[A-Za-z_][A-Za-z0-9_]*\})|[0-9]*|&)?(&>>|>>|>&|>\||<>|<&|&>|[<>])(.*)$'
    [[ $1 =~ $re ]] || return 1
    printf '%s' "${BASH_REMATCH[4]}"
}

# Appends the lines that compgen prints for the given arguments to COMPREPLY
# as they are: a file name such as `f[1].txt` is not expanded as a pattern.
__FN___compgen()
{
    local line
    while IFS= read -r line; do
        [[ -n $line ]] && COMPREPLY+=("$line")
    done <<<"$(compgen "$@")"
}

# File name completion: -d for directories only, or a pattern of file name
# extensions such as 'yaml|yml', or nothing for all files.
__FN___filedir()
{
    # The cursor word may be the operator itself (`><TAB>`) or an operator
    # glued to a filename (`>file`). Complete the filename part only.
    local rest
    if rest=$(__FN___redirect_rest "$cur"); then
        cur=$rest
    fi
    local first=${#COMPREPLY[@]} i
    if declare -F _filedir >/dev/null 2>&1; then
        if [[ $1 == -d || -z $1 ]]; then
            _filedir "$@"
        else
            _filedir "@($1)"
        fi
    else
        type compopt &>/dev/null && compopt -o filenames 2>/dev/null
        if [[ $1 == -d ]]; then
            __FN___compgen -d -- "$cur"
        elif [[ -n $1 ]]; then
            __FN___compgen -d -- "$cur"
            local ext
            local -a exts
            IFS='|' read -r -a exts <<<"$1"
            for ext in "${exts[@]}"; do
                __FN___compgen -f -X "!*.$ext" -- "$cur"
            done
        else
            __FN___compgen -f -- "$cur"
        fi
    fi
    # The file names replace a whole `--option=value` word when '=' is not
    # a word break (see valuePrefix in the caller): keep the option.
    if [[ -n $valuePrefix ]]; then
        for ((i = first; i < ${#COMPREPLY[@]}; i++)); do
            COMPREPLY[i]=$valuePrefix${COMPREPLY[i]}
        done
    fi
}

__FN___complete()
{
    local cur prev words cword
    COMPREPLY=()
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -n =: || return
    else
        __FN___init_completion || return
    fi

    # The completion request: the words before the cursor word, then the
    # (possibly empty) cursor word.
    local cmd=__PROGRAM__ out
    [[ $cmd == "~"* ]] && cmd=${HOME}${cmd#"~"}
    out=$("$cmd" __complete "${words[@]:1:cword-1}" "$cur" 2>/dev/null)

    # The last line of the response is the directive, e.g. ':4'.
    local directive=0 lastLine=${out##*$'\n'}
    if [[ $lastLine == :* ]]; then
        directive=${lastLine#:}
        if [[ $out == "$lastLine" ]]; then
            out=''
        else
            out=${out%$'\n'*}
        fi
    fi
    [[ $directive =~ ^[0-9]+$ ]] || directive=0

    local directiveError=1 directiveNoSpace=2 directiveNoFiles=4
    local directiveFileExt=8 directiveDirs=16 directiveKeepOrder=32

    ((directive & directiveError)) && return

    # When completing `--option=value`, the response holds the bare values.
    # Bash treats '=' as a word break (by default) and replaces only the part
    # after it, so complete that part only.
    local valuePrefix=''
    if [[ $cur == -*=* ]]; then
        [[ $COMP_WORDBREAKS != *=* ]] && valuePrefix=${cur%%=*}=
        cur=${cur#*=}
    fi

    if type compopt &>/dev/null; then
        ((directive & directiveNoSpace)) && compopt -o nospace
        ((directive & directiveKeepOrder)) && compopt -o nosort 2>/dev/null
    fi

    local -a comps=()
    local line
    while IFS= read -r line; do
        [[ -n $line ]] && comps+=("${line%%$'\t'*}")
    done <<<"$out"

    if ((directive & directiveFileExt)); then
        # The completions are the file extensions: join them to a pattern.
        local pattern
        pattern=$(IFS='|'; printf '%s' "${comps[*]}")
        __FN___filedir "$pattern"
    elif ((directive & directiveDirs)); then
        __FN___filedir -d
    else
        local comp
        for comp in "${comps[@]}"; do
            [[ $comp == "$cur"* ]] && COMPREPLY+=("$valuePrefix$comp")
        done
        if ((${#COMPREPLY[@]} == 0)); then
            ((directive & directiveNoFiles)) || __FN___filedir
        elif ((${#COMPREPLY[@]} == 1)); then
            # A single value is inserted as is: escape special characters.
            COMPREPLY[0]=$(printf '%q' "${COMPREPLY[0]}")
        fi
    fi

    # Bash replaces only the part of the word after the last ':' when ':'
    # is a word break, so remove the part up to it from the values.
    if [[ $cur == *:* && $COMP_WORDBREAKS == *:* ]]; then
        local prefix=$valuePrefix${cur%"${cur##*:}"} i
        for i in "${!COMPREPLY[@]}"; do
            COMPREPLY[i]=${COMPREPLY[i]#"$prefix"}
        done
    fi
}

complete -F __FN___complete __EXE_WORD__
''';
