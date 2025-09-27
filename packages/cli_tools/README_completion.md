## Command line completion

`BetterCommandRunner` can generate and install command line completion
in bash and some other shells for all its subcommands and options.

As command developer you will need to install an additional tool that generates
the completion shell script. Two tools are currently supported.

The shell script needs to be installed by end users to enable completion.

### Enable experimental feature

Enable this experimental feature by constructing `BetterCommandRunner`
with the flag `experimentalCompletionCommand` set to `true`.

## Using the tool `carapace`

Carapace supports a lot of shells, including Bash, ZSH, Fish, Elvish,
Powershell, Cmd, and more.
However end users need to install the `carapace` tool as well as the generated
script for the command.

https://carapace.sh/

### Prerequisites

This requires the tool `carapace`.

```sh
brew install carapace
```
For installing in other environments, see:
https://carapace-sh.github.io/carapace-bin/install.html

### Install completion for the command

When the `carapace` tool is installed, generate the completion for the command.

Note that the YAML file must have the same name as the command executable
before the `.yaml` extension.

```sh
my-command completion generate -f my-command.yaml -t carapace
cp my-command.yaml "${UserConfigDir}/carapace/specs/"
```

If you need to specify a specific command name to use in the generated YAML
file, use the `-e` option.

> Note: ${UserConfigDir} refers to the platform-specific user configuration
directory. On MacOS this is `~/Library/Application Support/` (even though many
other Bash commands use `~/.local/share/`), and on Windows this is `%APPDATA%`.
This can be overridden with the env var `XDG_CONFIG_HOME`, but be aware this
affects lots of applications.

Run the following once for the current shell,
or add to your shell startup script:

Bash:
```bash
source <(carapace my-command)
```

Zsh:
```zsh
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
source <(carapace my-command)
```

For more information and installing in other shells, see:
https://carapace-sh.github.io/carapace-bin/setup.html


### Distribution

End users will need to install `carapace` and copy the Yaml file to the proper
location, even if the Yaml file is distributed with the command.


## Using the tool `completely`

Completely supports Bash and ZSH. It's benefit is that it doesn't require the
end user to install any tool besides the generated shell completion script.

https://github.com/bashly-framework/completely

### Prerequisites

This requires the command developer to install the tool `completely`,
which also requires ruby to be installed.

```sh
gem install completely
```

or with homebrew:

```sh
brew install brew-gem
brew gem install completely
```

### Generate completion for the command

When the `completely` tool is installed, run commands similar to the following
to generate the bash completion script for the command.

```sh
my-command completion generate -f my-command.yaml -t completely
completely generate my-command.yaml my-command.bash
```

To install the completions in the bash shell, run:

```sh
mkdir -p ~/.local/share/bash-completion/completions
cp my-command.bash ~/.local/share/bash-completion/completions/
```

Completions scripts in `~/.local/share/bash-completion/completions/`
are automatically picked up by bash on start. Note that they must be named
the same as the command, except for the `.bash` suffix.

In order to update the completions in the current bash shell, run:

```sh
exec bash
```

If the completions directory already exists, you can update the completion
script with this one-liner which doesn't create the intermediate files.
(This approach requires that your command does not generate any other output
to `stdout` when run this way.)

```sh
my-command completion generate -t completely | completely generate - >~/.local/share/bash-completion/completions/my-command.bash
```

### ZSH

If you are using Oh-My-Zsh, bash completions should already be enabled.
Otherwise you should enable completion by adding this to your ~/.zshrc
(if is it not already there):

```sh
autoload -Uz +X compinit && compinit
autoload -Uz +X bashcompinit && bashcompinit
```

### Distribution

For end users, the generated bash script can be distributed as a file for them
to install directly in their `~/.local/share/bash-completion/completions/`.
