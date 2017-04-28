#!/usr/bin/env perl

use warnings FATAL => 'all';
use strict;

use Test::More tests => 2;
use Test::Exception;

BEGIN {

  no warnings;

  # Load testee
  use_ok('TO::App::SystemMonitor');

  # Mock internal functions
  *TO::App::SystemMonitor::syslog = sub { return; };
  *TO::App::SystemMonitor::LoadFile = sub { return; };


};

# Call _loadConfiguration w/o arguments
is(TO::App::SystemMonitor::_loadConfiguration(), undef, 'Call _loadConfiguration w/o arguments');
