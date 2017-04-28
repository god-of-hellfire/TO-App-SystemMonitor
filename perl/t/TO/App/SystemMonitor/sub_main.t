#!/usr/bin/env perl

use warnings FATAL => 'all';
use strict;

use Test::More tests => 11;
use Test::Exception;

use File::Temp qw(tempfile);
use YAML::XS qw(LoadFile);

my $qxFlag;
BEGIN {

  no warnings;

  # Mock qx, backticks
  *TO::App::SystemMonitor::readpipe = sub {
    return $qxFlag;
  };

  # Load testee
  use_ok('TO::App::SystemMonitor');

  # Mock internal functions
  *TO::App::SystemMonitor::openlog = sub { return; };
  *TO::App::SystemMonitor::setlogmask = sub { return; };
  *TO::App::SystemMonitor::syslog = sub { return; };
  *TO::App::SystemMonitor::closelog = sub { return; };
  *TO::App::SystemMonitor::_loadConfiguration = sub { return LoadFile(shift); };
  *TO::App::SystemMonitor::_getMemoryUsage = sub { return; };
  *TO::App::SystemMonitor::_checkMemoryUsage = sub { return; };

};

# Prepare tests
my @argv;
my $fh;
my $filename;
my @configurationContent = <DATA>;
local $SIG{ALRM} = sub { $TO::App::SystemMonitor::stopSignal = 1 };

# Call w/o parameters
is(TO::App::SystemMonitor::main(), 1, 'Call w/o parameters');

# Call SIG{TERM} handler
is($SIG{TERM}(), undef, 'Call SIG{TERM} handler');

# Call SIG{INT} handler
is($SIG{INT}(), undef, 'Call SIG{INT} handler');

# Call SIG{HUP} handler
is($SIG{HUP}(), undef, 'Call SIG{HUP} handler');

# Call with empty configuration file
($fh, $filename) = tempfile(UNLINK => 1, OPEN => 1);
@argv = ($filename);
is(TO::App::SystemMonitor::main(@argv), 1, 'Call with empty configuration file');

# Call with broken configuration file
($fh, $filename) = tempfile(UNLINK => 1, OPEN => 1);
print $fh 'broken.yaml';
$fh->flush();
@argv = ($filename);
is(TO::App::SystemMonitor::main(@argv), 1, 'Call with broken configuration file');

# Call with broken qx call
($fh, $filename) = tempfile(UNLINK => 1, OPEN => 1);
print $fh @configurationContent;
$fh->flush();
@argv = ($filename);
is(TO::App::SystemMonitor::main(@argv), 0, 'Call with broken qx call');

# Call with working qx call
($fh, $filename) = tempfile(UNLINK => 1, OPEN => 1);
$qxFlag = 1;
print $fh @configurationContent;
$fh->flush();
@argv = ($filename);
is(TO::App::SystemMonitor::main(@argv), 0, 'Call with working qx call');

# Call and exit by signal TERM
($fh, $filename) = tempfile(UNLINK => 1, OPEN => 1);
print $fh @configurationContent;
$fh->flush();
$TO::App::SystemMonitor::stopSignal = undef;
alarm 1;
@argv = ($filename);
is(TO::App::SystemMonitor::main(@argv), 0, 'Call and exit by signal TERM');

# Call and reload configuration by signaling HUP
($fh, $filename) = tempfile(UNLINK => 1, OPEN => 1);
print $fh @configurationContent;
$fh->flush();
$TO::App::SystemMonitor::stopSignal = undef;
$TO::App::SystemMonitor::signal = 'HUP';
alarm 2;
@argv = ($filename);
is(TO::App::SystemMonitor::main(@argv), 0, 'Call and reload configuration by signaling HUP');

done_testing();

__DATA__
---

logLevel: LOG_WARNING

pollingInterval: 5

free:
  mem:
    row: 1
    pattern: '^Mem: \s+ (?<total>\d+) \s+ (?<used>\d+) \s+ (?<free>\d+) \s+ (?<shared>\d+) \s+ (?<buffCache>\d+) \s+ (?<available>\d+)'
    threshold: 0.25
    notification:
      email: extto@localhost
  swap:
    row: 2
    pattern: '^Swap: \s+ (?<total>\d+) \s+ (?<used>\d+) \s+ (?<free>\d+) \s+'
    threshold: 0.2
    notification:
      email: extto@localhost
