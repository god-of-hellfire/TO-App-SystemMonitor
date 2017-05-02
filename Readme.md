# TO-App-SystemMonitor

The intention of this Perl package is to monitor the memory usage of the localhost at a certain frequency and send
alerts automatically if a configurable threshold was exceeded.

It comes as a modulino.

# Version

1.0.1

# Installation CentOS 7

```bash
git clone git@github.com:god-of-hellfire/TO-App-SystemMonitor.git
cd to-app-systemmonitor/perl
make test
vi etc/config.yaml-dist         # Set email to a valid adress in each section
sudo make install
systemctl status system-monitor
```

# Configuration

This project is configured by two configuration files.

## Daemon

The daemon processing is controlled by a yaml configuration file that is stored in '/etc/system-monitor/config.yaml'.

The **free** section controlls the parsing of the ouput of the free command on your system.

```yaml
---

logLevel: LOG_WARNING

pollingInterval: 600

free:
  mem:
    row: 1
    pattern: '^Mem: \s+ (?<total>\d+) \s+ (?<used>\d+) \s+ (?<free>\d+) \s+ (?<shared>\d+) \s+ (?<buffCache>\d+) \s+ (?<available>\d+)'
    threshold: 0.85
    notification:
      email:
  swap:
    row: 2
    pattern: '^Swap: \s+ (?<total>\d+) \s+ (?<used>\d+) \s+ (?<free>\d+) \s+'
    threshold: 0.2
    notification:
      email:
```

## systemd
```bash
[Unit]
Description=Memory Usage Monitor

[Service]
ExecStart=/usr/local/bin/system-monitor /etc/system-monitor/config.yaml
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=graphical.target
```

# Todo

More tests to get 100% coverage.

# Caveats

Right now the project is best used on CentOS with systemd.

# License

Copyright 2017 Theo Ohnsorge

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
