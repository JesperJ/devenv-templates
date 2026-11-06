# devenv-templates

The .NET development setup, solved once (SDKs, the VS Code C# Dev Kit on
NixOS, SQL Server), and `devenvify`, which puts it in a project in one
command. Installed on every machine by the
[wsl-reference](https://github.com/JesperJ/wsl-reference) baseline.

## Using it

```bash
cd ~/code/my-service
devenvify dotnet          # or dotnet-mssql; `devenvify` alone lists them
cd .                      # direnv builds the shell
```

That writes a small `devenv.yaml`, a near-empty `devenv.nix`, `.envrc` and
`.vscode/extensions.json`. Commit them, and `devenv.lock` after the first
build: a colleague who clones gets the same shell on their first `cd`.

For a repo you can't or don't want to commit devenv files to -- a
customer's, an open-source project:

```bash
devenvify --bind dotnet   # nothing is written into the repo's history
```

That binds the folder to the setup on this machine only
(`devenv --from ... allow`). devenv's own files and the `.envrc` are hidden
from git in `.git/info/exclude`, which belongs to your clone alone.

## How it fits together

```
modules/dotnet/       the shared .NET setup     <- projects IMPORT these
modules/mssql/        the shared SQL Server
dotnet/               thin templates: devenv.yaml imports the modules,
dotnet-mssql/         devenv.nix holds only the project's own additions
from/dotnet/          what --bind points at
from/dotnet-mssql/
devenvify             the command
```

A project does not get a copy of the shared setup; it imports it, the way a
`.csproj` references a NuGet package:

| File in the project | What it is | NuGet equivalent |
|---|---|---|
| `devenv.yaml` | where things come from: nixpkgs, devenv, this repo | `<PackageReference>` |
| `devenv.lock` | exactly which commit of each -- generated, committed | `packages.lock.json` |
| `devenv.nix` | the project's own additions on top | your code |

So a project's shell never changes by itself. An improvement to
`modules/dotnet` reaches a project when someone runs, in that project:

| Command | Moves | Then |
|---|---|---|
| `update-shared` | only this repo's modules | runs the tests, shows the lock diff |
| `update-toolchain` | everything: SDKs, nixpkgs, this repo | runs the tests, shows the lock diff |

Commit the lock change like any dependency bump; `git checkout devenv.lock`
undoes it.

## Changing the shared setup

Edit `modules/`, then try it in a project before pushing:

```bash
DEVENV_TEMPLATES_REPO=path:$HOME/code/repos/devenv-templates devenvify dotnet /tmp/try
```

Something only one project needs belongs in that project's `devenv.nix`, not
here. A shared value a project must differ on is overridden there with
`lib.mkForce`.

## Details

- `devenvify` pins devenv's own modules in each `devenv.yaml` it writes to the
  devenv installed on the machine. Unpinned, the first build locks the newest
  devenv on GitHub, and a devenv command older than its modules prints errors
  (`structuredAttrs: command not found`) into every shell.
- The templates also work with `nix flake init -t github:JesperJ/devenv-templates#dotnet`,
  which copies them verbatim (no `.gitignore` merge, no devenv pin).
- Projects set up before the shared modules existed have a full copy in their
  `devenv.nix`. To switch one over: `devenvify dotnet -f`, then move anything
  project-specific back into `devenv.nix`.
