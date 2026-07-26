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

# Read the .aux file recursively and pick out the lines that are read by xr.
# Do not overwrite the output if the content has not changed.

use warnings;
use strict;
use File::Spec;
use Getopt::Long;

use lib 'bookml';
use bookml;

my $output;

GetOptions('output=s' => \$output);

Fatal('expected', 'output', undef, 'you must specify the output file with --output or -o') unless $output;
Fatal('expected', 'input', undef, 'you must specify exactly one input file') unless @ARGV == 1;

sub process_aux {
  my ($aux, $dir) = @_;
  if (!defined $dir) {
    my ($v, $d, $f) = File::Spec->splitpath($aux);
    $dir = File::Spec->catpath($v, $d);
  }

  my $out = "";
  my @next;

  bookml::open_file(my $aux_fh, '<', $aux) or Fatal('I/O', $aux, undef, "cannot read '$aux': $!");

  while (<$aux_fh>) {
    if (m/^\s*\\(?:newlabel|bibcite|new\@label\@record)(?:[^a-zA-Z@]|$)/) {
      $out .= "$_";
    } elsif (m/^\s*\\\@input\s*\{?"?([^}]*)"?\}?/) {
      push(@next, $1);
    }
  }
  for (@next) {
    $out .= process_aux(File::Spec->catfile($dir, $_), $dir);
  }
  return $out;
}

my $out = process_aux($ARGV[0]);

if ($output ne '-') {
  if (bookml::test_f($output)) {
    bookml::open_file(my $fh_output, '<', $output) or Fatal('I/O', $output, undef, "cannot read file: $!");
    my $prev_out = do {
      local $/ = undef;
      <$fh_output>;
    };
    if ($prev_out eq $out) {
      print STDERR "xraux.pl: '$output' has not changed.\n";
      exit 0;
    }
  }
  bookml::open_file(my $fh_output, '>', $output) or Fatal('I/O', $output, undef, "cannot write file: $!");
  print $fh_output $out;
} else {
  print $out;
}
