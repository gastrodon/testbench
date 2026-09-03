// panel-analog: amplitude-window sniffer for the VTech pad-panel's 4
// candidate lines (A0-A3), to test a specific remaining hypothesis after
// digital edge capture (cmd/panel-sniff) found zero button-correlated
// activity even with its UART-blocking blind spot fixed.
//
// The toy's idle logic high measured ~3.4-3.6V by multimeter. The Uno at
// Vcc=5V has a digital-input threshold (VIH) around 3.0V -- only ~0.4-0.6V
// of margin. A signal that swings into the 1.5-3V band (a weak pull, a
// partially-driven line, a different logic family on the panel side) would
// read as unchanged on a digital Pin.Get() but would show up as a real
// amplitude dip on the ADC. This firmware looks for exactly that: it
// doesn't try to resolve edges, just the min/max raw ADC value seen per
// pin within each 10ms window, so a press that dips a line without fully
// crossing the digital threshold is still visible.
//
// ADC.Get() on this target returns 0..65535, scaled from a 10-bit
// AVcc-referenced conversion -- full scale is ~5V, so idle-high (~3.4-3.6V)
// reads ~44500-47000 and the ~3.0V digital threshold sits ~39300.
//
// Not edge-precise: an ADC conversion costs ~100us, so round-robining 4
// channels gives ~25 rounds per 10ms window -- plenty to catch a dip that
// lasts a button-press's worth of time, not enough to resolve the toy's
// own ~microsecond-scale bus transitions (that's what panel-sniff is for).
//
// Written for TinyGo's `arduino-uno` target. Flash with:
//
//	tinygo flash -target=arduino-uno ./cmd/panel-analog
//
// Output, one line per pin per 10ms window (only when min/max differs from
// the previous window for that pin, to keep idle output quiet):
//
//	<elapsed_us> <pin> min=<v> max=<v>
package main

import (
	"machine"
	"time"
)

var pins = [4]machine.ADC{
	{Pin: machine.ADC0},
	{Pin: machine.ADC1},
	{Pin: machine.ADC2},
	{Pin: machine.ADC3},
}
var names = [4]string{"A0", "A1", "A2", "A3"}

const windowUS = 10000

func main() {
	uart := machine.Serial
	uart.Configure(machine.UARTConfig{BaudRate: 115200})
	machine.InitADC()

	line(uart, "ANALOG v0.1 pins=A0,A1,A2,A3 window=10ms min/max raw(0..65535,AVcc-ref)")

	var winMin, winMax [4]uint16
	var lastMin, lastMax [4]uint16
	resetWindow(&winMin, &winMax)

	start := time.Now()
	windowStart := uint32(0)

	for {
		now := uint32(time.Since(start).Microseconds())
		for i := range pins {
			v := pins[i].Get()
			if v < winMin[i] {
				winMin[i] = v
			}
			if v > winMax[i] {
				winMax[i] = v
			}
		}

		if now-windowStart >= windowUS {
			for i := range pins {
				if winMin[i] != lastMin[i] || winMax[i] != lastMax[i] {
					emit(uart, windowStart, names[i], winMin[i], winMax[i])
					lastMin[i] = winMin[i]
					lastMax[i] = winMax[i]
				}
			}
			resetWindow(&winMin, &winMax)
			windowStart = now
		}
	}
}

func resetWindow(winMin, winMax *[4]uint16) {
	for i := range winMin {
		winMin[i] = 0xFFFF
		winMax[i] = 0
	}
}

func emit(uart *machine.UART, elapsed uint32, pin string, min, max uint16) {
	writeUint32(uart, elapsed)
	uart.Write([]byte(" "))
	uart.Write([]byte(pin))
	uart.Write([]byte(" min="))
	writeUint32(uart, uint32(min))
	uart.Write([]byte(" max="))
	writeUint32(uart, uint32(max))
	uart.Write([]byte("\r\n"))
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
