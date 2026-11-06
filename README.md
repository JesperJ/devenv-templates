# devenv-templates

The .NET development setup, solved once (the SDK and runtimes, the VS Code C#
Dev Kit on NixOS, SQL Server), and `devenvify`, which puts it in a project in
one command. Installed on every machine by the
[wsl-reference](https://github.com/JesperJ/wsl-reference) baseline.

## Using it

```bash
cd ~/code/my-service
devenvify --shared dotnet   # or dotnet-mssql; `devenvify` alone lists them
cd .                        # direnv builds the shell
```

`devenvify` needs a mode, and stops to explain them if you give none. The mode
decides who owns the setup:

| Mode | What the repo gets | Who owns the setup | It changes when |
|---|---|---|---|
| `--shared` | a `devenv.yaml` that imports the parts from this repo | this repo; the project's `devenv.lock` pins which commit | someone runs `update-shared` in the project |
| `--copy` | the parts themselves, in `devenv-shared/` | the project, outright | someone edits `devenv-shared/` |
| `--personal` | nothing in its history | this repo's `main`, bound on your machine only | this repo changes |

In every mode the project's `devenv.lock` pins nixpkgs, and with it the .NET
SDK and runtimes; `update-toolchain` moves it.

**`--shared`** is the default choice for your own repos: every project gets
the same setup, and improvements here reach a project when it takes them.
Commit `devenv.yaml`, `devenv.nix`, `.envrc`, `.vscode/`, and `devenv.lock`
after the first build: a colleague who clones gets the same shell on their
first `cd`.

**`--copy`** is for a project that must not depend on this repo: one handed
over to a customer, or that needs the setup changed in ways nobody else
wants. Commit the same files plus `devenv-shared/`. Each copied file says
which commit it came from; nothing here reaches it again unless you take it
with `devenvify --copy <template> -f`.

**`--personal`** is for a repo you can't or don't want to commit devenv files
to -- a customer's, an open-source project. devenv remembers on this machine
that the folder uses the template (`devenv --from ... allow`); its own files
and the `.envrc` are hidden from git in `.git/info/exclude`, which belongs to
your clone alone. It refuses a folder with a `devenv.nix` of its own, which
would silently replace the binding.

## Parts and templates

The setup is split into parts, and a template is a preset of parts:

| Part | What it is |
|---|---|
| `modules/dotnet` | the .NET 10 SDK, the nix-ld fix, `run-tests`, `update-shared`, `update-toolchain` |
| `modules/dotnet-runtime-8` | the .NET 8 runtime, so net8.0 projects run and test |
| `modules/mssql` | SQL Server in Docker (`devenv up`) and `sqlcmd` |

| Template | Parts |
|---|---|
| `dotnet` | dotnet, dotnet-runtime-8 |
| `dotnet-mssql` | dotnet, dotnet-runtime-8, mssql |

SDK 10 builds net8.0 projects on its own; running and testing them is what
needs the .NET 8 runtime. The runtime alone is a fraction of SDK 8 (about
190 MB against 740). .NET 8 support ends 10 November 2026, so the part is a
bridge: once a project targets net10.0 everywhere, remove
`dotnet-runtime-8` from the `imports:` in its `devenv.yaml`.

With `--shared` and `--copy`, the parts a project uses are the `imports:` in
its `devenv.yaml`, and changing them is a one-line edit. With `--personal`
there is nothing in the repo to edit, so it takes a template as a whole.

```
modules/<part>/       the parts                 <- --shared imports, --copy copies
dotnet/               templates: a devenv.yaml listing the parts, a near-empty
dotnet-mssql/         devenv.nix for the project's own additions, .envrc, .vscode/
from/dotnet/          the same presets for --personal (devenv --from)
from/dotnet-mssql/
devenvify             the command
```

## How --shared stays put

A `--shared` project does not get a copy of the setup; it imports it, the
way a `.csproj` references a NuGet package:

| File in the project | What it is | NuGet equivalent |
|---|---|---|
| `devenv.yaml` | where things come from: nixpkgs, devenv, this repo | `<PackageReference>` |
| `devenv.lock` | exactly which commit of each -- generated, committed | `packages.lock.json` |
| `devenv.nix` | the project's own additions on top | your code |

So a project's shell never changes by itself. An improvement to `modules/`
reaches a project when someone runs, in that project:

| Command | Moves | Then |
|---|---|---|
| `update-shared` | only this repo's parts | runs the tests, shows the lock diff |
| `update-toolchain` | everything: SDK, nixpkgs, this repo | runs the tests, shows the lock diff |

Commit the lock change like any dependency bump; `git checkout devenv.lock`
undoes it.

## Changing the shared setup

Edit `modules/`, then try it in a project before pushing:

```bash
DEVENV_TEMPLATES_REPO=path:$HOME/code/repos/devenv-templates devenvify --shared dotnet /tmp/try
```

Something only one project needs belongs in that project's `devenv.nix`, not
here. A shared value a project must differ on is overridden there with
`lib.mkForce`.

A new part is a folder in `modules/` with a `devenv.nix`. To make it part of
a template, list it in the template's `devenv.yaml` and in its `from/`
`devenv.nix`. The `from/` folders join parts with Nix `imports = [ ... ]`
rather than `devenv.yaml` `imports:`, because devenv refuses yaml imports
that reach outside the folder `--from` points at.

Parts that add runtimes do it through `shared.dotnet.runtimes`, a list the
dotnet part declares and puts next to the SDK on the one `dotnet` command.

## Details

- `devenvify` pins devenv's own modules in each `devenv.yaml` it writes to the
  devenv installed on the machine. Unpinned, the first build locks the newest
  devenv on GitHub, and a devenv command older than its modules prints errors
  (`structuredAttrs: command not found`) into every shell.
- The templates also work with `nix flake init -t github:JesperJ/devenv-templates#dotnet`,
  which copies them verbatim: the `--shared` setup, without the `.gitignore`
  merge or the devenv pin.
- `NIX_LD` in the dotnet part is not only for VS Code: `dotnet run` starts
  the app through a launcher Microsoft builds, which needs it just as the
  C# Dev Kit does. The comment in `modules/dotnet/devenv.nix` has the detail.
- Projects set up before the shared parts existed have a full copy in their
  `devenv.nix`. To switch one over: `devenvify --shared dotnet -f`, then move
  anything project-specific back into `devenv.nix`.
- `--bind` is now `--personal`.
