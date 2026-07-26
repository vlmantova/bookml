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

# Extract the make dependencies.
# - For PDFS: from .fls (files read), .logdeps (to detect xr)
# - For XML: from .latexml.logdeps (files read)
# - For HTML: from .xml (resources required)

use warnings;
use strict;
use File::Spec;
use Getopt::Long;

use lib 'bookml';
use bookml;

my @logs = ();
my ($output, $physical_auxdir);
my $raw_cwd = bookml::get_raw_cwd;
my $cwd     = bookml::get_cwd;
my $auxdir  = '$(AUX_DIR)';

sub normalize_path {
  my ($file) = @_;

  $file = bookml::get_long_path_name($file);
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
  $file =~ s!^\Q$physical_auxdir\E/!$auxdir/!;

  return $file;
}

# LaTeXML 0.8.8 does not decode Cwd::getcwd
sub fix_latexml_cwd_encoding {
  my ($file) = @_;
  return $file =~ s!^\Q$raw_cwd\E/!$cwd/!r;
}

GetOptions('output=s' => \$output,
  'auxdir=s' => \$physical_auxdir);

Fatal('expected', 'aux-dir', undef, 'you must specify the aux directory with --auxdir or -a') unless $physical_auxdir;
Fatal('expected', 'output', undef, 'you must specify the output file with --output or -o') unless $output;

$physical_auxdir = normalize_path($physical_auxdir);

my $deps = {};

for my $log (@ARGV) {
  bookml::open_file(my $log_fh, '<', $log) or Fatal('I/O', $log, undef, "cannot read '$log': $!");
  my $logname = logic_path($log) =~ s!^\Q$auxdir\E/!!r;

  if ($logname =~ m!^latexmlaux/(.*)\.latexml\.logdeps!) {
    my $jobname    = $1;
    my $targetname = "xml/$jobname";

    $$deps{$targetname} = {} if !$$deps{$targetname};
    my $target_deps = $$deps{$targetname};

    while (<$log_fh>) {
      my $file;

      if (m/^\(Loading (?:RelaxNG schema from |compiled schema )([^()]+\.(?:model|rng))\.\.\./) {
        $file = $1;
      } elsif (m/^\((?:Loading RelaxNG [^()]+|Preparsing Bibliography <Unknown>|Processing (?:content|definitions) (?:Literal String|Anonymous String))\.\.\./) {
        next;
      } elsif (m/^\((?:Processing (?:content|definitions) |Loading |Preparsing Bibliography )([^())]+)\.\.\./) {
        $file = $1;
      } else {
        next;
      }

      $file = fix_latexml_cwd_encoding($file);
      $file = normalize_path($file);

      # ignore redundant .tex dependency
      next if $file eq "$jobname.tex";
      $$target_deps{$file} = 1;
    }
  } elsif ($logname =~ m!^pdf/(.*)\.(fls|logdeps)$!) {
    my $jobname    = $1;
    my $targetname = "pdf/$jobname";
    my $ext        = $2;

    $$deps{$targetname} = {} if !$$deps{$targetname};
    my $target_deps = $$deps{$targetname};

    if ($ext eq 'fls') {
      while (<$log_fh>) {
        # ignore PWD as we know it is the current working directory, and its encoding may be mangled
        # we do not care about OUTPUT
        if (m/^\s*INPUT\s+(.*)$/) {
          my $file = logic_path($1);
          # skip files generated within $(AUX_DIR)
          next if $file =~ m!^\Q$auxdir\E/pdf/!;
          # ignore redundant .tex dependency
          next if $file eq "$jobname.tex";
          $$target_deps{INPUT}{$file} = 1;
        }
      }
    } else {
      my $nextline = 0;

      while (<$log_fh>) {
        my $aux_jobname;
        my $tex;

        if (m/^\s*Package xr Info: IMPORTING LABELS FROM (.*\.aux) on input line \d+.\s*$/) {
          $aux_jobname = logic_path("$1") =~ s!\.aux$!!r;
        } elsif (m/^\s*Package xr Warning:\s*$/) {
          $nextline = 1;
        } elsif ($nextline) {
          $nextline = 0;
          if (m/^\s*No file (.*)\.aux\s*$/) {
            # the .tex file should exist, start from there to properly resolve the file name on Windows
            $tex         = logic_path("$1.tex");
            $aux_jobname = $tex =~ s!\.tex$!!r;
          }
        }

        if ($aux_jobname) {
          $$target_deps{XR}{$aux_jobname} = 1;
      # the 'No file' case is a root .tex file, add it to INPUT in case the .tex file itself needs to be built
          $$target_deps{INPUT}{$tex} = 1 if $tex;
        }
      }
    }
  } else {
    Fatal('malformed', $logname, undef, 'cannot determine source of log');
  }
}

my $makefile = '';

for my $target (sort keys %$deps) {
  my $target_deps = $$deps{$target};

  if ($target =~ m!^xml/(.*)!) {
    my $fullname = "\$(AUX_DIR)/$target";

    if (my @inputs = sort(keys %$target_deps)) {
      $makefile .= "$fullname.xml: \\\n  ";
      $makefile .= join(" \\\n  ", @inputs) . "\n\n";
      $makefile .= join(":\n",     @inputs) . ":\n";
    }
  } elsif ($target =~ m!^pdf/(.*)$!) {
    my $jobname  = $1;
    my $fullname = "\$(AUX_DIR)/$target";

    for my $xr (sort keys %{ $$target_deps{XR} }) {
      # we only care about root .aux files, not subfiles generated by \include, \bibliography, etc
      # luckily, \externaldocument calls \set@curr@file, so we can spot root .aux from the .log
      my $tex = "$xr.tex";
      if ($$target_deps{INPUT}{$tex}) {
        # ignore redundant .tex dependency
        delete $$target_deps{INPUT}{$tex};
      } else {
        delete $$target_deps{XR}{$xr};
      }
    }

    my @xrjobs = grep { !File::Spec->file_name_is_absolute($_); } (sort(keys %{ $$target_deps{XR} }));
    my @inputs = sort(keys %{ $$target_deps{INPUT} });

    if (@inputs || @xrjobs) {
      # BIG TODO: reduce all dependencies to .pdf so that dependencies are represented by single nodes
      # anything else creates a mess when Make breaks the cycles
      my @xr = map { "\$(AUX_DIR)/pdf/$_.xraux" } @xrjobs;

      $makefile .= "$fullname.pdf $fullname.aux $fullname.fls $fullname.logdeps $fullname.start-stamp: \\\n  ";
      $makefile .= join(" \\\n  ", @inputs, @xr) . "\n\n";
      $makefile .= join(":\n", @inputs, @xr) . ":\n";

      if (@xrjobs ||
        (my @pdf = grep { m!.pdf$! && !File::Spec->file_name_is_absolute($_); } (sort(keys %{ $$target_deps{INPUT} })))) {
        $makefile .= "\nifneq (\$(filter $jobname,\$(bml.jobs.pdf)),)\n";
        $makefile .= '  -include $(sort $(filter-out $(call bml.deps.detect,pdf),$(patsubst %,$(AUX_DIR)/deps/%.pdfdeps,' . join(' ', @xrjobs) . ")))\n" if @xrjobs;
        $makefile .= '  bml.jobs.pdf += ' . join(' ', @pdf, @xrjobs) . "\n" if @pdf || @xrjobs;
        # for good measure, avoid self dependencies
        $makefile .= '  bml.xraux    += ' . join(' ', map { $_ ne $jobname ? "$jobname:$_" : () } @xrjobs) . "\n" if @xrjobs;
        $makefile .= "endif\n";
      }
    }
  }
}

if ($output ne '-') {
  bookml::open_file(my $fh_output, '>', $output) or Fatal('I/O', $output, undef, "cannot write '$output': $!");
  print $fh_output $makefile;
} else {
  print $makefile;
}
