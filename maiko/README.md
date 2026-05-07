# Maiko

Maiko is the implementation of the Medley Interlisp virtual machine for a
byte-coded Lisp instruction set, and some low-level functions for
connecting Lisp to a display (via X11 or SDL), the local filesystem,
and a network subsystem.

For an overview, see [Medley Interlisp Introduction](https://interlisp.org/medley/using/docs/medley/).

See [the Medley repository](https://github.com/Interlisp/medley) for
* [Issues](https://github.com/Interlisp/medley/issues) (note that maiko issues are there too)
* [Discussions](https://github.com/Interlisp/medley/discussions) (Q&A, announcements, etc)
* [Medley's README](https://github.com/Interlisp/medley/blob/master/README.md)

Bug reports, feature requests, fixes and improvements, support for additional platforms and hardware are all welcome.

## Development Platforms

Development has been primarily on macOS, FreeBSD, and Linux, with testing on Solaris and Windows.
Processor architectures i386, x86\_64, arm64, arm7l, and SPARC.


## Building Maiko

### Building with CMake (recommended)
Default build produces `lde`, `ldex`, `ldeinit`, and `ldesdl` (the SDL3 emulator). The runtime `lde` dispatcher prefers `ldesdl`; `ldex`/`ldeinit` are kept for the loadup pipeline and as an X11 fallback.

```
cd maiko
cmake -S . -B build
cmake --build build
cmake --install build
```

CMake options:
* MAIKO\_DISPLAY\_SDL: OFF, 2, [3] — SDL display version. Default 3.
* MAIKO\_DISPLAY\_X11: [ON], OFF — X11 display subsystem. On by default; required for the loadup-stage tools (`ldex`, `ldeinit`).
* MAIKO\_NETWORK\_TYPE: [NONE], SUN\_DLPI, SUN\_NIT, NETHUB
* MAIKO\_RELEASE: [351], various — see `maiko/inc/version.h`

### Building with make (legacy)
Building requires a C compiler (`clang` preferred) and either X11 client libraries or SDL. For example, using `make` and X11:

``` sh
sudo apt update
sudo apt install clang make libx11-dev
cd maiko/bin
./makeright x
```

* The build will (attempt to) detect the OS-type and cpu-type. It will build binaries `lde` and `ldex` in `../`_`ostype.cputype`_ (with .o files in `../`_`ostype.cputype-x`_. For example, Linux on a 64-bit x86 will use `linux.x86_64`, while macOS on Apple Silicon will use `darwin.aarch64`.
* If you prefer `gcc` over `clang`, you will need to edit the makefile fragment for your configuration (`makefile-ostype.cputype-x`) and comment out the line (with a #) that defines `CC` as `clang` and uncomment the line (delete the #) for the line that defines `CC` as `gcc`.
* If you want to do your own loadups to construct sysout files (see [the Medley repository](https://github.com/Interlisp/medley) for details), you also need the `ldeinit` binary, which you can build using `./makeright init`.

### Building For macOS

* Recommended path: SDL3 (`brew install sdl3`).  X11 still works via XQuartz (https://www.xquartz.org/releases) if `MAIKO_DISPLAY_X11=ON`.
* SDL libraries: see https://libsdl.org
