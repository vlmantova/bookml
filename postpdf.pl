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
use Encode qw(decode_utf8);
use File::Spec;

BEGIN {
  require Win32 if $^O eq 'MSWin32';
}

my $auxdir  = $ARGV[0];
my $jobname = $ARGV[1];

die 'you must specify exactly one directory and a jobname' if !$auxdir || @ARGV != 2;

# ignore PWD from .fls as it may be garbled, we know it is the current directory
my $cwd = $^O eq 'MSWin32' ? Win32::GetLongPathName(Win32::GetCwd()) : decode_utf8(Cwd::getcwd);

sub normalize_path {
  my ($file) = @_;
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

$auxdir = normalize_path($auxdir);

my $pdf     = "$auxdir/pdf/$jobname.pdf";
my $aux     = "$auxdir/pdf/$jobname.aux";
my $auxnoxr = "$auxdir/pdfnoxr/$jobname.aux";
my $fls     = "$auxdir/pdf/$jobname.fls";
my $log     = "$auxdir/pdf/$jobname.logdeps";
my $pdfdeps = "$auxdir/deps/$jobname.pdfdeps";

open(my $fls_fh, '<', $fls) or die "cannot read '$fls': $!";
open(my $log_fh, '<', $log) or die "cannot read '$log': $!";

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

if (my @outputs = sort(keys %outputs)) {
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

  $makefile .= "\n\n$pdf $aux $fls $log:";

  for (@inputs) {
    $makefile .= " \\\n  $_" if m!^$auxdir/!;
  }

  if (%xrinputs) {
    $makefile .= "\n\nifneq (,\$(filter $pdf,\$(BMLGOALS.PDF)))\n";
    $makefile .= 'BMLGOALS.PDF += ';
    $makefile .= join(' ', map { s!^$auxdir/pdfnoxr/(.*)\.aux$!$auxdir/pdf/$1.pdf!r } (grep { m!^$auxdir/pdfnoxr/! } @xrinputs));
    $makefile .= "\nendif\n";
  }

  for (@inputs) {
    $makefile .= "\n$_:";
  }

  $makefile .= "\n";
}

open(my $fh_pdfdeps, '>', $pdfdeps) or die "cannot write '$pdfdeps': $!";
print $fh_pdfdeps $makefile;
