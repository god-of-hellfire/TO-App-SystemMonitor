SHELL=/usr/bin/bash

install: clean build
	@mkdir -p /usr/local/lib/system-monitor
	@cp -r build/usr/local/lib/system-monitor/TO /usr/local/lib/system-monitor
	@mkdir -p /etc/system-monitor
	@cp -r build/etc/system-monitor/* /etc/system-monitor
	@cp etc/system-monitor.service-dist /usr/lib/systemd/system/system-monitor.service
	@ln -sf /usr/local/lib/system-monitor/TO/App/SystemMonitor.pm /usr/local/bin/system-monitor
	@systemctl enable system-monitor
	@systemctl restart system-monitor

build:
	@mkdir -p build/usr/local/lib/system-monitor build/etc/system-monitor
	@cp -r lib/TO build/usr/local/lib/system-monitor
	@cp etc/config.yaml-dist build/etc/system-monitor/.
	@cp etc/config.yaml-dist build/etc/system-monitor/config.yaml

test:
	@prove --rc=t/.proverc t

critic:
	-for dir in lib t; do perlcritic -profile $${dir}/.perlcriticrc $${dir}$(CRITIC); done

cover:
	rm -rf cover_db
	HARNESS_PERL_SWITCHES=-MDevel::Cover prove --rc t/.proverc-cover t
	cover -report html -select_re '^lib/.*\.pm'

clean:
	@rm -rf build

.PHONY: install build test critic cover clean