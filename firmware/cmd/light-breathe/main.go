// light-breathe: standalone, ambient firmware for the salvaged RGB "disco
// dome" light (3 common-anode LEDs on the Uno's 3 PWM timers). Runs
// entirely on-device -- no host, no serial protocol, nothing to send it.
// Flash the Uno with this and it just breathes, forever, on power-up.
//
// Pin mapping (found empirically, see AGENTS.md / testbench notes):
//
//	D5 = blue, D6 = green, D9 = red
//
// Wiring: dome's common (brown) -> 5V (common ANODE -- confirmed via
// diode-mode multimeter check, current only flowed anode-to-cathode with
// the meter's positive lead on brown). Each color line -> its D-pin,
// cathode side, so the LED lights while the pin is driven LOW. That's why
// duty is inverted below (255-v, not v) -- see PROTOCOL.md's PWM section
// for the same inversion on the probe firmware's PWM command.
//
// Each channel breathes on its own period and phase offset so the 3
// colors drift in and out of sync with each other rather than pulsing in
// lockstep -- same idea as the host-side awk/sine script this replaces,
// just running autonomously instead of being streamed over serial.
package main

import (
	"machine"
	"math"
	"time"
)

// One firmware, one device: unlike cmd/probe (general-purpose, any pin),
// this is hardwired to the dome's specific 3 pins and their specific
// timers.
type channel struct {
	timer  machine.PWM
	pin    machine.Pin
	ch     uint8
	period float64 // seconds per full breath cycle
	phase  float64 // radians, offsets where in its cycle this channel starts
}

var channels = []*channel{
	{timer: machine.Timer0, pin: machine.D6, period: 3.7, phase: 2.0}, // green
	{timer: machine.Timer0, pin: machine.D5, period: 4.3, phase: 4.0}, // blue -- shares Timer0 with D6, independent channel
	{timer: machine.Timer1, pin: machine.D9, period: 3.0, phase: 0.0}, // red
}

const tick = 30 * time.Millisecond

func main() {
	for _, c := range channels {
		c.timer.Configure(machine.PWMConfig{})
		ch, err := c.timer.Channel(c.pin)
		if err != nil {
			// Nothing sensible to do without a host to report to --
			// blink the onboard LED distinctively fast so a wiring/pin
			// mistake is visible without a serial connection.
			panicBlink()
		}
		c.ch = ch
	}

	var t float64
	for {
		for _, c := range channels {
			// Duty is fraction-of-time-HIGH; these are common-anode LEDs
			// (cathode on the pin), so brightest is pin-LOW, not
			// pin-HIGH -- invert the wave (255-v) to make v=255 mean
			// "brightest" the way it intuitively should.
			v := (math.Sin(2*math.Pi*t/c.period+c.phase) + 1) / 2 * 255
			c.timer.Set(c.ch, uint32(255-v))
		}
		t += tick.Seconds()
		time.Sleep(tick)
	}
}

func panicBlink() {
	led := machine.LED
	led.Configure(machine.PinConfig{Mode: machine.PinOutput})
	for {
		led.High()
		time.Sleep(80 * time.Millisecond)
		led.Low()
		time.Sleep(80 * time.Millisecond)
	}
}
