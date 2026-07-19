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

my $xml     = "$auxdir/xml/$jobname.xml";
my $log     = "$auxdir/latexmlaux/$jobname.latexml.log";
my $xmldeps = "$auxdir/deps/$jobname.xmldeps";

open(my $log_fh, '<', $log) or die "cannot read '$log': $!";

my %inputs = ();

while (<$log_fh>) {
  my $file;
  if (m/^\(Loading (?:RelaxNG schema from |compiled schema )([^()]+\.(?:ltxml|latexml|model|rng))\.\.\./) {
    $file = $1;
  } elsif (m/^\((?:Loading RelaxNG [^()]+|Preparsing Bibliography <Unknown>|Processing (?:content|definitions) (?:Literal String|Anonymous String))\.\.\./) {
    next;
  } elsif (m/^\((?:Processing (?:content|definitions) |Loading |Preparsing Bibliography )([^())]+)\.\.\./) {
    $file = $1;
  } else {
    next;
  }
  $inputs{ normalize_path($file) } = 1;
}

my @inputs = sort(keys %inputs);

my $makefile = "$xml $xmldeps:";

for (@inputs) {
  $makefile .= " \\\n  $_";
}

$makefile .= "\n" if @inputs;

for (@inputs) {
  $makefile .= "\n$_:";
}

$makefile .= "\n";

open(my $fh_xmldeps, '>', $xmldeps) or die "cannot write '$xmldeps': $!";
print $fh_xmldeps $makefile;
