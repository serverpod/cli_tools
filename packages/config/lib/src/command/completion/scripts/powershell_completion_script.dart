import '../completion_shell.dart' show shellIdentifier;

/// Generates the PowerShell completion script for the command [name].
///
/// The completion requests are sent to the command as typed, or to
/// [program] if given (when [name] is a wrapper of it).
///
/// Requires PowerShell 5.1+.
String powershellCompletionScript(
  final String name,
  final String header, {
  final String? program,
}) {
  final fn = '__${shellIdentifier(name)}';
  return _template
      .replaceAll('__HEADER__', header)
      .replaceAll(
        '__PROGRAM__',
        program == null ? r'$words[0]' : _quote(program),
      )
      .replaceAll('__FN__', fn)
      .replaceAll('__EXE__', name);
}

/// [value] as a single-quoted PowerShell string literal.
String _quote(final String value) => "'${value.replaceAll("'", "''")}'";

const _template = r'''
# powershell completion for __EXE__                         -*- shell-script -*-
#
__HEADER__

[scriptblock]$__FN___completer = {
    param($WordToComplete, $CommandAst, $CursorPosition)

    $directiveError = 1
    $directiveNoSpace = 2
    $directiveNoFiles = 4
    $directiveFileExt = 8
    $directiveDirs = 16
    $directiveKeepOrder = 32

    # The words before the cursor word, and the (possibly empty) cursor word.
    # The cursor may have been moved back: complete up to the cursor word.
    $words = @()
    $current = ''
    foreach ($element in $CommandAst.CommandElements) {
        $extent = $element.Extent
        if ($extent.StartOffset -ge $CursorPosition) { break }
        if ($element -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $text = $element.Value
        } else {
            $text = $extent.Text
        }
        if ($extent.EndOffset -lt $CursorPosition) {
            $words += $text
            continue
        }
        if ($extent.EndOffset -gt $CursorPosition) {
            $text = $extent.Text.Substring(0, $CursorPosition - $extent.StartOffset)
        }
        $current = $text
        break
    }
    if ($words.Count -eq 0) { return }
    $program = __PROGRAM__
    $arguments = @($words | Select-Object -Skip 1)

    # Before PowerShell 7.3 (or in legacy argument passing mode) an empty
    # string argument is dropped unless passed as "".
    $requestWord = $current
    if ($current -eq '') {
        $legacy = ($PSVersionTable.PSVersion -lt [version]'7.3.0') -or
            ($PSNativeCommandArgumentPassing -eq 'Legacy')
        if ($legacy) { $requestWord = '""' }
    }

    $out = @(& $program __complete @arguments $requestWord 2>$null)

    # The last line of the response is the directive, e.g. ':4'.
    $directive = 0
    if ($out.Count -gt 0 -and $out[-1] -match '^:(\d+)$') {
        $directive = [int]$Matches[1]
        $out = @($out | Select-Object -SkipLast 1)
    }

    if (($directive -band $directiveError) -ne 0) { return }

    # When completing `--option=value`, the response holds the bare values
    # which are inserted after the option prefix.
    $prefix = ''
    $value = $current
    if ($current -match '^(-[^=]*=)(.*)$') {
        $prefix = $Matches[1]
        $value = $Matches[2]
    }

    $space = ' '
    if (($directive -band $directiveNoSpace) -ne 0) { $space = '' }
    try {
        $mode = (Get-PSReadLineKeyHandler -ErrorAction Stop | Where-Object { $_.Key -eq 'Tab' }).Function
    } catch {
        $mode = ''
    }
    if ($mode -ne 'Complete' -and $mode -ne 'MenuComplete') { $space = '' }

    function New-Result($text, $listText, $type, $toolTip) {
        if (-not $toolTip) { $toolTip = $listText }
        [System.Management.Automation.CompletionResult]::new($text, $listText, $type, $toolTip)
    }

    # Path completion for directories, or files with the given extensions.
    function Complete-Paths($dirsOnly, $extensions) {
        $dir = [System.IO.Path]::GetDirectoryName($value)
        Get-ChildItem -Path "$value*" -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $isDir = $_.PSIsContainer
            if ($dirsOnly -and -not $isDir) { return }
            if ($extensions -and -not $isDir -and ($extensions -notcontains $_.Extension.TrimStart('.'))) { return }
            $name = $_.Name
            $path = if ($dir) { Join-Path $dir $name } else { $name }
            if ($isDir) { $path += [System.IO.Path]::DirectorySeparatorChar }
            $type = if ($isDir) { 'ProviderContainer' } else { 'ProviderItem' }
            New-Result "$prefix$path" $name $type $path
        }
    }

    if (($directive -band $directiveFileExt) -ne 0) {
        Complete-Paths $false @($out)
        return
    }
    if (($directive -band $directiveDirs) -ne 0) {
        Complete-Paths $true $null
        return
    }

    $results = @($out | ForEach-Object {
        $name, $description = $_.Split("`t", 2)
        if ($name -like "$value*") {
            [PSCustomObject]@{ Name = $name; Description = $description }
        }
    })
    if (($directive -band $directiveKeepOrder) -eq 0) {
        $results = @($results | Sort-Object -Property Name)
    }

    if ($results.Count -eq 0) {
        # Nothing matched: PowerShell completes paths when nothing is
        # returned. Returning a single space prevents that (an empty
        # string is rejected by CompletionResult).
        if (($directive -band $directiveNoFiles) -ne 0) { ' ' }
        return
    }

    $escape = '\s|#|@|\$|;|,|''|\{|\}|\(|\)|"|`|\||<|>|&'
    foreach ($result in $results) {
        $text = $prefix + ($result.Name -replace $escape, '`$&')
        if ($results.Count -eq 1 -or $mode -eq 'MenuComplete') { $text += $space }
        New-Result $text $result.Name 'ParameterValue' $result.Description
    }
}

Register-ArgumentCompleter -Native -CommandName '__EXE__' -ScriptBlock $__FN___completer
''';
