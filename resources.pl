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

package bookml::resources;

use warnings;
use strict;
use Getopt::Long;

use lib 'bookml';
use bookml;

__PACKAGE__->main unless caller;

sub find {
  my ($style, $jobname) = @_;
  return grep { m/(^[^.]*|\.([^.]*,)?(_all|\Q$style\E(-\Q$jobname\E)?)(,[^.]*)?)\.(css|js|ttf|woff|woff2)$/i }
    (bookml::find_files('bookml/CSS'), bookml::find_files('bmluser'));
}

sub main {
  my $style;
  my $jobname;

  GetOptions('style=s' => \$style);

  $jobname = $ARGV[0] or Fatal('expected', 'jobname', undef, 'you must specify a jobname');

  Fatal('expected', 'style', undef, 'you must specify the style with --style') unless $style;

  print(join "\n", find($style, $jobname), '');

  return 1;
}

1;