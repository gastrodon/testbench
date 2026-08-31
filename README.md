# testbench

Firmware + host client for turning an Arduino Uno into a general-purpose
GPIO probe an agent (or a human) can drive over serial: configure pins,
read digital/analog levels, drive outputs — one line-oriented command at a
time.

Part of the [Shop testbench project](https://linear.app/gastrodon/document/testbench-agent-operable-hardware-bench-41d0596a0f66)
— see that doc for the wider bench (camera, Pi fleet, `module/hw-bench.nix`
in [gastrodon/dotfiles](https://github.com/gastrodon/dotfiles)). This repo
is just the Uno firmware and its host client.

Two separate Go modules, deliberately: `firmware` targets bare-metal AVR
through TinyGo and must stay free of anything TinyGo can't compile;
`host` is plain Go with no special toolchain and no dependencies at all
(stdlib only — shells out to `stty` for serial config, same as this
project's other serial work).

## Nix

Everything below also has a Nix-native path, verified working end-to-end
(built, and for `probe`/`firmware`, actually run against real hardware):

```
nix develop              # tinygo, avrdude, arduino-cli, openscad, go, esptool all on PATH
nix build .#probe        # host CLI
nix build .#firmware     # -> result/testbench-uno.hex
nix build .#optics-calibration   # -> result/calibration.stl
```

The two external OpenSCAD libraries `optics/` depends on
(`cfinke/Technic.scad`, `paulirotta/PELA-blocks`) are flake inputs, pinned
by commit and content-hashed in `flake.lock` — not an imperative fetch
script. `nix develop`'s shellHook symlinks `optics/lib` to the resolved
store paths automatically.

One real gotcha hit while building the `firmware` package: TinyGo shells
out to `go` underneath, which wants a writable `$HOME` for its cache — the
build sandbox gives none by default (`mkdir /homeless-shelter: permission
denied`). Fixed with `export HOME=$TMPDIR` in the derivation's buildPhase.
Also: `nix run .#probe` needs `meta.mainProgram = "probe";` set, since Go
names the binary after `cmd/probe`, not the Nix package's `pname`
(`testbench-probe`) — without it `nix run` looks for the wrong filename.

The manual commands below still work unchanged (useful for quick iteration
without a full Nix build each time); the flake is for reproducibility, not
a replacement for the fast inner loop.

## Building and flashing the firmware

```
cd firmware
tinygo build -target=arduino-uno -size=short -o /tmp/testbench-uno.hex .
tinygo flash -target=arduino-uno -port=/dev/ttyACM0 .
```

Needs `tinygo` + `avrdude` on PATH — both provided by `hwBench.enable` in
`module/hw-bench.nix` once that's switched, or ephemerally via
`nix shell nixpkgs#tinygo nixpkgs#avrdude`. Flashing needs `dialout` group
access to the port.

Current build: **10397 bytes flash / 1244 bytes RAM** — Uno has 32256/2048
available, so there's still plenty of headroom for growing the command set.

## Using the host client / CLI

```
cd host
go build -o probe ./cmd/probe

./probe /dev/ttyACM0 ping
./probe /dev/ttyACM0 id
```

**Important**: opening the serial port resets the Uno (DTR auto-reset),
which wipes any pin `MODE` a previous connection configured. Each one-shot
`probe <device> <command>` invocation is its own fresh connection — fine
for independent commands (`ping`, `id`, `read` on a pin already wired the
way you want), but a stateful sequence like "configure a pin as output,
then write it" needs to happen over **one** connection. Use batch mode for
that:

```
printf 'MODE D13 OUT\nWRITE D13 1\nREAD D13\nWRITE D13 0\n' | ./probe /dev/ttyACM0
```

Or use the `testbench` package directly from Go — see `host/client.go` for
the `Client` API (`Open`, `Ping`, `ID`, `Mode`, `Read`, `Write`).

## Editor setup (VSCodium/gopls)

`machine` (and its transitive imports like `device/avr`, `runtime/volatile`)
live in TinyGo's own `TINYGOROOT/src`, not in any GOROOT, GOPATH, or
fetchable Go module gopls already knows about — there's no `go.mod` there,
and nothing to `go get`.

This is handled by the flake, not a script: `nix develop`'s shellHook
symlinks `firmware/.gopls-goroot` to a Nix derivation
(`packages.firmware-goroot`) that merges the real Go stdlib with exactly
the packages TinyGo adds that don't already exist there — via symlinks, a
few MB, not a stdlib copy. Just enter the shell:

```
nix develop
```

and the symlink is there, always pointing at the current flake-pinned
TinyGo version (no "did I remember to re-run the setup script after
upgrading" drift). `firmware/.vscode/settings.json` points gopls at
`${workspaceFolder}/.gopls-goroot` automatically when `firmware/` is
opened as a workspace folder, and sets the **full** build tag list `tinygo
info -target=arduino-uno` reports (`avr,baremetal,arm,atmega328p,...` —
see the settings file for the exact list) so everything gated behind them
resolves — including board-specific files like `board_arduino_uno.go`
(where `machine.D0`..`D13` are defined) and chip-specific ones like
`machine_atmega328.go` (where `machine.PWM`/`Timer0`..`Timer2` are
defined). Just `arduino_uno` alone isn't enough — confirmed by testing:
it resolves `machine.D0` fine but leaves `machine.PWM` undefined, since
that file's `//go:build avr && (atmega328p || atmega328pb)` needs tags
`arduino_uno` doesn't include. Verified clean end-to-end with `gopls
check` against both `cmd/probe/main.go` and `cmd/light-breathe/main.go`
(which uses PWM) — zero diagnostics on either.

Can also be inspected/tested standalone: `nix build .#firmware-goroot`.

`host/` needs none of this — it's ordinary Go, resolved normally, and
deliberately shares nothing with `firmware/`'s special environment (they're
separate Go modules for exactly this reason).

## Protocol

See [PROTOCOL.md](PROTOCOL.md) for the full command reference.

## Safety notes

- **D0/D1 are the UART to the host** — the firmware refuses `MODE`/`WRITE`
  on them (`ERR reserved-uart`). Don't wire a DUT to them.
- **This firmware only drives 5V logic.** Anything lower-voltage (a ~3V
  toy, for instance) should only ever be wired as an *input* to the Uno,
  never have the Uno drive an output into it.
- A0-A5 are fixed ADC inputs in this version — no digital I/O on the
  analog-labeled pins yet (Arduino normally allows this; scope-limited
  here for simplicity, see PROTOCOL.md).

## Status

Verified end-to-end on real hardware (genuine Uno R3, `/dev/ttyACM0`) —
`PING`/`ID`/`MODE`/`READ`/`WRITE` all round-tripped correctly, including
error paths (bad command, bad pin, bad mode, write-without-configure,
reserved UART pins). Onboard LED (`D13`) blinked on command as the
smoke test.

Not yet implemented: PWM (`analogWrite`), digital I/O on A0-A5, any framing
beyond plain ASCII lines.
