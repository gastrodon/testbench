// Package testbench is a host-side client for boards flashed with the
// testbench-uno firmware (see ../firmware). It talks the line protocol
// documented in PROTOCOL.md over the board's USB-serial port.
package testbench

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

// Client is an open connection to a testbench-uno device.
type Client struct {
	f *os.File
	r *bufio.Reader
}

// Open configures device as a raw 115200 8N1 serial port (no flow control)
// and returns a Client once the board's DTR auto-reset has settled.
//
// device is typically /dev/hw-bench/uno once module/hw-bench.nix's udev
// rules are active, or /dev/ttyACM0 directly before that.
func Open(device string) (*Client, error) {
	stty := exec.Command("stty", "-F", device, "115200", "raw", "-echo", "-crtscts", "clocal")
	if out, err := stty.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("stty %s: %w: %s", device, err, out)
	}

	f, err := os.OpenFile(device, os.O_RDWR, 0)
	if err != nil {
		return nil, fmt.Errorf("open %s: %w", device, err)
	}

	c := &Client{f: f, r: bufio.NewReader(f)}

	// Opening the port toggles DTR, which resets the Uno into its bootloader
	// before the flashed firmware resumes running. The bootloader waits
	// ~1-2s for a flash attempt before jumping to the application, so we
	// have to wait it out before the other end will answer anything.
	time.Sleep(2 * time.Second)

	return c, nil
}

// Close releases the underlying file. It does not reset the board.
func (c *Client) Close() error {
	return c.f.Close()
}

// Raw sends line verbatim (protocol terminator added) and returns the raw
// response line, unparsed. Exists for scripting sequences of commands
// against one open connection — see cmd/probe's stdin batch mode — since
// every new Open() reboots the board via DTR and wipes any pin state a
// previous connection configured.
func (c *Client) Raw(line string) (string, error) {
	return c.command(line)
}

// command sends one line (protocol terminator added) and returns the single
// response line with its CRLF stripped.
func (c *Client) command(line string) (string, error) {
	if _, err := fmt.Fprintf(c.f, "%s\r\n", line); err != nil {
		return "", fmt.Errorf("write: %w", err)
	}
	resp, err := c.r.ReadString('\n')
	if err != nil {
		return "", fmt.Errorf("read: %w", err)
	}
	return strings.TrimRight(resp, "\r\n"), nil
}

// Ping checks the link is alive and speaking the expected protocol.
func (c *Client) Ping() error {
	resp, err := c.command("PING")
	if err != nil {
		return err
	}
	if resp != "PONG" {
		return fmt.Errorf("unexpected reply to PING: %q", resp)
	}
	return nil
}

// ID returns the firmware's self-reported identity string, e.g.
// "testbench-uno v0.1".
func (c *Client) ID() (string, error) {
	resp, err := c.command("ID")
	if err != nil {
		return "", err
	}
	id, ok := strings.CutPrefix(resp, "ID ")
	if !ok {
		return "", fmt.Errorf("unexpected reply to ID: %q", resp)
	}
	return id, nil
}

// PinMode selects how Mode configures a digital pin.
type PinMode string

const (
	In       PinMode = "IN"
	Out      PinMode = "OUT"
	InPullup PinMode = "PULLUP"
)

// Mode configures a digital pin (D2-D13). D0/D1 are reserved for the
// USB-serial link and A0-A5 are fixed ADC inputs — the firmware rejects
// both with a "reserved-uart"/"analog-fixed-input" error.
func (c *Client) Mode(pin string, m PinMode) error {
	return c.okOrErr(fmt.Sprintf("MODE %s %s", pin, m))
}

// Read returns a digital pin's level (0/1) or an analog pin's raw ADC
// reading (0-1023, matching classic Arduino analogRead() scaling).
func (c *Client) Read(pin string) (int, error) {
	resp, err := c.command(fmt.Sprintf("READ %s", pin))
	if err != nil {
		return 0, err
	}
	v, ok := strings.CutPrefix(resp, "OK ")
	if !ok {
		return 0, replyErr(resp)
	}
	var n int
	if _, err := fmt.Sscanf(v, "%d", &n); err != nil {
		return 0, fmt.Errorf("unparseable value in reply %q: %w", resp, err)
	}
	return n, nil
}

// Write drives a digital pin previously configured with Mode(pin, Out).
// Writing a pin that hasn't been configured Out returns an error rather
// than silently reconfiguring it.
func (c *Client) Write(pin string, high bool) error {
	v := "0"
	if high {
		v = "1"
	}
	return c.okOrErr(fmt.Sprintf("WRITE %s %s", pin, v))
}

func (c *Client) okOrErr(line string) error {
	resp, err := c.command(line)
	if err != nil {
		return err
	}
	if resp != "OK" {
		return replyErr(resp)
	}
	return nil
}

func replyErr(resp string) error {
	if reason, ok := strings.CutPrefix(resp, "ERR "); ok {
		return fmt.Errorf("device: %s", reason)
	}
	return fmt.Errorf("unexpected reply: %q", resp)
}
