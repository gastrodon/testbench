# testbench-uno protocol

Line-oriented ASCII over USB-serial, **115200 8N1, no flow control**.

- One command per line, `\n` or `\r\n` terminated (either accepted).
- One response line per command, `\r\n` terminated.
- Tokens are space-separated. Max 4 tokens per line; extras are silently
  discarded (`fieldBuf` is fixed-size — see firmware/main.go).
- Max line length 48 bytes; bytes beyond that are silently dropped, not
  buffered/errored (fixed-size line buffer, no dynamic allocation on an
  ATmega328P with 2 KB RAM).

**Every new serial connection resets the board (DTR auto-reset).** Pin
`MODE` state does not survive a reconnect — see README.md's "Using the
host client" section.

## Pin naming

- `D0`-`D13` — digital pins. **`D0`/`D1` are reserved** (UART RX/TX to the
  host) and rejected by every command that takes a pin.
- `A0`-`A5` — analog pins. **Read-only** in this version (fixed as ADC
  inputs; `MODE`/`WRITE` reject them with `analog-fixed-input`). Real
  Arduio hardware can also use these as digital I/O (`D14`-`D19`) — not
  exposed yet, see README.md's Status section.
- **PWM (hardware, not software-simulated)** is only wired to 6 of the 14
  digital pins on the ATmega328P: **`D3`, `D5`, `D6`, `D9`, `D10`, `D11`**.
  These 6 come in 3 pairs sharing one hardware timer each (`D5`/`D6`,
  `D9`/`D10`, `D3`/`D11`) — each pin in a pair gets its own independent
  duty cycle, but they share the same underlying PWM frequency. The other
  8 digital pins have no timer wired to them and cannot do PWM at all;
  `MODE <pin> PWM` on any of them returns `not-pwm-pin`.

## Commands

### `PING`

→ `PONG`

Liveness/protocol check.

### `ID`

→ `ID testbench-uno v0.1`

Firmware self-identification string, format `ID <name> v<version>`.

### `HELP`

→ multiple lines, human-readable command summary.

Not meant to be machine-parsed — the host client doesn't use it. For
interactive debugging via a terminal (e.g. `picocom`).

### `MODE <pin> <IN|OUT|PULLUP|PWM>`

→ `OK` or `ERR <reason>`

Configures a digital pin's direction. `pin` must be `D2`-`D13` (`D0`/`D1`
rejected, `A*` rejected). `PULLUP` configures input with the internal
pull-up resistor enabled (idle high, reads low when pulled to ground —
standard Arduino `INPUT_PULLUP` semantics). `PWM` configures the pin for
hardware PWM output — only valid on `D3`, `D5`, `D6`, `D9`, `D10`, `D11`
(`not-pwm-pin` on any other pin); see `PWM` command below.

Pins reset to unconfigured (high-impedance input) on every board reset;
nothing is remembered across a reconnect.

### `READ <pin>`

→ `OK <value>` or `ERR <reason>`

- Digital pin (`D2`-`D13` — `D0`/`D1` rejected here too, same as `MODE`/`WRITE`): `value` is `0` or `1`.
- Analog pin (`A0`-`A5`): `value` is `0`-`1023` (classic Arduino
  `analogRead()` scaling — the AVR ADC is 10-bit, left-justified in a
  16-bit register internally, shifted down by the firmware).

Reading a digital pin does not require it to have been `MODE`'d first —
unconfigured pins read as whatever the AVR's default high-impedance input
state settles to (often floating/noisy).

### `WRITE <pin> <0|1>`

→ `OK` or `ERR <reason>`

Drives a digital pin. **Requires the pin to have already been configured
`MODE <pin> OUT`** in the current connection — the firmware refuses to
implicitly reconfigure a pin's direction from a `WRITE` call
(`not-configured-output`). `A*` pins are rejected
(`analog-fixed-input`). Rejects a pin currently in `PWM` mode the same
way (`not-configured-output`) — `MODE` a pin `OUT` again first if you want
to switch it back to plain digital.

### `PWM <pin> <0-255>`

→ `OK` or `ERR <reason>`

Sets duty cycle on a pin already configured `MODE <pin> PWM`
(`not-configured-pwm` otherwise). `0` is fully off, `255` is ~100% on,
linear in between — matches classic Arduino `analogWrite()` scaling.
Only valid on the 6 PWM-capable pins (see Pin naming above); non-PWM
digital pins and `A*` are rejected the same way `MODE PWM` rejects them.

## Errors

All error replies are `ERR <reason>`, one lowercase-hyphenated token:

| reason | meaning |
|---|---|
| `bad-command` | first token isn't `PING`/`ID`/`HELP`/`MODE`/`READ`/`WRITE`/`PWM` |
| `bad-args` | wrong number of tokens for the command |
| `bad-pin` | pin token isn't a valid `D0`-`D13`/`A0`-`A5` |
| `bad-mode` | third token of `MODE` isn't `IN`/`OUT`/`PULLUP`/`PWM` |
| `bad-value` | third token of `WRITE` isn't `0`/`1`, or `PWM`'s isn't `0`-`255` |
| `reserved-uart` | pin is `D0` or `D1` |
| `analog-fixed-input` | `MODE`/`WRITE`/`PWM` targeted an `A*` pin |
| `not-configured-output` | `WRITE` targeted a pin not `MODE`'d `OUT` (includes pins currently in `PWM` mode) |
| `not-pwm-pin` | `MODE <pin> PWM` targeted a pin with no hardware timer (anything but `D3`/`D5`/`D6`/`D9`/`D10`/`D11`) |
| `not-configured-pwm` | `PWM` targeted a pin not `MODE`'d `PWM` |
| `pwm-config-failed` | internal: timer/channel setup failed (shouldn't happen if `not-pwm-pin` didn't already fire) |

## Example session

```
> PING
< PONG
> MODE D13 OUT
< OK
> WRITE D13 1
< OK
> READ D13
< OK 1
> READ A0
< OK 586
> WRITE D2 1
< ERR not-configured-output
> MODE D5 PWM
< OK
> PWM D5 128
< OK
> MODE D13 PWM
< ERR not-pwm-pin
```
