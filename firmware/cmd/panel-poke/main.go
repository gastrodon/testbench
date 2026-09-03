// panel-poke: reproduce the toy's own power-on drive pattern on the panel,
// then listen for any response.
//
// Every capture so far (panel-sniff, analog and digital) shows the toy's
// own board driving A1 and A2 LOW together at power-on, holding them for
// ~2.17s, then releasing both together -- measured directly from
// panel-final.log:
//
//	A1 0 -> A2 0 (3.6ms apart) -> [~2.17s held low] -> A2 1 -> A1 1 (3.6ms apart)
//
// A0 never participates. This firmware reproduces exactly that pulse on
// A1/A2, then switches to listening on all three pins (same edge-detect
// loop as cmd/panel-sniff) to see whether the panel does anything back --
// particularly on A0, which has never shown activity in any prior capture.
//
// SAFETY: only run this with the panel disconnected from the toy's own
// board. Driving A1/A2 as outputs while the toy's own chip also drives
// them would contend and could damage either side -- this is the whole
// reason cmd/panel-sniff never writes anything. tan still goes to the
// Uno's GND, and the panel's 4th (power) wire still needs 3.3V from the
// Uno to run at all with the toy out of the loop.
//
// Written for TinyGo's `arduino-uno` target. Flash with:
//
//	tinygo flash -target=arduino-uno ./cmd/panel-poke
package main

import (
	"machine"
	"time"
)

// holdDuration matches the toy's own measured reset-hold, not a guess.
const holdDuration = 2170 * time.Millisecond

func main() {
	uart := machine.Serial
	uart.Configure(machine.UARTConfig{BaudRate: 115200})

	a0, a1, a2 := machine.ADC0, machine.ADC1, machine.ADC2

	a1.Configure(machine.PinConfig{Mode: machine.PinOutput})
	a2.Configure(machine.PinConfig{Mode: machine.PinOutput})
	a1.Low()
	a2.Low()
	line(uart, "POKE v0.1: A1+A2 driven LOW together")
	time.Sleep(holdDuration)

	// Release to high-impedance input rather than actively forcing high --
	// closer to what "the toy stops driving" actually means, and matches
	// every other pin's listening state.
	a1.Configure(machine.PinConfig{Mode: machine.PinInput})
	a2.Configure(machine.PinConfig{Mode: machine.PinInput})
	a0.Configure(machine.PinConfig{Mode: machine.PinInput})
	line(uart, "POKE v0.1: released, listening")

	pins := [3]machine.Pin{a0, a1, a2}
	names := [3]string{"A0", "A1", "A2"}

	var last [3]bool
	for i := range pins {
		last[i] = pins[i].Get()
	}

	start := time.Now()
	for {
		for i := range pins {
			v := pins[i].Get()
			if v != last[i] {
				last[i] = v
				emit(uart, time.Since(start), names[i], v)
			}
		}
	}
}

func emit(uart *machine.UART, elapsed time.Duration, pin string, level bool) {
	writeUint32(uart, uint32(elapsed.Microseconds()))
	uart.Write([]byte(" "))
	uart.Write([]byte(pin))
	if level {
		uart.Write([]byte(" 1\r\n"))
	} else {
		uart.Write([]byte(" 0\r\n"))
	}
}

func line(uart *machine.UART, s string) {
	uart.Write([]byte(s))
	uart.Write([]byte("\r\n"))
}

func writeUint32(uart *machine.UART, v uint32) {
	var buf [10]byte
	i := len(buf)
	if v == 0 {
		i--
		buf[i] = '0'
	} else {
		for v > 0 {
			i--
			buf[i] = byte('0' + v%10)
			v /= 10
		}
	}
	uart.Write(buf[i:])
}
