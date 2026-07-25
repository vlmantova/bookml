#!/usr/bin/env perl

=begin comment

  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021-25  Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

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

# List the files in a given directory into a simple XML file.

use warnings;
use strict;
use XML::LibXML;
use File::Find qw(find);
use File::Spec;
use URI::file;

use lib 'bookml';
use bookml;

my $directory = $ARGV[0];
my $manifest  = $ARGV[1];

if (!$directory || !bookml::test_d($directory) || @ARGV != 2) {
  die 'you must specify exactly one directory and one manifest file';
}

my $doc  = XML::LibXML::Document->new('1.0', 'utf-8');
my $root = $doc->createElement('manifest');
$doc->setDocumentElement($root);

{
  my $tag = $doc->createElement('file');
  $tag->appendTextNode('index.html');
  $root->appendChild($tag);
}

find({
    no_chdir   => 1,
    preprocess => sub { sort @_; },
    wanted     => sub {
      $_ = bookml::decode_fs($_);
      my $path = File::Spec->abs2rel($_, $directory);
      return if bookml::test_d($path) || $path =~ m/^(\.|index\.html)$/;
      my $tag = $doc->createElement('file');
      $tag->appendTextNode(URI::file->new($path));
      $root->appendChild($tag);
    } }, $directory);

bookml::open_file(my $fh, '>', $manifest) or die "cannot write '$manifest': $!";
$doc->toFH($fh, 1);
