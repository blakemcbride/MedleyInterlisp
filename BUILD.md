# Building MedleyInterlisp

End-to-end instructions to build the VM (Maiko), the Lisp sysouts, and run the system. Run all commands from the repository root unless noted otherwise.

The shortest path:

```sh
make            # build the VM and the lisp/full sysouts
cd medley
./medley -f     # start Medley from full.sysout
```

The rest of this document covers prerequisites, optional targets, the underlying steps, and start-up flags.

## Prerequisites

A C compiler (clang preferred), CMake ≥ 3.15, and **SDL3**. X11 dev libraries are no longer required; pass `-DMAIKO_DISPLAY_X11=ON` to also build the X11 emulator (`ldex`).

### Linux (Debian / Ubuntu)
```sh
sudo apt update
sudo apt install build-essential clang cmake pkg-config libbsd-overlay-dev libsdl3-dev
# Optional: also build the X11 emulator (-DMAIKO_DISPLAY_X11=ON)
sudo apt install libx11-dev
```

### Linux (Fedora / RHEL)
```sh
sudo dnf install clang cmake pkgconf-pkg-config libbsd-devel SDL3-devel
# Optional: also build the X11 emulator
sudo dnf install libX11-devel
```

### macOS
```sh
brew install cmake sdl3
# Optional: also build the X11 emulator
brew install --cask xquartz
```

### `apps.sysout` (optional)

Building `apps.sysout` requires the NoteCards sources as a sibling of this repo:
```sh
cd ..
git clone https://github.com/Interlisp/notecards.git
cd MedleyInterlisp
```

## Step 1 — Build with `make`

From the repository root:

```sh
make           # builds Maiko, then the lisp and full sysouts
```

Other targets (`make help` lists them all):

| Target | Effect |
|---|---|
| `all` (default) | Build Maiko and the lisp/full sysouts |
| `maiko` | Build the VM only |
| `sysouts` | Build `lisp.sysout` and `full.sysout` (depends on `maiko`) |
| `apps` | Also build `apps.sysout` (requires `../notecards`) |
| `aux` | Rebuild `exports.all` and `whereis.hash` |
| `db` | Build the Masterscope database (`fuller.database`; several minutes) |
| `clean` | Remove intermediate build files; keep the runnable system |
| `realclean` | `clean`, plus remove every built artifact |

Example sequence to (re)build everything including `apps.sysout` and the Masterscope DB:

```sh
make realclean
make apps
make db
```

### What `make` produces

After a default `make`:

| Path | Contents |
|---|---|
| `maiko/<os>.<cpu>/lde` | runtime dispatcher (re-execs as `ldesdl` by default, `ldex` if you pass `-display X11` or an X11-style display string) |
| `maiko/<os>.<cpu>/ldesdl` | SDL3 emulator (default runtime) |
| `maiko/<os>.<cpu>/ldex` | X11 emulator (used by the loadup pipeline; runtime fallback) |
| `maiko/<os>.<cpu>/ldeinit` | bootstrap emulator used by the `mid` loadup stage |
| `medley/loadups/lisp.sysout` | base Lisp environment |
| `medley/loadups/full.sysout` | + library/lispusers + modernizations |
| `medley/loadups/exports.all` | external declarations |
| `medley/loadups/whereis.hash` | symbol → file index |

`make apps` adds `medley/loadups/apps.sysout` (NoteCards, ROOMS, CLOS); `make db` adds `medley/loadups/fuller.database`.

`<os>.<cpu>` is detected automatically (`linux.x86_64`, `darwin.aarch64`, etc.).

### Display backends

By default the build produces both SDL3 and X11 emulators; the `lde` dispatcher picks SDL3 at runtime unless you ask for X11. To opt out of either backend:

```sh
cmake -S maiko -B maiko/build -DMAIKO_DISPLAY_SDL=OFF   # X11 only
cmake -S maiko -B maiko/build -DMAIKO_DISPLAY_X11=OFF   # SDL3 only — note the loadup pipeline currently requires ldex/ldeinit
cmake -S maiko -B maiko/build -DMAIKO_DISPLAY_SDL=2     # legacy SDL2 instead of SDL3
cmake --build maiko/build && cmake --install maiko/build
```

## Step 2 — Direct build (without `make`)

The Makefile is a thin wrapper. The underlying commands are:

```sh
# Build Maiko
cmake -S maiko -B maiko/build
cmake --build maiko/build
cmake --install maiko/build

# Build sysouts
cd medley
./loadup                              # lisp + full
./loadup -apps                        # also apps.sysout
./scripts/loadups/loadup-db.sh        # fuller.database
```

Useful flags on `./loadup`:
- `--target <stage>` — stop after `init`, `mid`, `lisp`, `full`, or `apps`
- `--start <stage>` — resume from a stage whose input sysout already exists
- `-aux` — also rebuild `exports.all` and `whereis.hash`
- `-d <dir>` / `--maikodir <dir>` — override the Maiko binary location
- `-v` / `--vnc` — run the loadup inside Xvnc (headless / CI)
- `-z` / `--man` — display the `loadup(1)` man page

Examples:
```sh
./loadup --target lisp                  # build through lisp.sysout only
./loadup --start full --target apps     # rebuild apps from existing full.sysout
```

Sysouts land in `medley/loadups/`. The loadup work directory defaults to `/tmp/loadups-$$` and is auto-cleaned; set `LOADUP_WORKDIR=./tmp` to keep it.

## Step 3 — Start the system

The loadup scripts find the Maiko binaries automatically because `maiko/` is the sibling of `medley/`.

### Display

By default Medley runs through SDL3 (`ldesdl`).  SDL3 transparently uses Wayland or X11 underneath on Linux, the native compositor on macOS, and the native compositor on Windows.

- **Linux (Wayland or X11):** start in any normal session — no extra setup.
- **macOS:** no extra setup with SDL3.  (XQuartz is only needed if you opt into the X11 emulator with `-d X11`.)
- **WSL2:** SDL3 works through WSLg if available; otherwise install an X server (e.g. VcXsrv) and use `-d X11`.
- **Headless / SSH:** use `--vnc` (see below) or run `Xvfb`/`Xvnc` and set `DISPLAY`.

To force the X11 emulator instead of SDL3 — `./medley -d X11 ...`.

### Pick a launcher

```sh
cd medley
./medley [flags]               # primary launcher
./run-medley [flags]           # simpler legacy launcher
```

### Select a sysout

`./medley` chooses from `medley/loadups/`. Use one of:

| Flag | Starts from |
|---|---|
| `-a` / `--apps` | `apps.sysout` (NoteCards, ROOMS, CLOS) |
| `-f` / `--full` | `full.sysout` (libraries + modernizations) |
| `-l` / `--lisp` | `lisp.sysout` (base Lisp environment) |
| `-y FILE` / `--sysout FILE` | explicit sysout path |
| `-u` / `--continue` | resume from your last session's `~/lisp.virtualmem` |

`run-medley` accepts the same idea with `-full` / `-lisp` / `-apps` / `-n` / `-nl`, or a positional sysout filename.

A first-time start typically uses `-a` or `-f`:
```sh
./medley -a
```

### Window and screen size

```sh
./medley -a -g 1600x1000        # outer window geometry
./medley -a -s 1600x1000        # internal Medley screen size
./medley -a -ps 2               # SDL pixel scale factor (ldesdl only)
```

`run-medley` uses the same `-g WxH` and `-sc WxH`.

### Headless / VNC

```sh
./medley -a --vnc               # runs Medley inside an embedded VNC server
```

Connect a VNC client to the printed display (e.g. `:1`) on `localhost`. Not available on macOS or Windows/Cygwin.

### Other useful start-up flags

| Flag | Effect |
|---|---|
| `-r FILE` / `--greet FILE` | use `FILE` as the greetfile (`-r -` to skip) |
| `-x DIR` / `--logindir DIR` | use `DIR` as Medley's `LOGINDIR` |
| `-k FILE` / `--vmem FILE` | use `FILE` as the virtual-memory store |
| `-m N` / `--mem N` | set Medley memory size |
| `-t STRING` / `--title STRING` | set the X window title |
| `-d :N` / `--display :N` | use a specific X display |

`./medley --help` lists every option; `./medley --man` opens the man page.

### Exit

At the Interlisp prompt: `(LOGOUT)`. At the Common Lisp prompt: `(IL:LOGOUT)`. Logout writes `~/lisp.virtualmem` (override with `-k FILE` or the `LDEDESTSYSOUT` environment variable). The next `./medley -u` resumes from that image.

## CI builds

The same builds run from GitHub Actions:
- `maiko/.github/workflows/build.yml` — VM build across Linux + macOS
- `medley/.github/workflows/buildReleaseInclDocker.yml` — full build, release publish, Docker image (manual `workflow_dispatch`)
