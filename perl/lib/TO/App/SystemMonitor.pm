#!/usr/bin/env perl

package TO::App::SystemMonitor;

use warnings FATAL => 'all';
use strict;

use YAML::XS qw(LoadFile);
use Sys::Syslog qw(:standard :macros);
use POSIX 'strftime';

use constant EXIT_OK    => 0;
use constant EXIT_ERROR => 1;
use constant MEGABYTE   => 1_024;
use constant GIGABYTE   => 1_024 * MEGABYTE ;
use constant LOG_LEVEL  => {
  LOG_EMERG   => LOG_EMERG,
  LOG_ALERT   => LOG_ALERT,
  LOG_CRIT    => LOG_CRIT,
  LOG_ERR     => LOG_ERR,
  LOG_WARNING => LOG_WARNING,
  LOG_NOTICE  => LOG_NOTICE,
  LOG_INFO    => LOG_INFO,
  LOG_DEBUG   => LOG_DEBUG,
};

our $VERSION = 'v1.0.0';
our $signal = '';
our $stopSignal;

my $configuration;
my $memoryUsage = {};
my $hostname = '';

exit(main(@ARGV)) unless caller();

=head1 PUBLIC SUBROUTINES

=head2 main

=cut
sub main {
  my (@argv) = @_;

  openlog('system-monitor', 'cons,pid', LOG_LOCAL0);

  my $exitCode = EXIT_OK;

  $SIG{TERM} = sub {
    syslog(LOG_INFO, 'Receive TERM signal');
    $signal     = 'TERM';
    $stopSignal = 1;
    return;
  };

  $SIG{INT} = sub {
    syslog(LOG_INFO, 'Receive INT signal');
    $signal     = 'INT';
    $stopSignal = 1;
    return;
  };

  $SIG{HUP} = sub {
    syslog(LOG_INFO, 'Receive HUP signal');
    $signal = 'HUP';
    return;
  };

  eval {

    my $configurationFile = $argv[0];
    die 'Please submit a configuration file as argument, stopped' unless $configurationFile;
    die "Configuration file '$configurationFile' does not exist or is empty, stopped" unless -s $configurationFile;
    $configuration = _loadConfiguration($configurationFile);

    $hostname = qx(hostname) // 'unknown hostname';

    setlogmask(LOG_MASK(LOG_LEVEL->{$configuration->{logLevel}}));
    syslog(LOG_INFO, 'Enter main loop');
    syslog(LOG_INFO, 'Set log priority to %i', LOG_MASK(LOG_LEVEL->{$configuration->{logLevel}}));

    # Set waitCount to pollingInterval to trigger measurement at very first iteration
    my $waitCount = $configuration->{pollingInterval};
    while(!defined($stopSignal)) {

      if ($signal eq 'HUP') {
        $configuration = _loadConfiguration($configurationFile);

        setlogmask(LOG_MASK(LOG_LEVEL->{$configuration->{logLevel}}));
        syslog(LOG_INFO, 'Set log priority to %i', LOG_MASK(LOG_LEVEL->{$configuration->{logLevel}}));

        syslog(LOG_INFO, 'Empty alert hash');
        undef $memoryUsage->{alert};

        $waitCount = $configuration->{pollingInterval};
        $signal = '';
      }

      if ($waitCount >= $configuration->{pollingInterval}) {
        _getMemoryUsage();
        _checkMemoryUsage();
        $waitCount = 0;
      }

      $waitCount++;

      sleep(1);
    }

    1;

  } or do {

    syslog(LOG_ERR, '%s', $@);

    $exitCode = EXIT_ERROR;

  };

  syslog(LOG_INFO, 'Shutdown server');

  closelog();

  return $exitCode;

}

=head1 PRIVATE SUBROUTINES

=head2 _checkMemoryUsage

=cut
sub _checkMemoryUsage {

  eval {
    while(my ($key, $value) = each(%{$memoryUsage->{data}})) {

      my $specification = $configuration->{free}->{$key};

      if ($value->{quota} >= $specification->{threshold}) {

        my $message = sprintf('%s exceeds limit! Total: %i, Used: %i, Utilization: %0.2f%%, Threshold: %0.2f%%',
                              uc($key),
                              $value->{total},
                              $value->{used},
                              $value->{quota} * 100,
                              $specification->{threshold} * 100
                            );

        syslog(LOG_WARNING, '%s', $message);

        $memoryUsage->{alert}->{$key}->{message}  = $message;
        $memoryUsage->{alert}->{$key}->{datetime} = strftime('%d.%m.%Y %H:%M:%S', localtime(time()));

        if (!exists $memoryUsage->{alert}->{$key}->{count}) {
          _sendMail(
            subject => sprintf('%s exceeded on %s', uc($key), $hostname),
            email   => $specification->{notification}->{email},
            content => $message,
          );
        }

        $memoryUsage->{alert}->{$key}->{count}++;

      }

    }

    1;

  } or do {

    syslog(LOG_ERR, '_checkMemoryUsage fails with: %s', $@);

  };

}

=head2 _getMemoryUsage

=cut
sub _getMemoryUsage {

  eval {

    syslog(LOG_INFO, 'Get memory usage');

    my @free = qx(free);

    while(my ($key, $value) = each(%{$configuration->{free}})) {

      $free[$value->{row}] =~ m/$value->{pattern}/x;

      $memoryUsage->{data}->{$key} = {
        epoch     => time,
        total     => $+{total},
        used      => $+{used},
        quota     => sprintf('%0.4f', $+{used} / $+{total}),
        available => $+{available} // 0,
      };

    }

    1;

  } or do {

    syslog(LOG_ERR, '_getMemoryUsage fails with: %s', $@);

  };

  return;
}

=head2 _loadConfiguration

=cut
sub _loadConfiguration {
  my ($configurationFile) = @_;

  my $validConfiguration;

  eval {

    syslog(LOG_INFO, 'Load configuration file: %s', $configurationFile);

    $validConfiguration = $configuration if defined $configuration;
    $configuration      = LoadFile($configurationFile);

    1;

  } or do {

    if (defined $validConfiguration) {

      syslog(LOG_ERR, '_loadConfiguration fails with: %s', $@);
      syslog(LOG_WARNING, 'Fall back to last valid configuraton');
      $configuration = $validConfiguration;

    } else {
      die '';
    }

  };

  return $configuration;

}

=head2 _sendMail

=cut
sub _sendMail {
  my (%params) = @_;

  eval {

    syslog(LOG_INFO, 'Send alert mail to: "%s"', $params{email});

    open(my $mail, "| mail -s '$params{subject}' $params{email}") or die 'Cannot open mail pipe, stopped';
    print $mail $params{content};
    close($mail);

    1;

  } or do {

    syslog(LOG_ERR, '_sendMail fails with: %s', $@);

  };

}

=head1 PURPOSE

=head1 CAVEATS

=head1 LICENSE

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

=cut

1;