// panel-sniff: standalone bus sniffer for the VTech pad-panel's candidate
// data lines (wired to A0/A1/A2/A3, ground common with the panel/toy).
//
// v3: buffered edge capture. v2 called uart.Write() (blocking on AVR --
// TinyGo's UART Write/WriteByte busy-waits per byte, then flush() blocks
// until the byte is fully shifted out) once per edge, right in the polling
// loop. At 115200 baud a ~15 byte line costs ~1.3ms of dead time during
// which Pin.Get() is never called -- and that blackout starts exactly at
// the edge that triggered it. Any real transition synchronized to the
// toy's own scan strobe (which is exactly how a button's return line would
// behave on a matrix-scanned bus) lands inside that window on every single
// cycle, not occasionally -- systematically invisible. v3 fixes this by
// recording edges to a RAM ring buffer with no I/O in the hot loop, and
// only draining it over UART when the bus has gone quiet.
//
// v2: plain digital edge detection, not ADC sampling. A0-A3 are also
// ordinary GPIO pins on the ATmega328P (machine.ADC0 == PC0, etc) -- an
// ADC conversion takes ~100us, so round-robining channels gave an
// effective scan rate way too slow to resolve real bus transitions and
// blurry (a sample mid-transition reads a misleading intermediate value
// instead of a clean 0/1). A digital Pin.Get() is a register read, or
// roughly 2-3 orders of magnitude faster.
//
// A3 (the "steady/power" wire) is included this time: its role was
// inferred from a DC multimeter reading, which averages -- a data line
// that idles mostly-high would read the same way. Watching it costs
// nothing now that emission is decoupled from sampling.
//
// Written for TinyGo's `arduino-uno` target. Flash with:
//
//	tinygo flash -target=arduino-uno ./cmd/panel-sniff
//
// Output: one line per edge, drained in batches once the bus is idle:
//
//	<elapsed_us> <pin> <0|1>
//
// A line "OVERFLOW <n>" means n edges were dropped because the ring
// buffer filled before a quiet period allowed a flush -- never silent.
//
// elapsed_us is real microseconds since boot (time.Since a boot-time
// timestamp), verified against a wall clock -- accurate to a fraction of
// a millisecond over multi-second windows on this target.
package main

import (
	"machine"
	"time"
)

var pins = [4]machine.Pin{machine.ADC0, machine.ADC1, machine.ADC2, machine.ADC3}
var names = [4]string{"A0", "A1", "A2", "A3"}

// ringSize: 3 bytes/edge (uint16 delta_us + pin/level byte). 200 entries
// is 600 bytes of globals, leaving real headroom under the 2KB SRAM
// ceiling for the runtime and stack (a larger ring caused an out-of-memory
// panic even though the static build-size report looked fine -- that
// report only sees globals, not stack usage) -- still comfortably covers
// a burst far denser than anything seen in idle-scan captures before a
// flush can occur.
const ringSize = 200

var (
	ringUS     [ringSize]uint16 // delta_us since previous edge, saturating at 65535
	ringPin    [ringSize]uint8  // pin index<<1 | level
	ringCount  int
	ringBaseUS uint32 // absolute time of the edge immediately before ring[0]
	overflow   uint32
)

// flushIdleUS: drain the ring once the bus has been silent this long.
// Idle scan activity (A1 strobe) repeats every ~40ms, so 8ms of silence
// reliably means "between button-relevant events", not "mid-transaction".
const flushIdleUS = 8000

func main() {
	uart := machine.Serial
	uart.Configure(machine.UARTConfig{BaudRate: 115200})

	for i := range pins {
		pins[i].Configure(machine.PinConfig{Mode: machine.PinInput})
	}

	line(uart, "EDGE v0.3 pins=A0,A1,A2,A3 digital buffered elapsed_us")

	var last [4]bool
	for i := range pins {
		last[i] = pins[i].Get()
	}

	start := time.Now()
	lastEdgeUS := uint32(time.Since(start).Microseconds())
	lastAnyUS := lastEdgeUS

	for {
		now := uint32(time.Since(start).Microseconds())
		sawEdge := false
		for i := range pins {
			v := pins[i].Get()
			if v != last[i] {
				last[i] = v
				sawEdge = true
				if ringCount == 0 {
					ringBaseUS = lastEdgeUS
				}
				record(uint32(now-lastEdgeUS), i, v)
				lastEdgeUS = now
			}
		}
		if sawEdge {
			lastAnyUS = now
		} else if ringCount > 0 && now-lastAnyUS > flushIdleUS {
			drain(uart)
		}
	}
}

func record(delta uint32, pinIdx int, level bool) {
	if ringCount >= ringSize {
		overflow++
		return
	}
	d := delta
	if d > 65535 {
		d = 65535
	}
	ringUS[ringCount] = uint16(d)
	pb := uint8(pinIdx) << 1
	if level {
		pb |= 1
	}
	ringPin[ringCount] = pb
	ringCount++
}

// drain writes out every buffered edge as an absolute elapsed_us line, then
// clears the ring. Runs only while the bus is idle, so blocking UART I/O
// here never overlaps a real transaction. Absolute timestamps are
// reconstructed in a single forward pass, walking from ringBaseUS (the
// absolute time of the edge immediately preceding ring[0]) through the
// recorded deltas -- no second buffer, to stay well under the 2KB SRAM
// ceiling (a naive version with a separate absolute-times array panicked
// with out-of-memory: its stack-local array wasn't visible in the static
// build-size report, only the two global ring arrays were).
func drain(uart *machine.UART) {
	if overflow > 0 {
		uart.Write([]byte("OVERFLOW "))
		writeUint32(uart, overflow)
		uart.Write([]byte("\r\n"))
		overflow = 0
	}
	acc := ringBaseUS
	for i := 0; i < ringCount; i++ {
		acc += uint32(ringUS[i])
		pb := ringPin[i]
		pinIdx := pb >> 1
		level := pb&1 != 0
		writeUint32(uart, acc)
		uart.Write([]byte(" "))
		uart.Write([]byte(names[pinIdx]))
		if level {
			uart.Write([]byte(" 1\r\n"))
		} else {
			uart.Write([]byte(" 0\r\n"))
		}
	}
	ringCount = 0
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
