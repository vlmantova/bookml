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
# - For PDFS: from .fdb_latexmk, .fls (files read and written), .log (to detect xr)
# - For XML: from .latexml.log (files read)
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

  if ($logname =~ m!^latexmlaux/(.*)\.latexml\.log!) {
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
  } elsif ($logname =~ m!^pdf/(.*)\.(fls|log|fdb_latexmk|xraux)$!) {
    my $jobname    = $1;
    my $targetname = "pdf/$jobname";
    my $ext        = $2;

    $$deps{$targetname} = {} if !$$deps{$targetname};
    my $target_deps = $$deps{$targetname};

    if ($ext eq 'fls') {
      # redundant if we can parse .fdb_latexmk, but include just in case of issues
      while (<$log_fh>) {
        # ignore PWD as we know it is the current working directory, and its encoding may be mangled
        if (m/^\s*INPUT\s+(.*)$/) {
          my $file = logic_path($1);
          # ignore redundant .tex dependency
          next if $file eq "$jobname.tex";
          $$target_deps{INPUT}{$file} = 1;
        } elsif (m/^\s*OUTPUT\s+(.*)$/) {
          my $file = logic_path($1);
          $$target_deps{OUTPUT}{$file} = 1;
        }
      }
    } elsif ($ext eq 'log') {
      my $nextline = 0;

      while (<$log_fh>) {
        my $aux_jobname;
        my $tex;
        my $notfound;

        if (m/^\s*Package xr Info: IMPORTING LABELS FROM (.*)\.aux on input line \d+.\s*$/) {
          $aux_jobname = $1;
        } elsif (m/^\s*Package xr Warning:\s*$/) {
          $nextline = 1;
        } elsif ($nextline) {
          $nextline = 0;
          if (m/^\s*No file (.*)\.aux\s*$/) {
            $aux_jobname = $1;
            $notfound    = 1;
          }
        }

        if ($aux_jobname) {
          # the .tex file should exist, start from there to properly resolve the file name on Windows
          $tex         = logic_path("$aux_jobname.tex");
          $aux_jobname = $tex =~ s!\.tex$!!r;

          $$target_deps{XR}{$aux_jobname} = 1;
          # the 'No file' case is a root .tex file, add it to INPUT in case the file .tex
          # does not exist yet and so it has not made it to .fls
          $$target_deps{INPUT}{$tex} = 1 if $notfound;
        }
      }
    } elsif ($ext eq 'fdb_latexmk') {
      my $header = <$log_fh>;
      my $version;

      if ($header !~ m!^\s*# Fdb version [\d]+\s*!) {
        Fatal('malformed', $logname, undef, 'latexmk file database not of correct format');
      } elsif ($header =~ m!^\s*# Fdb version ([\d]+)\s*!) {
        $version = $1;
        if ($version > 4) {
          Warn('unexpected', $logname, undef, 'unsupported latexmk version, dependencies are likely to be missed');
        }
      }

      # the format of .fdb_latexmk is not documented, see latexmk.pl
      # use state as in latexmk:
      # 1 = source, 2 = generated, 3 = rewritten before read
      my $state = 0;
      while (<$log_fh>) {
        s!^\s*!!;
        s!\s*$!!;

        if (m!^\[!) {
          $state = 1;
        } elsif (m!^\(generated\)!) {
          $state = 2;
        } elsif (m!^\(rewritten before read\)!) {
          $state = 3;
        } elsif (($state == 1) && m!^"([^"]*)".*"[^"]*"$!) {
          my $file = logic_path($1);
          # ignore redundant .tex dependency
          next if $file eq "$jobname.tex";
          $$target_deps{INPUT}{$file} = 1;
        } elsif (($state == 2 || $state == 3) && m!^"([^"]*)"$!) {
          # the distinction between generated and rewritten is
          # irrelevant for make purposes
          my $file = logic_path($1);
          $$target_deps{OUTPUT}{$file} = 1;
        }
      }
    } elsif ($ext eq 'xraux') {
      while (<$log_fh>) {
        if (m/^%%% xraux\.pl: (.*)$/) {
          my $file = logic_path($1);
          $$target_deps{XRINPUT}{$file} = 1;
        }
      }
    }
  } else {
    Fatal('malformed', $logname, undef, 'cannot determine source of log');
  }
}

my $logic_output = logic_path($output);

my $makefile = '';

for my $target (sort keys %$deps) {
  my $target_deps = $$deps{$target};

  if ($target =~ m!^xml/(.*)!) {
    my $jobname  = $1;
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
      my $tex = "$xr.tex";
      if ($$target_deps{INPUT}{$tex}) {
        # not found, or recorded by \set@curr@file in \externaldocument
        # then the dependency shall be on .xraux, not .tex
        # FIX what if .tex is also read for other reasons, e.g. a listing?
        delete $$target_deps{INPUT}{$tex};
      } elsif (File::Spec->file_name_is_absolute($xr)) {
        # not under BookML's $(AUX_DIR)
        delete $$target_deps{XR}{$xr};
      } elsif ($$target_deps{INPUT}{"$auxdir/pdf/$xr.aux"}) {
        # in $(AUX_DIR), but not generated by compiling $xr.tex (necessary
        # check in case \set@curr@file does not create an INPUT entry, like
        # with luatex)
        delete $$target_deps{XR}{$xr} unless bookml::test_f(File::Spec->catfile($physical_auxdir, 'pdf', "$xr.log"));
      } elsif ($$target_deps{INPUT}{"$xr.aux"}) {
        # .aux generated in the current directory instead of $(AUX_DIR),
        # (e.g. from the editor running pdflatex directly)
        # check if generated by compiling $xr.tex
        delete $$target_deps{XR}{$xr} unless bookml::test_f("$xr.log");
        # $xr.aux will be rebuilt in $(AUX_DIR) via .xraux
        delete $$target_deps{INPUT}{"$xr.aux"};
      }
    }

    for my $output (sort keys %{ $$target_deps{OUTPUT} }) {
      delete $$target_deps{INPUT}{$output};
    }

    for my $input (sort keys %{ $$target_deps{INPUT} }) {
      # ignore generated inputs except for the ones with a recipe
      # (i.e. .pdf, for \includegraphics)
      delete $$target_deps{INPUT}{$input} if $input =~ m!^\Q$auxdir\E/pdf/! && $input !~ m!\.pdf$!;
    }

    my @xrjobs   = grep { !File::Spec->file_name_is_absolute($_); } (sort(keys %{ $$target_deps{XR} }));
    my @inputs   = sort(keys %{ $$target_deps{INPUT} });
    my @xrinputs = sort(keys %{ $$target_deps{XRINPUT} });

    if (@inputs || @xrjobs) {
      my @xr = map { "\$(AUX_DIR)/pdf/$_.xraux" } @xrjobs;

      $makefile .= "$fullname.pdf: \\\n  ";
      $makefile .= join(" \\\n  ", @inputs, @xr) . "\n\n";
      $makefile .= join(":\n",     @inputs, @xr) . ":\n";
    }

    if (@xrjobs ||
      (my @pdf = grep { m!.pdf$! && !File::Spec->file_name_is_absolute($_); } (sort(keys %{ $$target_deps{INPUT} })))) {
      # report dependency, and exclude self dependencies for good measure
      $makefile .= "\nbml.deps.xraux += " . join(' ', map { $_ ne $jobname ? "$jobname:$_" : () } @xrjobs) . "\n" if @xrjobs;
    }

    if (@xrinputs) {
      my ($v, $d, $f) = File::Spec->splitpath($target);
      my $dir = "\$(AUX_DIR)/" . File::Spec->catpath($v, $d);
      # force rebuild the PDF if any of .aux, .bbl, etc files that would be
      # read by xr have gone missing
      $makefile .= "\nifeq (\$(and " . join(',', map { "\$(wildcard $dir$_)" } @xrinputs) . "),)\n";
      $makefile .= "$fullname.pdf: FORCE\n";
      $makefile .= "endif\n";
    }
  }
}

if ($output ne '-') {
  bookml::mk_path(bookml::dirname($output));
  bookml::open_file(my $fh_output, '>', $output) or Fatal('I/O', $output, undef, "cannot write '$output': $!");
  print $fh_output $makefile;
} else {
  print $makefile;
}
