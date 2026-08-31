# AGENTS.md — testbench

Orientation for an agent starting a fresh session in this repo. Read
`README.md` and `PROTOCOL.md` for what things do; this file is for how to
not re-break things that were already fixed once.

## What this is

Firmware + host client turning an Arduino Uno into a serial GPIO probe
(`firmware/`, `host/`), plus an unrelated LEGO/printed-collar accessory
project (`optics/`) that happens to live in the same repo. Part of the
[Shop testbench](https://linear.app/gastrodon/document/testbench-agent-operable-hardware-bench-41d0596a0f66)
— the bench camera and udev plumbing live in `module/hw-bench.nix` in
[gastrodon/dotfiles](https://github.com/gastrodon/dotfiles), not here.

## Ground rules

- **Two separate Go modules on purpose** (`firmware/go.mod`,
  `host/go.mod`). `firmware/` targets bare-metal AVR via TinyGo and must
  stay free of anything TinyGo can't compile. Don't merge them, don't
  import one from the other.
- **Nix-first.** `nix develop` for the toolchain, `nix build .#<name>` for
  reproducible artifacts. Don't reach for `go install`/global package
  managers/imperative fetch scripts if a flake input or derivation can do
  it — see the git log for why (`fetch-libs.sh` → flake inputs,
  `setup-editor.sh` → a devShell-managed derivation, both replaced for
  the same reason: reproducibility, no manual re-run drift).
- **Test before trusting, always.** Every non-obvious fact in this repo
  (below) was found by actually building/flashing/running something, not
  by reasoning about what should work. If you're about to write something
  that "should" work based on how a tool is documented, try it on the real
  thing first — this repo's history is a long list of "should have worked,
  didn't" corrected by testing.
- **Real hardware may be attached.** The Uno enumerates at `/dev/ttyACM0`
  (or `/dev/hw-bench/uno` once `hw-bench.nix` is switched on the host).
  Needs `dialout` group — if your shell session predates that grant, wrap
  commands in `sg dialout -c '...'`. Wrap serial commands in `timeout` to
  avoid hangs.

## Gotchas already found — don't rediscover these

- **Opening the Uno's serial port resets the board** (DTR auto-reset),
  wiping any `MODE` a previous connection configured. Stateful command
  sequences need one held-open connection — `probe`'s batch/stdin mode,
  not separate one-shot CLI invocations. (`host/README` usage section,
  `PROTOCOL.md`)
- **OpenSCAD's `include <file>` does not protect a variable assigned
  before the include line** — the included file's own top-level
  assignment silently wins (console warning only, easy to miss). The only
  override that reliably sticks is `-D` on the command line. (verified by
  direct test, see `optics/README.md`)
- **Merging Go's `runtime` package wholesale (real stdlib + TinyGo's own)
  trips a real Go toolchain safety check** — a cross-platform
  case-insensitivity guard on `asm_386.s` vs `asm_386.S` coexisting, even
  on a case-sensitive Linux filesystem. Fix: only *add* TinyGo-exclusive
  subdirectories/packages, never merge an entire colliding directory.
  (`flake.nix`, `firmwareGoroot`)
- **`cp -rs` (recursive + symlink) inherits the *source's* permission
  bits on newly created destination directories** — copying from the Nix
  store (read-only) produces destination directories you can't write into
  afterward, even though you "own" them. Symlink per-top-level-entry
  instead of copying when merging trees sourced partly from `/nix/store`.
- **A gitignore pattern with a trailing slash (`lib/`) matches plain
  directories but not a symlink pointing at one.** If a Nix-managed
  symlink is showing up as untracked, check for this before assuming
  something else is wrong. (`optics/.gitignore`)
- **`nix run .#<pkg>` assumes the binary is named after the package's
  `pname`.** If the actual binary is named differently (Go names it after
  the `cmd/` subdirectory), `nix run` fails to find it unless
  `meta.mainProgram` is set explicitly.
- **TinyGo shells out to `go` underneath**, which wants a writable `$HOME`
  for its cache — the Nix build sandbox gives none by default
  (`mkdir /homeless-shelter: permission denied`). Set `HOME=$TMPDIR` in
  any derivation that invokes `tinygo build`.
- **`machine` (TinyGo's hardware package) is not a fetchable Go module**
  — no `go.mod`, and its own imports (`device/avr`, `runtime/volatile`)
  assume GOROOT-style resolution. `go.mod` `replace` directives and GOPATH
  are both the wrong tool; a real merged GOROOT (`packages.firmware-goroot`
  in `flake.nix`) is what actually works, verified with `gopls check`.

## Verifying you haven't broken anything

```
nix flake check                    # evaluates everything, cheap
nix build .#probe && result/bin/probe /dev/ttyACM0 ping   # needs real hardware
nix build .#firmware                                       # then flash + ping to confirm
nix build .#optics-calibration     # real OpenSCAD render, ~1 min
nix develop -c bash -c 'cd firmware && GOROOT=$(pwd)/.gopls-goroot GOFLAGS=-tags=arduino_uno gopls check main.go'
```

All of these have been run for real at some point in this repo's history
— none of it is aspirational.
