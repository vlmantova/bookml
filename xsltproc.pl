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

# Minimal implementation of xsltproc based on XML::LibXSLT

use warnings;
use strict;

use Encode qw(decode);
use Encode::Locale;
use Getopt::Long;
use XML::LibXSLT;

use lib 'bookml';
use bookml;

my ($stylefile, $input, $output);
my @stringparams;

local $SIG{__WARN__} = sub {
  my ($msg) = @_;
  my ($severity, $category, $object, $summary) = $msg =~ m/^([^: ]*):([^: ]*):([^ ]*) ?(.*)$/;
  $severity = $severity // 'Error';
  $object   = $object   // 'unknown';
  $category = $category // 'internal';
  $summary  = $summary  // $msg;
  Message($severity, $category, $object, $input, decode('console_out', $summary));
};

local $SIG{__DIE__} = sub {
  my ($msg) = @_;
  Fatal('error', 'xsltproc.pl', undef, decode('console_out', $msg));
};

GetOptions('--output=s' => \$output,
  '--stringparam=s@{2}' => \@stringparams);

my %params = @stringparams;

for (keys %params) {
  $params{$_} = "'$params{$_}'";
}

($stylefile, $input) = @ARGV;

Fatal('expected', 'input',      undef, 'you must specify an input file')  unless defined $input;
Fatal('expected', 'stylesheet', undef, 'you must specify a stylesheet')   unless defined $stylefile;
Fatal('expected', 'output',     undef, 'you must specify an output file') unless defined $output;

my $raw_input     = bookml::encode_fs($input);
my $raw_stylefile = bookml::encode_fs($stylefile);
my $raw_output    = bookml::encode_fs($output);

my $xslt = XML::LibXSLT->new();
my $stylesheet = $xslt->parse_stylesheet_file($raw_stylefile) or Fatal('I/O', 'stylesheet', $stylefile, "cannot open stylesheet: $!");
my $result = $stylesheet->transform_file($raw_input, %params) or Fatal('I/O', 'input', $input, "cannot open or parse input file: $!");
$stylesheet->output_file($result, $raw_output);
