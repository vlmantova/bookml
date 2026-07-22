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
use Cwd;
use Encode qw(decode decode_utf8 encode);
use Encode::Locale;
use File::Spec;
use Term::ANSIColor qw(colored);

use open ':std', ':encoding(UTF-8)';
binmode(STDERR, ':encoding(UTF-8)');
binmode(STDOUT, ':encoding(UTF-8)');
*STDERR->autoflush();

BEGIN {
  if ($^O eq 'MSWin32') {
    require Win32;
    require Win32::Console;
  }
}

Encode::Locale::decode_argv(Encode::FB_CROAK);

# Pretty print messages like LaTeXML (adapted from LaTeXML::Common::Error)
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

sub Message {
  my ($severity, $category, $object, $summary) = @_;
  my $prefix = "$severity:$category:$object";
  print STDERR (($IS_TERMINAL ? colored($prefix, $color_scheme{ lc($severity) }) : $prefix) . " $summary\n");
  exit 1 if $severity eq 'Fatal';
}

sub Fatal {
  Message('Fatal', @_);
}

my @logs = ();
my ($auxdir, $output);
my $cwd = $^O eq 'MSWin32' ? Win32::GetLongPathName(Win32::GetCwd()) : decode('locale_fs', Cwd::getcwd, Encode::FB_CROAK);

sub normalize_path {
  my ($file) = @_;
  $file = Win32::GetLongPathName($file) if $^O eq 'MSWin32';
  $file = File::Spec->canonpath($file);
  if (File::Spec->file_name_is_absolute($file)) {
    my $relfile = File::Spec->abs2rel($file, $cwd);
    if (!File::Spec->file_name_is_absolute($relfile)) {
      my ($top) = File::Spec->splitdir($relfile);
      $file = $relfile if $top ne File::Spec->updir;
    }
  } else {
    my ($top) = File::Spec->splitdir($file);
    $file = File::Spec->rel2abs($file, $cwd) if $top eq File::Spec->updir;
  }
  $file =~ s!\\!/!g;
  $file =~ s! !\\ !g;
  return $file;
}

while (@ARGV) {
  my $arg = shift @ARGV;
  if ($arg eq '--output' || $arg eq '-o') {
    $output = (shift @ARGV) or Fatal('expected', 'output', "argument required after $arg");
  } elsif ($arg eq '--auxdir' || $arg eq '-a') {
    $auxdir = (shift @ARGV) or Fatal('expected', 'auxdir', "argument required after $arg");
  } elsif ($arg =~ /^-/) {
    Fatal('unexpected', '$arg', 'this minimal script only supports --auxdir, -a, --output, -o');
  } else {
    push(@logs, $arg);
  }
}

Fatal('expected', 'aux-dir', 'you must specify the aux directory with --auxdir') unless $auxdir;

$auxdir = normalize_path($auxdir);

my $deps = {};

for my $log (@logs) {
  open(my $log_fh, '<', encode('locale_fs', $log, Encode::FB_CROAK | Encode::LEAVE_SRC)) or Fatal('I/O', $log, "cannot read '$log': $!");
  print STDERR "log '$log'\n";
  my $logname = normalize_path($log) =~ s!^$auxdir/!!r;
  print STDERR "'$logname'\n";
  if ($logname =~ m!^latexmlaux/(.*)\.latexml\.log!) {
    my $jobname = $1;
  } elsif ($logname =~ m!^pdf((?:aux)?)/(.*)\.(fls|log)$!) {
    my $aux     = $1;
    my $ext     = $3;
    my $jobname = $aux ? $2 : $2 =~ s!\.pdf/[^/]*$!!r;
    if ($ext eq 'fls') {
      while (<$log_fh>) {
        if (m/^\s*(INPUT|OUTPUT)\s+(.*)$/) {
          my $type = $1;
          my $file = normalize_path($2);
          $$deps{"pdf$aux/$jobname"}{ lc($type) }{$file} = 1;
        }
      }
    } else {
      my $nextline = 0;
      while (<$log_fh>) {
        if (m/^\s*Package xr Info: IMPORTING LABELS FROM (.*) on input line \d+.\s*$/) {
          my $file = normalize_path($1);
          $$deps{"pdf$aux/$jobname"}{xr}{$file} = 1;
        } elsif (m/^\s*Package xr Warning:\s*$/) {
          $nextline = 1;
        } elsif ($nextline) {
          $nextline = 0;
          if (m/^\s*No file (.*)\s*$/) {
            my $raw_file = $1;
            my $file     = normalize_path($1);
            $file = "$auxdir/pdfaux/$file" if !File::Spec->file_name_is_absolute($raw_file);
            $$deps{"pdf$aux/$jobname"}{xr}{$file} = 1;
          }
        }
      }
    }
  } else {
    Fatal('malformed', $logname, 'cannot determine source of log');
  }
}

use Data::Dumper;

print STDERR Dumper($deps);

exit 1;

my $jobname;
my $pdf     = "$auxdir/pdf/$jobname.pdf/$jobname.pdf";
my $aux     = "$auxdir/pdf/$jobname.pdf/$jobname.aux";
my $auxnoxr = "$auxdir/pdfnoxr/$jobname.aux";
my $fls     = "$auxdir/pdf/$jobname.pdf/$jobname.fls";
my $log     = "$auxdir/pdf/$jobname.pdf/$jobname.logdeps";
my $pdfdeps = "$auxdir/deps/$jobname.pdfdeps";

open(my $fls_fh, '<', encode('locale_fs', $fls, Encode::FB_CROAK)) or die "cannot read '$fls': $!";
open(my $log_fh, '<', encode('locale_fs', $log, Encode::FB_CROAK)) or die "cannot read '$log': $!";

my %inputs   = ();
my %outputs  = ();
my %xrinputs = ();

while (<$fls_fh>) {
  if (m/^\s*(INPUT|OUTPUT)\s+(.*)$/) {
    my $type = $1;
    my $file = normalize_path($2);
    if ($type eq 'INPUT') {
      $inputs{$file} = 1;
    } else {
      $outputs{$file} = 1;
    }
  }
}

my $nextline = 0;
while (<$log_fh>) {
  if (m/^\s*Package xr Info: IMPORTING LABELS FROM (.*) on input line \d+.\s*$/) {
    my $file = normalize_path($1);
    my $tex  = ($file =~ s!^$auxdir/pdf/!!r) =~ s!\.aux$!.tex!r;
    delete $inputs{$file};
    if (!File::Spec->file_name_is_absolute($file)) {
      # if .aux is in the current directory (e.g. by compiling outside of BookML)
      $file = "$auxdir/pdf/$file" if $file !~ m!^$auxdir/!;
      delete $inputs{$file};
      # we only want the .aux files coming from compilable .tex files
      # luckily \externaldocument calls \set@curr@file, leaving a trace in .fls
      next unless $inputs{$tex};
    }
    $file =~ s!^$auxdir/pdf/!$auxdir/pdfnoxr/!;
    $xrinputs{$file} = 1;
  } elsif (m/^\s*Package xr Warning:\s*$/) {
    $nextline = 1;
  } elsif ($nextline) {
    $nextline = 0;
    if (m/^\s*No file (.*)\s*$/) {
      my $file = normalize_path($1);
      $file = "$auxdir/pdfnoxr/$file" if !File::Spec->file_name_is_absolute($file);
      $xrinputs{$file} = 1;
    }
  }
}

my $makefile = "";

if (my @outputs = grep { $_ !~ m!^$auxdir/pdf/$jobname\.(?:aux|fls|pdf)! } (sort(keys %outputs))) {
  for (@outputs) {
    delete $inputs{$_};
  }
  # flag that the outputs are regenerated when the PDF is recompiled
  # exclude .aux, .fls which are grouped with .pdf in bookml.mk
  # (this won't regenerate missing files, however)
  @outputs = grep { $_ !~ m!^$auxdir/pdf/$jobname\.(?:aux|fls|pdf)! } @outputs;
  $makefile .= join(' ', @outputs) . ": $pdf ;\n";
}

my @xrinputs = sort(keys %xrinputs);

if (my @inputs = (sort(keys %inputs), @xrinputs)) {
  $makefile .= "$pdf $aux $fls $log $auxnoxr:";

  for (@inputs) {
    $makefile .= " \\\n  $_" unless m!^$auxdir/!;
  }

  if (my @noxrinputs = sort(grep { m!^$auxdir/pdfnoxr/! } @inputs)) {
    $makefile .= "\n\n$pdf $aux $fls $log:";

    for (@noxrinputs) {
      $makefile .= " \\\n  $_";
    }
  }

  if (%xrinputs) {
    $makefile .= "\n\nifneq (,\$(filter $pdf,\$(BMLGOALS.PDF)))\n";
    my @auxs = grep { m!^$auxdir/pdfnoxr/! } @xrinputs;
    for (@auxs) {
      my $pdfnoxr = $_ =~ s!^$auxdir/pdfnoxr/((?:.*/)?)([^/]*)\.aux$!$auxdir/pdf/$1$2.pdf/$2.pdf!r;
      my $deps    = $_ =~ s!^$auxdir/pdfnoxr/(.*)\.aux$!$auxdir/deps/$1.pdfdeps!r;
      $makefile .= "ifeq (,\$(filter $pdfnoxr,\$(BMLGOALS.PDF))\$(wildcard $deps))\n-include $deps\nendif\n";
    }
    $makefile .= 'BMLGOALS.PDF += ';
    $makefile .= join(' ', map { s!^$auxdir/pdfnoxr/((?:.*/)?)([^/]*)\.aux$!$auxdir/pdf/$1$2.pdf/$2.pdf!r } (grep { m!^$auxdir/pdfnoxr/! } @xrinputs));
    $makefile .= "\nendif";
  }

  $makefile .= "\n";

  for (@inputs) {
    $makefile .= "\n$_:";
  }

  $makefile .= "\n";
}

open(my $fh_pdfdeps, '>', encode('locale_fs', $pdfdeps, Encode::FB_CROAK)) or die "cannot write '$pdfdeps': $!";
print $fh_pdfdeps $makefile;
