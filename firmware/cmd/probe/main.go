// testbench-uno: a line-oriented GPIO probe for the Arduino Uno.
//
// Protocol: one command per line (\n or \r\n terminated), space-separated
// tokens, one response line per command. See PROTOCOL.md for the full
// command reference.
//
// Written for TinyGo's `arduino-uno` target (ATmega328P, 2 KB RAM, no
// goroutines — this is a hand-rolled polling loop, not concurrent Go).
package main

import "machine"

const version = "testbench-uno v0.1"

// digitalPins maps our D0..D13 numbering onto the board's Pin constants.
var digitalPins = [14]machine.Pin{
	machine.D0, machine.D1, machine.D2, machine.D3, machine.D4,
	machine.D5, machine.D6, machine.D7, machine.D8, machine.D9,
	machine.D10, machine.D11, machine.D12, machine.D13,
}

// analogPins maps our A0..A5 numbering onto the board's ADC channel constants.
var analogPins = [6]machine.Pin{
	machine.ADC0, machine.ADC1, machine.ADC2,
	machine.ADC3, machine.ADC4, machine.ADC5,
}

// digitalMode tracks what we've explicitly configured each digital pin as,
// so WRITE can refuse to drive a pin nobody asked to be an output. AVR
// pins reset to high-impedance input, which is modeUnset here too.
type mode uint8

const (
	modeUnset mode = iota
	modeIn
	modeInPullup
	modeOut
	modePWM
)

var digitalMode [14]mode

// pwmChan holds the (Timer, channel) pair MODE PWM configured for a pin,
// meaningful only when digitalMode[idx] == modePWM.
var pwmChan [14]uint8

// pwmTimer reports which of the Uno's 3 PWM timers owns a given digital pin
// index, for the 6 pins that have hardware PWM at all (D3, D5, D6, D9, D10,
// D11 -- the rest of D0-D13 have no timer wired to them on this chip).
func pwmTimer(idx uint8) (machine.PWM, bool) {
	switch idx {
	case 5, 6:
		return machine.Timer0, true // D5=PD5, D6=PD6
	case 9, 10:
		return machine.Timer1, true // D9=PB1, D10=PB2
	case 3, 11:
		return machine.Timer2, true // D3=PD3, D11=PB3
	}
	return machine.PWM{}, false
}

func main() {
	uart := machine.Serial
	uart.Configure(machine.UARTConfig{BaudRate: 115200})
	machine.InitADC()

	var line [48]byte
	for {
		n := readLine(uart, line[:])
		if n == 0 {
			continue
		}
		handle(uart, string(line[:n]))
	}
}

// readLine blocks (polling, not sleeping) until a full \n- or \r\n-terminated
// line arrives, then returns its length with the terminator stripped. Bytes
// past cap(buf) are silently dropped rather than overflowing.
func readLine(uart *machine.UART, buf []byte) int {
	i := 0
	for {
		if uart.Buffered() == 0 {
			continue
		}
		b, _ := uart.ReadByte()
		switch b {
		case '\r':
			// swallow; wait for the \n that should follow
		case '\n':
			if i == 0 {
				continue // ignore blank lines
			}
			return i
		default:
			if i < len(buf) {
				buf[i] = b
				i++
			}
		}
	}
}

func handle(uart *machine.UART, line string) {
	fields := split(line)
	if len(fields) == 0 {
		return
	}
	switch fields[0] {
	case "PING":
		reply(uart, "PONG")
	case "ID":
		reply(uart, "ID "+version)
	case "HELP":
		help(uart)
	case "MODE":
		cmdMode(uart, fields)
	case "READ":
		cmdRead(uart, fields)
	case "WRITE":
		cmdWrite(uart, fields)
	case "PWM":
		cmdPWM(uart, fields)
	default:
		errReply(uart, "bad-command")
	}
}

func cmdMode(uart *machine.UART, fields []string) {
	if len(fields) != 3 {
		errReply(uart, "bad-args")
		return
	}
	idx, analog, ok := parsePin(fields[1])
	if !ok {
		errReply(uart, "bad-pin")
		return
	}
	if idx <= 1 && !analog {
		errReply(uart, "reserved-uart")
		return
	}
	if analog {
		errReply(uart, "analog-fixed-input")
		return
	}
	if fields[2] == "PWM" {
		timer, ok := pwmTimer(idx)
		if !ok {
			errReply(uart, "not-pwm-pin")
			return
		}
		// Default PWMConfig (Period: 0) picks a fixed period tuned for LEDs on
		// all 3 timers -- see machine.PWM.Configure. Reconfiguring a timer
		// that's already running its other channel is harmless: the default
		// config is the same every time, so this is idempotent.
		timer.Configure(machine.PWMConfig{})
		ch, err := timer.Channel(digitalPins[idx])
		if err != nil {
			errReply(uart, "pwm-config-failed")
			return
		}
		pwmChan[idx] = ch
		digitalMode[idx] = modePWM
		reply(uart, "OK")
		return
	}
	var pc machine.PinConfig
	var m mode
	switch fields[2] {
	case "IN":
		pc, m = machine.PinConfig{Mode: machine.PinInput}, modeIn
	case "OUT":
		pc, m = machine.PinConfig{Mode: machine.PinOutput}, modeOut
	case "PULLUP":
		pc, m = machine.PinConfig{Mode: machine.PinInputPullup}, modeInPullup
	default:
		errReply(uart, "bad-mode")
		return
	}
	digitalPins[idx].Configure(pc)
	digitalMode[idx] = m
	reply(uart, "OK")
}

func cmdRead(uart *machine.UART, fields []string) {
	if len(fields) != 2 {
		errReply(uart, "bad-args")
		return
	}
	idx, analog, ok := parsePin(fields[1])
	if !ok {
		errReply(uart, "bad-pin")
		return
	}
	if idx <= 1 && !analog {
		errReply(uart, "reserved-uart")
		return
	}
	if analog {
		adc := machine.ADC{Pin: analogPins[idx]}
		adc.Configure(machine.ADCConfig{})
		// AVR ADC.Get() returns a left-justified 16-bit value (10 significant
		// bits); shift down to the familiar 0-1023 analogRead() range.
		okReplyUint(uart, adc.Get()>>6)
		return
	}
	v := uint16(0)
	if digitalPins[idx].Get() {
		v = 1
	}
	okReplyUint(uart, v)
}

func cmdWrite(uart *machine.UART, fields []string) {
	if len(fields) != 3 {
		errReply(uart, "bad-args")
		return
	}
	idx, analog, ok := parsePin(fields[1])
	if !ok {
		errReply(uart, "bad-pin")
		return
	}
	if idx <= 1 && !analog {
		errReply(uart, "reserved-uart")
		return
	}
	if analog {
		errReply(uart, "analog-fixed-input")
		return
	}
	if digitalMode[idx] != modeOut {
		errReply(uart, "not-configured-output")
		return
	}
	switch fields[2] {
	case "0":
		digitalPins[idx].Set(false)
	case "1":
		digitalPins[idx].Set(true)
	default:
		errReply(uart, "bad-value")
		return
	}
	reply(uart, "OK")
}

// cmdPWM sets the duty cycle (0-255, matching Arduino's analogWrite scale)
// on a pin previously configured with MODE <pin> PWM.
func cmdPWM(uart *machine.UART, fields []string) {
	if len(fields) != 3 {
		errReply(uart, "bad-args")
		return
	}
	idx, analog, ok := parsePin(fields[1])
	if !ok {
		errReply(uart, "bad-pin")
		return
	}
	if analog {
		errReply(uart, "analog-fixed-input")
		return
	}
	if digitalMode[idx] != modePWM {
		errReply(uart, "not-configured-pwm")
		return
	}
	v, ok := parseUint(fields[2])
	if !ok || v > 255 {
		errReply(uart, "bad-value")
		return
	}
	timer, _ := pwmTimer(idx) // guaranteed ok: only reachable via a prior successful MODE PWM
	timer.Set(pwmChan[idx], uint32(v))
	reply(uart, "OK")
}

func help(uart *machine.UART) {
	reply(uart, "PING")
	reply(uart, "ID")
	reply(uart, "MODE <D2-D13> <IN|OUT|PULLUP|PWM>")
	reply(uart, "READ <D0-D13|A0-A5>")
	reply(uart, "WRITE <D2-D13> <0|1>")
	reply(uart, "PWM <pin> <0-255>")
	reply(uart, "(D0/D1 reserved for USB-serial; A0-A5 are ADC-only)")
	reply(uart, "(PWM mode only valid on D3, D5, D6, D9, D10, D11)")
}

// parsePin decodes "D<n>" (n 0-13) or "A<n>" (n 0-5) into an index into
// digitalPins/analogPins respectively.
func parsePin(s string) (idx uint8, analog bool, ok bool) {
	if len(s) < 2 {
		return 0, false, false
	}
	n, pok := parseUint(s[1:])
	if !pok {
		return 0, false, false
	}
	switch s[0] {
	case 'D':
		if n > 13 {
			return 0, false, false
		}
		return uint8(n), false, true
	case 'A':
		if n > 5 {
			return 0, false, false
		}
		return uint8(n), true, true
	default:
		return 0, false, false
	}
}

// parseUint is a tiny hand-rolled replacement for strconv.ParseUint — no
// imports, no allocation, keeps us well clear of the 2 KB RAM ceiling.
func parseUint(s string) (uint16, bool) {
	if len(s) == 0 {
		return 0, false
	}
	var v uint16
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c < '0' || c > '9' {
			return 0, false
		}
		v = v*10 + uint16(c-'0')
	}
	return v, true
}

// split breaks a line into space-separated fields without allocating a
// []string per call the way strings.Split's sibling strings.Fields would —
// fields here is a fixed-size backing array reused across calls.
var fieldBuf [4]string

func split(line string) []string {
	n := 0
	start := -1
	for i := 0; i <= len(line); i++ {
		atSpace := i == len(line) || line[i] == ' '
		if !atSpace && start < 0 {
			start = i
		} else if atSpace && start >= 0 {
			if n < len(fieldBuf) {
				fieldBuf[n] = line[start:i]
				n++
			}
			start = -1
		}
	}
	return fieldBuf[:n]
}

func reply(uart *machine.UART, s string) {
	uart.Write([]byte(s))
	uart.Write([]byte("\r\n"))
}

func errReply(uart *machine.UART, reason string) {
	reply(uart, "ERR "+reason)
}

func okReplyUint(uart *machine.UART, v uint16) {
	var buf [5]byte
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
	uart.Write([]byte("OK "))
	uart.Write(buf[i:])
	uart.Write([]byte("\r\n"))
}
