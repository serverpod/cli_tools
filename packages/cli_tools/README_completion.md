## Command line completion for scloud

There is now an experimental feature to generate and install command line
completion in bash for commands using `BetterCommandRunner`.

### Enable experimental feature

Enable this experimental feature by constructing `BetterCommandRunner`
with the flag `experimentalCompletionCommand` set to `true`.

## Using the tool `carapace`

Carapace supports a lot of shells, including Bash, ZSH, Fish, Elvish,
Powershell, Cmd, and more.

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
my-command completion -f my-command.yaml -t carapace
cp example.yaml "${UserConfigDir}/carapace/specs/"
```

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

https://github.com/bashly-framework/completely

### Prerequisites

This requires the tool `completely`, which also requires ruby to be installed.

```sh
gem install completely
```

or with homebrew:

```sh
brew install brew-gem
brew gem install completely
```

### Install completion for the command

When the `completely` tool is installed, run e.g:

```sh
my-command completion -f my-command.yaml -t completely
completely generate my-command.yaml my-command.bash
mkdir -p ~/.local/share/bash-completion/completions
cp my-command.bash ~/.local/share/bash-completion/completions/
```

This will write the completions script to `~/.local/share/bash-completion/completions/`,
where bash picks it up automatically on start.

In order to update the completions in the current bash shell, run:

```sh
exec bash
```

### Distribution

For end users, the generated bash script can be distributed as a file for them
to install directly in their `~/.local/share/bash-completion/completions/`.
