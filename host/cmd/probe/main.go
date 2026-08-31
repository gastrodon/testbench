// probe is a thin CLI over the testbench host client, for ad hoc GPIO
// probing without writing Go each time.
package main

import (
	"bufio"
	"fmt"
	"os"

	testbench "github.com/gastrodon/testbench/host"
)

func usage() {
	fmt.Fprintln(os.Stderr, `usage:
  probe <device> <command> [args...]   one-shot: opens, runs, resets on exit
  probe <device>                        batch: reads protocol lines from
                                         stdin over ONE open connection

commands:
  ping
  id
  mode <pin> <IN|OUT|PULLUP>
  read <pin>
  write <pin> <0|1>

pins: D0-D13 (digital; D0/D1 reserved for USB-serial), A0-A5 (analog, read-only)
device: e.g. /dev/hw-bench/uno or /dev/ttyACM0

Note: every connection resets the board (DTR auto-reset), which wipes any
pin MODE previously configured. Stateful sequences (MODE then WRITE) need
to run over one connection — use batch mode (echo commands into stdin, or
pipe a file of them) rather than separate one-shot invocations.`)
	os.Exit(2)
}

func main() {
	if len(os.Args) == 2 {
		batch(os.Args[1])
		return
	}
	if len(os.Args) < 3 {
		usage()
	}
	device, cmd, args := os.Args[1], os.Args[2], os.Args[3:]

	c, err := testbench.Open(device)
	if err != nil {
		fatal(err)
	}
	defer c.Close()

	switch cmd {
	case "ping":
		fatalIf(c.Ping())
		fmt.Println("pong")
	case "id":
		id, err := c.ID()
		fatalIf(err)
		fmt.Println(id)
	case "mode":
		if len(args) != 2 {
			usage()
		}
		fatalIf(c.Mode(args[0], testbench.PinMode(args[1])))
		fmt.Println("ok")
	case "read":
		if len(args) != 1 {
			usage()
		}
		v, err := c.Read(args[0])
		fatalIf(err)
		fmt.Println(v)
	case "write":
		if len(args) != 2 {
			usage()
		}
		fatalIf(c.Write(args[0], args[1] == "1"))
		fmt.Println("ok")
	default:
		usage()
	}
}

// batch keeps one connection open and relays raw protocol lines from stdin,
// printing each raw response — for stateful command sequences, or piping in
// a saved script of commands.
func batch(device string) {
	c, err := testbench.Open(device)
	if err != nil {
		fatal(err)
	}
	defer c.Close()

	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}
		resp, err := c.Raw(line)
		if err != nil {
			fatal(err)
		}
		fmt.Println(resp)
	}
	fatalIf(scanner.Err())
}

func fatalIf(err error) {
	if err != nil {
		fatal(err)
	}
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "probe:", err)
	os.Exit(1)
}
