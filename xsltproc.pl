#!/usr/bin/env perl

=begin comment

  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021-24  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

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

my @files = ();
my %params;
my ($stylefile, $input, $output);

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
    print STDERR 'this minimal script only supports --stringparam, --output, -o';
    die 1;
  } else {
    if (defined $stylefile) {
      $input = $arg;
    } else {
      $stylefile = $arg;
    }
  }
}

die 'must specify an input file' unless defined $input;
die 'must specify a stylesheet' unless defined $stylefile;
die 'must specify an output file' unless defined $output;

my $xslt = XML::LibXSLT->new();
my $stylesheet = $xslt->parse_stylesheet_file($stylefile);
my $result = $stylesheet->transform_file($input, %params);
$stylesheet->output_file($result, $output);
