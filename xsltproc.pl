#!/usr/bin/env perl

=begin comment

  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021-26  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

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
use Encode qw(decode decode_utf8 encode);
use Encode::Locale;
use XML::LibXSLT;
use Term::ANSIColor qw(colored);
use IO::Handle;

Encode::Locale::decode_argv(Encode::FB_CROAK);

my @files = ();
my %params;
my ($stylefile, $input, $output);

# Pretty print messages like LaTeXML (adapted from LaTeXML::Common::Error)
BEGIN {
  require Win32::Console if $^O eq 'MSWin32';
}

binmode(STDERR, ":encoding(utf-8)");
*STDERR->autoflush();

# recode output messages from Perl to match the messages from libxslt
sub encode_console {
  my ($message) = @_;
  return encode('console_out', $message, Encode::FB_CROAK | Encode::LEAVE_SRC);
}

sub decode_console {
  my ($message) = @_;
  return decode('console_out', $message, Encode::FB_CROAK | Encode::LEAVE_SRC);
}

my $IS_TERMINAL = -t STDERR;

if ($IS_TERMINAL && $^O eq 'MSWin32') {
  # set utf-8 codepage
  # CP_UTF8 = 65001
  Win32::Console::OutputCP(65001);

  # CHECK what does libxslt do after we changed codepage?
  Encode::Locale::reinit;

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
  my $prefix = decode_console("$severity:$category:$object");
  $summary = decode_console($summary);
  print STDERR (($IS_TERMINAL ? colored($prefix, $color_scheme{ lc($severity) }) : $prefix) . " $summary\n");
  exit 1 if $severity eq 'Fatal';
  return;
}

local $SIG{__WARN__} = sub {
  my ($msg) = @_;
  my ($severity, $category, $object, $summary) = $msg =~ m/^([^: ]*):([^: ]*):([^ ]*) ?(.*)$/;
  $severity = $severity // 'Error';
  $object   = $object   // 'unknown';
  $category = $category // 'internal';
  $summary  = $summary  // $msg;
  Error($severity, $object, $category, $summary . ($input ? " at $input;" : ''));
};

while (@ARGV) {
  my $arg = shift @ARGV;
  if ($arg eq '--stringparam') {
    my $key   = shift @ARGV;
    my $value = shift @ARGV;
    ($key, $value) = XML::LibXSLT::xpath_to_string($key => $value);
    $params{$key} = $value;
  } elsif ($arg eq '--output' || $arg eq '-o') {
    $output = shift @ARGV;
  } elsif ($arg =~ /^-/) {
    Error('Fatal', 'unexpected', encode_console('$arg'), 'this minimal script only supports --stringparam, --output, -o');
  } else {
    if (defined $stylefile) {
      $input = $arg;
    } else {
      $stylefile = $arg;
    }
  }
}

Error('Fatal', 'expected', 'input',      'must specify an input file')  unless defined $input;
Error('Fatal', 'expected', 'stylesheet', 'must specify a stylesheet')   unless defined $stylefile;
Error('Fatal', 'expected', 'output',     'must specify an output file') unless defined $output;

my $raw_input     = encode('locale_fs', $input,     Encode::FB_CROAK | Encode::LEAVE_SRC);
my $raw_stylefile = encode('locale_fs', $stylefile, Encode::FB_CROAK | Encode::LEAVE_SRC);
my $raw_output    = encode('locale_fs', $output,    Encode::FB_CROAK | Encode::LEAVE_SRC);

Error('Fatal', 'missing', 'input', encode_console("cannot open input file '$input'")) unless -f $raw_input;
Error('Fatal', 'missing', 'stylesheet', encode_console("cannot open stylesheet '$stylefile'")) unless -f $raw_stylefile;

my $xslt       = XML::LibXSLT->new();
my $stylesheet = $xslt->parse_stylesheet_file($raw_stylefile);
my $result     = $stylesheet->transform_file($raw_input, %params);
$stylesheet->output_file($result, $raw_output);
