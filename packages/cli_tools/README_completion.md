## Command line completion for scloud

There is now an experimental feature to generate and install command line
completion in bash for commands using `BetterCommandRunner`.

### Prerequisites

This requires the tool `completely`, which also requires ruby to be installed.

https://github.com/bashly-framework/completely

```sh
gem install completely
```

or with homebrew:

```sh
brew install brew-gem
brew gem install completely
```

### Activate

Construct `BetterCommandRunner` with the flag `experimentalCompletionCommand`
set to `true`.

### Install completion

When the `completely` tool is installed, run e.g:

```sh
my-command completion -f completely.yaml
completely generate completely.yaml completely.bash
mkdir -p ~/.local/share/bash-completion/completions
cp completely.bash ~/.local/share/bash-completion/completions/my-command.bash
```

This will write the completions script to `~/.local/share/bash-completion/completions/`,
where bash picks it up automatically on start.

In order to update the completions in the current bash shell, run:

```sh
exec bash
```

For end users, the generated bash script can be distributed as a file for them
to install directly.
