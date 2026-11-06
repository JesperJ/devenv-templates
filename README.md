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
| `--copy` | the parts themselves, in `.shared-devenv/` | the project, outright | someone edits `.shared-devenv/` |
| `--personal` | nothing in its history | you: the template is written to a folder on your machine, the lock pins which commit | you run `update-shared` there |

In every mode the project's `devenv.lock` pins nixpkgs, and with it the .NET
SDK and runtimes; `update-toolchain` moves it.

**`--shared`** is the default choice for your own repos: every project gets
the same setup, and improvements here reach a project when it takes them.
Commit `devenv.yaml`, `devenv.nix`, `.envrc`, `.vscode/`, and `devenv.lock`
after the first build: a colleague who clones gets the same shell on their
first `cd`.

**`--copy`** is for a project that must not depend on this repo: one handed
over to a customer, or that needs the setup changed in ways nobody else
wants. Commit the same files plus `.shared-devenv/`. Each copied file says
which commit it came from; nothing here reaches it again unless you take it
with `devenvify --copy <template> -f`. Its `devenv.yaml` imports the parts
as folders in the repo (`./.shared-devenv/dotnet`), so its `devenv.lock` has
no devenv-templates in it.

**`--personal`** is for a repo you can't or don't want to commit devenv files
to -- a customer's, an open-source project. The template's `devenv.yaml`
goes into a folder on your machine,
`~/.local/share/devenvify/personal/<folder>-<hash>/`, with a `devenv.nix` for
your own additions, and devenv binds the repo to it
(`devenv --from ... allow`). It works like `--shared` from there: the lock
pins the commit, `update-shared` moves it, and you choose parts by editing
that `devenv.yaml`. devenv's files in the repo -- the lock, `.devenv/`, the
`.envrc` -- are hidden from git in `.git/info/exclude`, which belongs to your
clone alone. It refuses a folder with a `devenv.nix` or `devenv.yaml` of its
own, which would override the binding. A rerun keeps your folder;
`-f` starts it over from the template.

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

In every mode the parts a project uses are the `imports:` in its
`devenv.yaml` -- the repo's, or with `--personal` the one on your machine --
and changing them is a one-line edit.

```
modules/<part>/         the parts: the setup itself
templates/<template>/   what a project gets: devenv.yaml listing the parts,
                        devenv.nix for its own additions, .envrc, .vscode/,
                        and the lines devenvify adds to .gitignore
devenvify               the command
package.nix, flake.nix  devenvify packaged with the templates and parts
```

One template serves all three modes. `--shared` writes it as it is,
`--copy` rewrites its `imports:` to `./.shared-devenv/<part>` and copies
the parts in, and `--personal` writes it to the folder on your machine.

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

Commit the lock change like any dependency bump. Both keep the lock from
before in `.devenv/devenv.lock.before`, and say how to put it back if the
tests fail.

## Changing the shared setup

Edit `modules/`, then try it in a project before pushing:

```bash
DEVENV_TEMPLATES_REPO=path:$HOME/code/repos/devenv-templates devenvify --shared dotnet /tmp/try
```

Something only one project needs belongs in that project's `devenv.nix`, not
here. A shared value a project must differ on is overridden there with
`lib.mkForce`.

A new part is a folder in `modules/` with a `devenv.nix`. To make it part of
a template, list it under `imports:` in the template's `devenv.yaml` -- the
one place, for all three modes. A new template is a folder in `templates/`.

Parts that add runtimes do it through `shared.dotnet.runtimes`, a list the
dotnet part declares and puts next to the SDK on the one `dotnet` command.

## Details

- `devenvify` pins devenv's own modules in each `devenv.yaml` it writes to the
  devenv installed on the machine. Unpinned, the first build locks the newest
  devenv on GitHub, and a devenv command older than its modules prints errors
  (`structuredAttrs: command not found`) into every shell.
- There is no `nix flake init -t` for the templates: it would set a project
  up without a mode and without the devenv pin. `devenvify` is the way in.
- `--personal` imports the parts through the devenv-templates input, never
  by relative path: devenv refuses `imports:` in a `--from` folder that reach
  outside it, but inputs are fine.
- `NIX_LD` in the dotnet part is not only for VS Code: `dotnet run` starts
  the app through a launcher Microsoft builds, which needs it just as the
  C# Dev Kit does. The comment in `modules/dotnet/devenv.nix` has the detail.
- Projects set up before the shared parts existed have a full copy in their
  `devenv.nix`. To switch one over: `devenvify --shared dotnet -f`, then move
  anything project-specific back into `devenv.nix`.
- `--bind` is now `--personal`.
