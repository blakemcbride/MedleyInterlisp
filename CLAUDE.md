# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## What this repository is

**Blake McBride's fork of Medley Interlisp** — a preservation/modernization of the Interlisp environment from Xerox PARC (1970s onward). Not a typical modern codebase.

Upstream Interlisp keeps the VM and the Lisp environment as separate repos (`Interlisp/maiko`, `Interlisp/medley`). **This fork integrates them as two top-level subdirectories of one repo:**

- `maiko/` — the C-based Interlisp virtual machine (builds `lde`, `ldex`, `ldeinit`, `ldesdl`, plus utilities).
- `medley/` — the Lisp environment that runs on top of Maiko.

Repo home: https://github.com/blakemcbride/MedleyInterlisp. Single git repo at the root; no submodules (`.gitmodules` is empty). The `notecards` repo is *not* in-tree — `loadup-apps-from-full.sh` expects it as a sibling of `medley/` (i.e. `MedleyInterlisp/notecards/`) when building `apps.sysout`.

Building produces *sysouts* (binary memory images): `init.sysout` → `mid.sysout` → `lisp.sysout` → `full.sysout` → `apps.sysout`. Each stage starts from the previous stage's image. There is no `make`-on-every-PR style CI for the Lisp side — sysout builds are triggered manually via GitHub Actions or the loadup scripts. Maiko has its own CMake build.

Blake's stated priorities (from `README.md`):
1. Simplify and correct system build
2. Stop the system from pegging the CPU
3. Default the display backend to **SDL3** (Wayland-compatible; smooths native macOS / Windows ports). X11 is retained for the loadup tools and as a runtime fallback; long term it can be retired entirely.
4. Dynamic window sizes (instead of a limited range of static sizes)
5. Stop polluting the home directory
6. Native macOS and Windows ports (Linux is the primary dev platform)

Lean toward changes that move these forward; flag changes that work against them.

## Top-level layout

The repo root contains:
- `maiko/` — VM (see below)
- `medley/` — Lisp environment (see below)
- `README.md` — Blake's intro and priorities
- `LICENSE` — single license for the integrated fork
- `CLAUDE.md` — this guide

There is **no top-level launcher, no top-level `.github/workflows/`, no top-level build script.** CI lives inside `maiko/.github/workflows/` and `medley/.github/workflows/`. To do anything you `cd` into `maiko/` or `medley/`.

## maiko/ (the VM)

```
maiko/
├── CMakeLists.txt        # primary modern build
├── src/                  # 138 .c files
├── inc/                  # 171 .h files (incl. X11 + SDL headers)
├── include/              # minimal additional headers
├── bin/                  # legacy make-based build system + scripts
│   ├── makeright         # bash driver: detects ostype.cputype, picks the right makefile
│   ├── makeinitlde       # builds ldeinit (the loadup-mid stage needs this)
│   ├── makefile-header   # template prepended to platform makefiles
│   ├── makefile-tail     # template appended
│   ├── makefile-<os.cpu>-<display>   # per-platform makefiles (linux.x86_64-x, darwin.aarch64-sdl, ...)
│   ├── linux-*.mk        # Linux fragments (linux-common.mk, linux-x.mk, linux-sdl.mk, linux-libbsd.mk, linux-compiler.mk)
│   ├── compile-flags     # shared compile flag list
│   ├── machinetype       # detects ostype.cputype
│   ├── test.vm           # 9.1 MB test sysout (binary data, not an executable)
│   └── legacy/           # old SunOS 3/4, DOS, ancient targets — left as historical artifacts
├── docs/
└── README.md             # describes both make and CMake build paths
```

There are **two coexisting build systems** in `maiko/`:

### CMake (primary, recommended)
```
cd maiko
mkdir -p build && cd build
cmake .. && cmake --build .
```
Targets defined in `CMakeLists.txt`:
- `lde` — runtime dispatcher; re-execs as `ldesdl` by default, or as `ldex` when invoked with `-display X11` or an X11-style display string (`:0`, `host:0`, ...).
- `ldesdl` — SDL3 emulator (default runtime). Built when `MAIKO_DISPLAY_SDL` is `2` or `3`.
- `ldex` — X11 emulator. Built only when `MAIKO_DISPLAY_X11=ON` (off by default). Available as a runtime fallback.
- `ldeinit` — bootstrap variant used by the `loadup-mid` stage; built whenever any display backend is enabled, picks X11 when `MAIKO_DISPLAY_X11=ON`, otherwise SDL.
- `ldeether`, `mkvdate`, `setsout`, `tstsout` — utilities.
- `INSTALL` places everything in `${release_dir}` = `${os_ver}.${machine_type}`.

CMake options (all live in the cache, configurable via `-D...` or `cmake-gui`):
- `MAIKO_RELEASE` — `351` (default), `350`, `300`, `210`, `201`, `200`, `115`. See `inc/version.h`.
- `MAIKO_DISPLAY_SDL` — `3` (default) / `2` / `OFF`. Adds `-DSDL=3` (or `=2`) and includes `src/sdl.c`. SDL3 is the default everywhere — runtime, loadup, ldeinit.
- `MAIKO_DISPLAY_X11` — `OFF` (default) / `ON`. Optional X11 backend. Adds `-DXWINDOW`, links `X11::X11`, includes `src/xbbt.c`, `src/xinit.c`, `src/xwinman.c`, etc. When on, also builds `ldex` and uses X11 sources for `ldeinit`.
- `MAIKO_NETWORK_TYPE` — `NONE` (default), `SUN_DLPI`, `SUN_NIT`, `NETHUB`.

clang-tidy is detected and applied if available (with `cert-*` checks, plus a hand-curated set of suppressions for legacy strcpy/bzero usage).

`BAD_SRCS` near the top of `CMakeLists.txt` lists C files that don't build on Linux (DOS, SunOS, ancient peripherals) — leave them out of new build paths.

### Legacy make
```
cd maiko/bin
./makeright x          # X11 build for current platform
./makeright sdl        # SDL build for current platform
./makeright init       # builds ldeinit
```
Output goes to `maiko/<osversion>.<cputype>/` (e.g. `maiko/linux.x86_64/lde`, `maiko/linux.x86_64-x/*.o`). The loadup scripts know to look there.

When in doubt, prefer CMake — but `bin/makeright` is what `maiko/README.md` documents first and is still in active use.

## medley/ (the Lisp environment)

```
medley/
├── sources/              # core Interlisp + Common Lisp sources (UPPERCASE filenames, no extension)
├── library/              # bundled "supported" packages (lafite, sketch, tedit, virtualkeyboards, ...)
├── lispusers/            # bundled "user-contributed" packages
├── internal/             # historically Venue-internal utilities
│   ├── envos/            # environment definitions
│   ├── loadups/          # LOADUP-LISP/LOADUP-FULL/LOADUP-APPS/LOADUP-CLOS, MAKEINIT, starter.sysout (8.9 MB), man-page/loadup.1.gz
│   └── venuesysouts/     # Venue-specific sysout metadata
├── clos/                 # early CLOS (PCL-derived)
├── CLTL2/                # CLtL2 conformance additions (still not full ANSI CL)
├── rooms/                # ROOMS window/desktop manager
├── greetfiles/           # init profiles (MEDLEYDIR-INIT default; NOGREET used by loadups)
├── fonts/                # raster fonts (display, PostScript, Interpress, Press)
├── fontsold/             # older fonts; not yet retired
├── unicode/              # XCCS↔Unicode mapping tables
├── docs/, doctools/      # documentation and tools
├── installers/           # platform installer machinery
├── scripts/              # all shell infrastructure (see below)
├── loadups/              # output dir for built sysouts (gitignored except build/ and gitinfo)
├── medley                # symlink → scripts/medley/medley.command
├── loadup                # symlink → scripts/loadups/loadup-all.sh
├── run-medley            # real script (5.6 KB) — older simpler launcher
├── BUILDING.md, CONTRIBUTING.md, README.md, release-notes.md
├── .github/workflows/    # CI: buildLoadup.yml, buildReleaseInclDocker.yml, doHCFILES.yml, buildDocker.yml
└── .gitmodules           # empty
```

Notably **no** `obsolete/` at the medley root in this fork — only `scripts/loadups/obsolete/` for legacy loadup scripts.

`medley/internal/loadups/starter.sysout` is already present (8.9 MB). It's the bootstrap image needed to run `loadup-init.sh`. Compiled loadup drivers (`LOADUP-LISP.LCOM`, `LOADUP-FULL.LCOM`, `LOADUP-APPS.LCOM`, `LOADUP-CLOS.LCOM`, `MAKEINIT.LCOM`) are also tracked there.

### medley/scripts/loadups/ (the build entry points)

```
loadup                        # the actual orchestrator script (~20 KB)
loadup-all.sh -> loadup       # symlink (loadup-all.sh and loadup are the same script)
loadup-init.sh                # stage 0: starter.sysout → init.dlinit / init.sysout (runs MAKEINIT)
loadup-mid-from-init.sh       # stage 1: init.dlinit → init-mid.sysout (needs ldeinit)
loadup-lisp-from-mid.sh       # stage 2: init-mid.sysout → lisp.sysout (runs LOADUP-LISP)
loadup-full-from-lisp.sh      # stage 3: lisp.sysout → full.sysout (runs LOADUP-FULL)
loadup-apps-from-full.sh      # stage 4: full.sysout → apps.sysout (needs notecards sibling)
loadup-aux.sh                 # builds exports.all + whereis.hash
loadup-db.sh                  # masterscope DB (fuller.database) via GATHER-INFO
loadup-db-from-full.sh        # variant
loadup-full.sh                # standalone full builder
loadup-setup.sh               # sourced env setup + helpers (not executable)
thin_loadups.sh               # cleans .~N~ versioned files
obsolete/                     # legacy scripts
```

There is **no separate `copy-all.sh`** in this fork — the copy/promote logic is folded into `loadup` itself. (Upstream `medley/BUILDING.md` still references `copy-all.sh` as a separate stage; that doc is slightly stale relative to the script directory.)

### medley/scripts/medley/ (the runtime launcher)

`medley.command` (51 KB) is **generated**. Do not edit it directly. It is assembled by `scripts/medley/compile.sh` from these components:
- `medley_header.sh`, `medley_args.sh`, `medley_configfile.sh`, `medley_geometry.sh`, `medley_main.sh`, `medley_run.sh`, `medley_usage.sh`, `medley_vnc.sh`
- `medley.ps1` (Windows PowerShell variant)
- `inline.sh` (helper for compile.sh)

To make changes: edit the components, run `compile.sh`, or run `medley_main.sh` directly during testing.

## Building sysouts (loadups)

`loadup` (the orchestrator) and the stage scripts must be run from inside `medley/`. They search for Maiko in this order:
1. `lde`/`ldeinit` on `$PATH`
2. `$MAIKODIR/<osversion>.<machinetype>/`
3. `$MEDLEYDIR/../maiko/<osversion>.<machinetype>/` (this works in this fork because `maiko/` is `medley/`'s sibling)
4. `$MEDLEYDIR/maiko/<osversion>.<machinetype>/`

**Full build** (everything; ~4–6 min on fast hardware, mostly the `loadup-db` step):
```
cd medley
time ./loadup -apps && time ./scripts/loadups/loadup-db.sh
```
Without `-db` and without `-apps`, the rest finishes in ~22 s on a fast system.

Useful flags on `./loadup` (a.k.a. `loadup-all.sh`):
- `--start <stage>` / `--target <stage>` — partial builds. Stages: `scratch | init | mid | lisp | full | apps`, also numbers `0..5`. End must come after start.
- `-aux` / `-db` — also build aux files / masterscope DB (require end at `full` or later).
- `-d <dir>` / `--maikodir <dir>` — explicit Maiko location.
- `-nc` / `--nocopy` — skip the final copy-into-`loadups/` step.
- `-th` / `-tw` / `-tl` (`+` to confirm) — thin `*.~N~` versioned files from workdir / loadups.
- `-v` / `--vnc` — run inside Xvnc (headless/CI).
- `-z` / `--man` — show the `loadup(1)` man page (`internal/loadups/man-page/loadup.1.gz`).

Work directory is `$LOADUP_WORKDIR` (defaults to `/tmp/loadups-$$`, auto-cleaned). Set to `./tmp` for the historical persistent-workdir behavior. Output dir is `$LOADUP_OUTDIR` (defaults to `medley/loadups/`).

GitHub-side equivalent: trigger **Build/Push Release & Docker** (`medley/.github/workflows/buildReleaseInclDocker.yml`) via the Actions tab.

## Running Medley

```
cd medley
./medley                              # symlink to scripts/medley/medley.command (modern launcher)
./run-medley [flags] [SYSOUTFILE]     # older simpler launcher
```

`run-medley` flags: `-prog <ldefile>`, `-loadup <file>`, `-nogreet | -greet <file>`, `-g WxH`, `-sc WxH`, `--display`, `-n|-nl|-full|-lisp` (sysout selection). Honors `LDESRCESYSOUT`, `LDEDESTSYSOUT`, `MEDLEYDIR`, `MAIKODIR`, `LDEINIT`.

Exit from a running system: `(LOGOUT)` (Interlisp prompt) or `(IL:LOGOUT)` (CL prompt). Logout writes `~/lisp.virtualmem` (override via `$LDEDESTSYSOUT` or `$LOGINDIR`); the next launch without an explicit sysout restores from there. **Note Blake priority #5** — home-dir pollution like this is a known target for cleanup.

Display: SDL3 is the default everywhere — runtime, loadup, `ldeinit`. SDL3 transparently uses Wayland or X11 on Linux and the native compositor on macOS / Windows. The `lde` dispatcher prefers `ldesdl`; pass `-display X11` (or any X-style display name) to force `ldex` (only available when `MAIKO_DISPLAY_X11=ON`).

## Testing

There is no automated test suite for the Lisp side. `medley/CONTRIBUTING.md` (upstream) says: "We don't have testing new builds automated or integrated. Be sure you've tested your patch." Verification means running the relevant loadup stage and exercising changes in a running sysout. Cosmetic-only changes are typically not accepted upstream.

For Maiko C changes: `cmake --build .` covers compile/link, but actual VM correctness still needs running it under a sysout.

## File conventions

- **UPPERCASE filenames, no extension** — Interlisp source files. Don't add `.lisp`.
- **`.LCOM`** — Interlisp compiled (binary). **`.DFASL`** — Common Lisp compiled (binary). Both are `.gitattributes`-marked binary; never hand-edit them, and don't be confused when they appear next to a same-stem source file.
- **`.TEDIT`** — Medley structured-text format (binary). Used for both packages and accompanying docs.
- **`.~N~` suffixed files** — Medley's file-versioning scheme. `cpv` and `restore-versions.sh` manage them; `thin_loadups.sh` removes them. Gitignored.
- **`.IMPTR`** — manual cross-reference, gitignored.
- **`.dribble`** — session log (text, contains font control codes).
- **Font/control characters in source** — Medley sources can contain font escapes; use `medley/scripts/lsee` to render, not `cat`.

## Code conventions and Blake's preferences

- The Maiko C code was originally K&R for a big-endian 32-bit machine. Expect "unforeseen interactions" with 30-year-old code on modern systems.
- Keep PRs small and focused. For new features, prefer a Discussion before issue/PR.
- **Blake wants root-cause fixes, not workarounds.** Drive bugs to the actual source line and fix it there. If you can't fix it from the current context, produce a precise bug report with file:line references — not an LD_PRELOAD shim, monkeypatch, or wrapper script.
- Don't hand-edit generated files (`scripts/medley/medley.command`, `.LCOM`, `.DFASL`).
- Documentation files (`.md`) describe current state only — no history of past bugs, fixes, or enhancements. Git history is where that lives.
