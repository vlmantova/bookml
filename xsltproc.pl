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
use bookml qw(encode_fs);

my ($stylefile, $input, $output);
my @params;

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
  '--stringparam=s{2}' => @params);

my %params = @params;

($stylefile, $input) = @ARGV;

Error('Fatal', 'expected', 'input',      'must specify an input file')  unless defined $input;
Error('Fatal', 'expected', 'stylesheet', 'must specify a stylesheet')   unless defined $stylefile;
Error('Fatal', 'expected', 'output',     'must specify an output file') unless defined $output;

my $raw_input     = encode_fs($input);
my $raw_stylefile = encode_fs($stylefile);
my $raw_output    = encode_fs($output);

my $xslt = XML::LibXSLT->new();
my $stylesheet = $xslt->parse_stylesheet_file($raw_stylefile) or Fatal('I/O', 'stylesheet', $stylefile, "cannot open stylesheet '$stylefile'");
my $result = $stylesheet->transform_file($raw_input, %params) or Fatal('I/O', 'input', $input, "cannot open or parse input file '$input'");
$stylesheet->output_file($result, $raw_output);
