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

### Windows (Cygwin)

The Windows build runs under [Cygwin](https://cygwin.com) with the SDL3 backend. Native Windows toolchains (MSVC, MSYS2 UCRT64) are **not** supported — the VM relies on a POSIX surface (`fork`, termios/PTY, `SIGALRM`/`setitimer`, AF_UNIX sockets) and the build pipeline is bash-driven, so Cygwin is the only viable path. X11 is not used on Windows; build SDL3 only.

1. Install Cygwin from https://cygwin.com (run `setup-x86_64.exe`).
2. Add the required packages — either tick them in the setup GUI, or from a Windows command prompt run:
   ```
   setup-x86_64.exe -q -P gcc-core,make,cmake,pkg-config,libSDL3-devel,git,bash
   ```
   Recommended additions for the Lisp loadups and day-to-day use: `coreutils`, `findutils`, `grep`, `sed`, `gawk`, `xz`, `gzip`, `tar`, `which`, `procps-ng`.
3. From a **Cygwin terminal** (not PowerShell or `cmd.exe`), clone the repository and run the same commands as on Linux/macOS:
   ```sh
   git clone https://github.com/blakemcbride/MedleyInterlisp.git
   cd MedleyInterlisp
   make
   ```
   The defaults (`MAIKO_DISPLAY_SDL=3`, `MAIKO_DISPLAY_X11=OFF`) produce a Cygwin SDL3 binary; no X server is needed.

Notes:
- All build and run commands must be issued from inside a Cygwin shell. The loadup scripts and `medley.command` are bash scripts and use Cygwin path conventions.
- Do not pass `-DMAIKO_DISPLAY_X11=ON` on Windows. The legacy `bin/makefile-cygwin.x86_64-x` X11 makefile is retained only as a historical artifact and is not a supported build path.
- The `--vnc` launcher flag is not available on Windows/Cygwin (see "Headless / VNC" below).

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
| `maiko/<os>.<cpu>/lde` | runtime dispatcher (re-execs as `ldesdl` by default; re-execs as `ldex` if the X11 emulator was built and you pass `-display X11` or an X11-style display string) |
| `maiko/<os>.<cpu>/ldesdl` | SDL3 emulator (default runtime) |
| `maiko/<os>.<cpu>/ldex` | X11 emulator — only built with `-DMAIKO_DISPLAY_X11=ON` |
| `maiko/<os>.<cpu>/ldeinit` | bootstrap emulator used by the `mid` loadup stage |
| `medley/loadups/lisp.sysout` | base Lisp environment |
| `medley/loadups/full.sysout` | + library/lispusers + modernizations |
| `medley/loadups/exports.all` | external declarations |
| `medley/loadups/whereis.hash` | symbol → file index |

`make apps` adds `medley/loadups/apps.sysout` (NoteCards, ROOMS, CLOS); `make db` adds `medley/loadups/fuller.database`.

`<os>.<cpu>` is detected automatically (`linux.x86_64`, `darwin.aarch64`, etc.).

### Display backends

By default the build produces only the SDL3 emulator (`ldesdl`); the `lde` dispatcher always re-execs into it. The X11 emulator (`ldex`) is opt-in:

```sh
cmake -S maiko -B maiko/build -DMAIKO_DISPLAY_X11=ON                          # also build ldex
cmake -S maiko -B maiko/build -DMAIKO_DISPLAY_SDL=OFF -DMAIKO_DISPLAY_X11=ON  # X11 only
cmake -S maiko -B maiko/build -DMAIKO_DISPLAY_SDL=2                           # legacy SDL2 instead of SDL3
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
- **Windows (Cygwin):** no extra setup — SDL3 renders directly through the native Windows compositor. WSL/WSL2 is not a supported environment for this fork; build and run from a Cygwin terminal (see Prerequisites).
- **Headless / SSH:** use `--vnc` (see below) or run `Xvfb`/`Xvnc` and set `DISPLAY`.

To force the X11 emulator instead of SDL3 — `./medley -d X11 ...` (requires building with `-DMAIKO_DISPLAY_X11=ON`).

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

## System Limitations

The following limitations apply to the current system. They are inherent in the underlying Interlisp implementation and the structure of the saved sysouts; working around them requires substantial engineering beyond ordinary code changes.

- **Maximum internal screen size is approximately 2 million pixels.** The Medley internal screen cannot exceed about 2,097,152 pixels total. Practical defaults that fit within this limit include 1408×1488 (balanced), 1280×1638 (taller, narrower), 1024×2048 (tallest, narrowest), and 1920×1092 (widest, shorter). Picking dimensions whose product exceeds the cap clamps the height down.

- **Resizing the outer window does not enlarge the Lisp screen.** When the outer Medley window is made larger than the internal screen — either manually or by a tiling window manager (i3, sway, etc.) — Medley fills the extra space with the desktop shade pattern, but internal Lisp windows cannot be moved into that area. There is a visible boundary at the bottom-right of the internal screen.

- **Prompt Window may appear with a black background on first launch.** When Medley starts from a freshly built sysout (no previously saved `~/lisp.virtualmem`), the Prompt Window content area may show as black instead of the usual white. The Exec window may also briefly appear with reversed colors. The Exec window self-corrects as soon as Lisp produces output (greet message, prompt scrolling); the Prompt Window remains black until something writes to it. Both cosmetic anomalies disappear after `(LOGOUT)` and a subsequent `./medley -u` resume from `~/lisp.virtualmem`.

- **Monochrome display only.** Medley's screen is a 1-bit black-and-white bitmap by design, reflecting the original Interlisp environment. There is no color rendering mode.

- **Linux tiling-WM caveat.** On Linux with tiling window managers, the outer window will be resized to fit a tile. The internal screen size stays fixed regardless. If you prefer Medley as a floating window in i3/sway, mark it floating in your window-manager configuration.

- **16-bit word legacy.** The Interlisp memory model is built around 16-bit words. Many internal data structures inherit limits from this base unit: page numbers, atom indices, string lengths, array sizes, and various counts within the saved sysout are 16-bit quantities. In the current 256MB ("BIGBIGVM") build, the total Lisp address space is large, but individual objects and counts still carry these legacy limits. Most ordinary Lisp programs never approach them; very large data structures or extreme uses of system tables can.
