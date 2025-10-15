#!/usr/bin/env perl

=begin comment

  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021-25  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.

=end comment

=cut

use warnings;
use strict;
use XML::LibXSLT;
use Term::ANSIColor qw(colored);
use IO::Handle;

my @files = ();
my %params;
my ($stylefile, $input, $output);

# Pretty print messages like LaTeXML (adapted from LaTeXML::Common::Error)
BEGIN {
  require Win32::Console if $^O eq 'MSWin32';
}

binmode(STDERR, ":encoding(UTF-8)");
*STDERR->autoflush();

my $IS_TERMINAL = -t STDERR;

if ($IS_TERMINAL && $^O eq 'MSWin32') {
  # set utf-8 codepage
  # CP_UTF8 = 65001
  Win32::Console::OutputCP(65001);

  # get standard error console
  our $W32_STDERR = Win32::Console->new(&Win32::Console::STD_ERROR_HANDLE());

  # enable VT100 emulation or fall back to ANSI emulation if unsuccessful
  # ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004 (not exported by Win32::Console)
  my $mode = $W32_STDERR->Mode();
  unless ($W32_STDERR->Mode($mode | 0x0004) && $W32_STDERR->Mode() & 0x0004) {
    require Win32::Console::ANSI; } }

my %color_scheme = (
  details => 'bold',
  success => 'green',
  info    => 'bright_blue',
  warning => 'yellow',
  error   => 'bold red',
  fatal   => 'bold red underline',
);

sub Error {
  my ($severity, $category, $object, $summary) = @_;
  my $prefix = "$severity:$category:$object";
  print STDERR (($IS_TERMINAL ? colored($prefix, $color_scheme{lc($severity)}) : $prefix) . " $summary\n");
  exit 1 if $severity eq 'Fatal';
}

$SIG{__WARN__} = sub {
  my ($msg) = @_;
  my ($severity, $category, $object, $summary) = $msg =~ m/^([^: ]*):([^: ]*):([^ ]*) ?(.*)$/;
  $severity = $severity // 'Error';
  $object = $object // 'unknown';
  $category = $category // 'internal';
  $summary = $summary // $msg;
  Error($severity, $object, $category, $summary . ($input ? " at $input;" : ''));
};

while (@ARGV) {
  my $arg = shift @ARGV;
  if ($arg eq '--stringparam') {
    my $key = shift @ARGV;
    my $value = shift @ARGV;
    ($key, $value) = XML::LibXSLT::xpath_to_string($key => $value);
    $params{$key} = $value;
  } elsif ($arg eq '--output' || $arg eq '-o') {
    $output = shift @ARGV;
  } elsif ($arg =~ /^-/) {
    Error('Fatal', 'unexpected', '$arg', 'this minimal script only supports --stringparam, --output, -o');
  } else {
    if (defined $stylefile) {
      $input = $arg;
    } else {
      $stylefile = $arg;
    }
  }
}

Error('Fatal', 'expected', 'input', 'must specify an input file') unless defined $input;
Error('Fatal', 'expected', 'stylesheet', 'must specify a stylesheet') unless defined $stylefile;
Error('Fatal', 'expected', 'output', 'must specify an output file') unless defined $output;

Error('Fatal', 'missing', 'input', 'cannot open input file') unless -f $input;
Error('Fatal', 'missing', 'stylesheet', 'cannot open stylesheet') unless -f $stylefile;

my $xslt = XML::LibXSLT->new();
my $stylesheet = $xslt->parse_stylesheet_file($stylefile);
my $result = $stylesheet->transform_file($input, %params);
$stylesheet->output_file($result, $output);
