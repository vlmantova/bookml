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

use File::Find;
use JSON::XS;
use XML::LibXML;
use XML::LibXSLT;

my @files;
my @index;

die 'must specify a folder' unless scalar @ARGV == 1;

File::Find::find({
    preprocess => sub { sort @_; },
    wanted     => sub {
      push(@files, $_) if (-f $_ && m/\.html$/i);
    }
  },
  $ARGV[0]);

my $parser = XML::LibXML->new({ suppress_errors => 1, suppress_warnings => 1, recover => 2 });
my $xslt = XML::LibXSLT->new();
my $stylesheet = $xslt->parse_stylesheet_file('bookml/XSLT/proc-text.xsl');

chdir $ARGV[0];

for my $file (@files) {
  my $doc = $parser->load_html(location => $file);
  my $title = $doc->findnodes('//title/text()');
  my @urls = reverse (map { $_->string_value } $doc->findnodes('//link[contains("up up up up up up up up up",@rel)]/@href'));
  push(@urls, $file);
  my $result = $stylesheet->transform($doc);
  push(@index, [\@urls, $title->string_value, $stylesheet->output_as_chars($result)]);
}

open(my $fh, '>', 'search_index.json') or die "cannot write search_index.json: $!";
print $fh encode_json(\@index);
