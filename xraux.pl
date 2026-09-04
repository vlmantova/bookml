#!/usr/bin/env perl

=begin comment

  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021-26 Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

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

# Read the .aux file recursively and pick out the lines that are read by xr.
# Do not overwrite the output if the content has not changed.

use warnings;
use strict;
use File::Spec;
use Getopt::Long;

use lib 'bookml';
use bookml;

my $output;
my @read;

my $force = 0;

GetOptions('output=s' => \$output, 'force' => \$force);

Fatal('expected', 'output', undef, 'you must specify the output file with --output or -o') unless $output;
Fatal('expected', 'input', undef, 'you must specify exactly one input file') unless @ARGV == 1;

sub process_aux {
  my ($aux, $dir) = @_;
  my $aux_path;
  if (!defined $dir) {
    $aux_path = $aux;
    my ($v, $d, $f) = File::Spec->splitpath(File::Spec->canonpath($aux));
    $dir = File::Spec->catpath($v, $d);
    $aux = $f;
  } else {
    $aux_path = File::Spec->catfile($dir, $aux);
  }

  return '' if grep { $_ eq $aux } @read;

  push(@read, $aux);

  my $out = '';
  my @next;

  if (bookml::open_file(my $aux_fh, '<', $aux_path) or Fatal('I/O', $aux, undef, "cannot read '$aux_path': $!")) {
    $out .= "%%% xraux.pl: $aux\n";
    while (<$aux_fh>) {
      if (m/^\s*\\(?:newlabel|bibcite|new\@label\@record)(?:[^a-zA-Z@]|$)/) {
        $out .= "$_";
      } elsif (m/^\s*\\\@input\s*\{?"?([^}]*)"?\}?/) {
        push(@next, $1);
      }
    }

    $out .= join('', map { process_aux($_, $dir) } @next);
  } else {
    Warn('I/O', $aux, undef, "cannot read '$aux_path': $!");
  }

  return $out;
}

my $out = process_aux($ARGV[0]);

if ($output ne '-') {
  if (!$force && bookml::test_f($output)) {
    bookml::open_file(my $fh_output, '<', $output) or Fatal('I/O', $output, undef, "cannot read file: $!");
    my $prev_out = do {
      local $/ = undef;
      <$fh_output>;
    };
    if ($prev_out eq $out) {
      print STDERR "xraux.pl: '$output' has not changed.\n";
      exit 0;
    }
  } else {
    bookml::mk_path(bookml::dirname($output));
  }
  bookml::open_file(my $fh_output, '>', $output) or Fatal('I/O', $output, undef, "cannot write file: $!");
  print $fh_output $out;
} else {
  print $out;
}
