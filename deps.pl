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

sub Warn {
  Message('Warning', @_);
}

sub Fatal {
  Message('Fatal', @_);
}

my @logs = ();
my ($output, $physical_auxdir);
my $cwd = $^O eq 'MSWin32' ? Win32::GetLongPathName(Win32::GetCwd()) : decode('locale_fs', Cwd::getcwd, Encode::FB_CROAK);
my $auxdir = '$(AUX_DIR)';

sub normalize_path {
  my ($file) = @_;
  # if $file does not exist (problematic!), fall back gracefully
  if ($^O eq 'MSWin32') {
    if (my $long = Win32::GetLongPathName($file)) {
      $file = $long;
    } else {
      Warn('I/O', $file, "could not determine the long file name, changes to '$file' will likely not be detected");
    };
  }
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

sub logic_path {
  my ($file) = @_;
  $file = normalize_path($file);
  $file =~ s!^$physical_auxdir/!$auxdir/!;
  return $file;
}

while (@ARGV) {
  my $arg = shift @ARGV;
  if ($arg eq '--output' || $arg eq '-o') {
    $output = (shift @ARGV) or Fatal('expected', 'output', "argument required after $arg");
  } elsif ($arg eq '--auxdir' || $arg eq '-a') {
    $physical_auxdir = (shift @ARGV) or Fatal('expected', 'auxdir', "argument required after $arg");
  } elsif ($arg =~ /^-/) {
    Fatal('unexpected', '$arg', 'this minimal script only supports --auxdir, -a, --output, -o');
  } else {
    push(@logs, $arg);
  }
}

Fatal('expected', 'aux-dir', 'you must specify the aux directory with --auxdir or -a') unless $auxdir;
Fatal('expected', 'output', 'you must specify the output file with --output or -o') unless $output;

$physical_auxdir = normalize_path($physical_auxdir);

my $deps = {};

for my $log (@logs) {
  open(my $log_fh, '<', encode('locale_fs', $log, Encode::FB_CROAK | Encode::LEAVE_SRC)) or Fatal('I/O', $log, "cannot read '$log': $!");
  my $logname = logic_path($log) =~ s!^\Q$auxdir\E/!!r;

  if ($logname =~ m!^latexmlaux/(.*)\.latexml\.logdeps!) {
    my $jobname = $1;
  } elsif ($logname =~ m!^pdf((?:aux)?)/(.*)\.(fls|logdeps)$!) {
    my $aux     = $1;
    my $ext     = $3;
    my $jobname = $aux ? $2 : $2 =~ s!\.pdf/[^/]*$!!r;

    if ($ext eq 'fls') {
      while (<$log_fh>) {
        # ignore PWD as we know it is the current working directory, and its encoding may be mangled
        # we do not care about OUTPUT
        if (m/^\s*INPUT\s+(.*)$/) {
          my $file = logic_path($1);
          # skip files that could cause cyclic dependencies
          next if $file =~ m!^\Q$auxdir\E/pdf$aux/!;
          $$deps{"pdf$aux/$jobname"}{INPUT}{$file} = 1;
        }
      }
    } else {
      my $nextline = 0;
      while (<$log_fh>) {
        if (m/^\s*Package xr Info: IMPORTING LABELS FROM (.*\.aux) on input line \d+.\s*$/) {
          my $file = logic_path($1);
          $$deps{"pdf$aux/$jobname"}{XR}{$file} = 1;
        } elsif (m/^\s*Package xr Warning:\s*$/) {
          $nextline = 1;
        } elsif ($nextline) {
          $nextline = 0;
          if (m/^\s*No file (.*)\.aux\s*$/) {
            my $file = $1;
            # the .tex file should exist, start from there to properly resolve the file name on Windows
            my $tex = logic_path("$1.tex");
            my $aux_file = $tex =~ s!\.tex$!.aux!r;
            $$deps{"pdf$aux/$jobname"}{XR}{$aux_file} = 1;
            # pretend that the file actually existed
            $$deps{"pdf$aux/$jobname"}{INPUT}{$tex} = 1 if !$aux;
            if (!$aux) {
              $aux_file = "$auxdir/pdfaux/$aux_file" if !File::Spec->file_name_is_absolute($aux_file);
              $$deps{"pdf$aux/$jobname"}{INPUT}{$aux_file} = 1;
            }
          }
        }
      }
    }
  } else {
    Fatal('malformed', $logname, 'cannot determine source of log');
  }
}

my $makefile = '';

for my $target (sort keys %$deps) {
  my $target_deps = $$deps{$target};

  for (keys %{ $$target_deps{INPUT} }) {
    delete $$target_deps{INPUT}{$_};
    $_ =~ s!^$auxdir/!\$(AUX_DIR)/!;
    $$target_deps{INPUT}{$_} = 1;
  }

  if ($target =~ m!^pdf((?:aux)?)/(.*)$!) {
    my $aux = $1;
    my $jobname = $2;

    $jobname =~ s!\.pdf/[^/]*$!! if !$aux;
    my $fullname = "\$(AUX_DIR)/$target";
    $fullname .= ".pdf/$jobname" if !$aux;

    # dependency on .tex is redundant
    delete $$target_deps{INPUT}{"$jobname.tex"};

    for my $xr (sort keys %{ $$target_deps{XR} }) {
# we only care about root .aux files, not subfiles generated by \include, \bibliography, etc
# root .aux files have a corresponding .tex INPUT line in .fls, thanks to \externaldocument calling \set@curr@file
      my $tex = $xr =~ s!\.aux$!.tex!r;
      if ($$target_deps{INPUT}{$tex}) {
        # dependency on .tex is redundant
        delete $$target_deps{INPUT}{$tex};
      } else {
        delete $$target_deps{XR}{$xr};
      }
    }

    if (my @inputs = sort(keys %{ $$target_deps{INPUT} })) {
      $makefile .= ($aux ? "$fullname.aux $fullname.fls:" : "$fullname.pdf $fullname.aux $fullname.fls $fullname.logdeps:") . " \\\n  ";
      $makefile .= join(" \\\n  ", @inputs);
      $makefile .= "\n\n";
      $makefile .= join(":\n", @inputs);
      $makefile .= ":\n";
    }

    if (!$aux && (my @xr = sort(keys %{ $$target_deps{XR} }))) {
      $makefile .= "\nifneq (,\$(filter $fullname.pdf,\$(BMLGOALS.PDF)))";
      $makefile .= "\n  BMLGOALS.PDFAUX += \$(AUX_DIR)/pdfaux/" . join(' $(AUX_DIR)/pdfaux/', @xr);
      $makefile .= "\nendif\n";
    }
  }
}

if ($output ne '-') {
  open(my $fh_output, '>', encode('locale_fs', $output, Encode::FB_CROAK | Encode::LEAVE_SRC)) or die "cannot write '$output': $!";
  print $fh_output $makefile;
} else {
  print $makefile;
}
