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
use URI::file;
use XML::LibXML;
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

bookml::open_file(my $fh_style, '<', $stylefile) or Fatal('I/O', 'stylesheet', $stylefile, "cannot open the stylesheet: $!");
binmode($fh_style);
my $style_doc = XML::LibXML->load_xml(IO => $fh_style, URI => URI::file->new(bookml::dirname($stylefile))->as_string) or Fatal('I/O', 'stylesheet', $stylefile, "cannot parse the stylesheet: $!");

my $parser = XML::LibXSLT->new();
my $stylesheet = $parser->parse_stylesheet($style_doc) or Fatal('I/O', 'stylesheet', $stylefile, "invalid stylesheet: $!");

bookml::open_file(my $fh_input, '<', $input) or Fatal('I/O', 'stylesheet', $stylefile, "cannot open stylesheet: $!");
binmode($fh_input);
my $input_doc = XML::LibXML->load_xml(IO => $fh_input, URI => URI::file->new(bookml::dirname($input))->as_string) or Fatal('I/O', 'input', $input, "cannot open or parse the input file: $!");

my $result = $stylesheet->transform($input_doc, %params) or Fatal('I/O', 'input', $input, "cannot transform the input file: $!");

if ($output ne '-') {
  bookml::mk_path(bookml::dirname($output));
  bookml::open_file(my $fh_output, '>', $output) or Fatal('I/O', $output, undef, "cannot write '$output': $!");
  binmode($fh_output);
  $stylesheet->output_fh($result, $fh_output);
} else {
  print $result->toString();
}
