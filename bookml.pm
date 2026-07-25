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

package bookml;
use Exporter 'import';

use Cwd;
use Encode qw(decode decode_utf8 encode);
use Encode::Locale;
use File::Spec;
use Term::ANSIColor qw(colored);

our @EXPORT    = qw(Message Warning Error Fatal);
our @EXPORT_OK = qw(encode_fs);

BEGIN {
  # portable platform-dependent I/O functions to handle path name encoding
  require Encode;

  sub get_raw_cwd {
    return Cwd::getcwd;
  }

  if ($^O eq 'Win32') {
    require Win32;
    require Win32::Console;

    *get_long_path_name = sub {
      my ($path) = @_;
      return Win32::GetLongPathName($path) // $path;
    };

    if (eval { require Win32::LongPath; }) {
      *decode_fs = sub {
        my ($path) = @_;
        return $path;
      };

      *encode_fs = sub {
        my ($path) = @_;
        return $path;
      };

      *get_cwd = sub {
        return &Win32::LongPath::getcwdL;
      };

      *open_file = sub {
        return Win32::LongPath::openL($_[0], $_[1], $_[2]);
      };

      *test_f = sub {
        my ($path) = @_;
        return Win32::LongPath::testL('f', $path); 
      };
    } else {
      *decode_fs = \&Win32::GetLongPathName;

      *encode_fs = \&Win32::GetANSIPathName;

      *get_cwd = sub {
        return decode_fs(get_raw_cwd);
      };

      *open_file = sub {
        my ($fh, $mode, $path) = @_;
        Win32::CreateFile($path) or Fatal('I/O', $path, "cannot write to '$path': $!") if $mode =~ m/>|\+/;
        return open($_[0], $_[1], encode_fs($path));
      };

      *test_f = sub {
        my ($path) = @_;
        return -f encode_fs($path); 
      };
    }
  } else {
    *get_long_path_name = sub {
      my ($path) = @_;
      return $path;
    };

    *decode_fs = sub {
      my ($path) = @_;
      return Encode::decode('locale_fs', $path, Encode::FB_CROAK | Encode::LEAVE_SRC);
    };

    *encode_fs = sub {
      my ($path) = @_;
      return Encode::encode('locale_fs', $path, Encode::FB_CROAK | Encode::LEAVE_SRC);
    };

    *get_cwd = sub {
      return decode_fs(get_raw_cwd);
    };

    *open_file = sub {
      return open($_[0], $_[1], encode_fs($_[2]));
    };

    *test_f = sub {
      my ($path) = @_;
      return -f encode_fs($path); 
    };
  }
}

Encode::Locale::decode_argv(Encode::FB_CROAK);

use open ':std', ':encoding(UTF-8)';
binmode(STDERR, ':encoding(UTF-8)');
binmode(STDOUT, ':encoding(UTF-8)');
*STDERR->autoflush();

# Pretty print messages like LaTeXML (adapted from LaTeXML::Common::Error)
my $IS_TERMINAL = -t STDERR;

if ($IS_TERMINAL && $^O eq 'MSWin32') {
  # set utf-8 codepage
  # CP_UTF8 = 65001
  Win32::Console::OutputCP(65001);

  # get standard error console
  our $W32_STDERR = Win32::Console->new(&Win32::Console::STD_ERROR_HANDLE());

  # CHECK what does libxslt do after we changed codepage?
  Encode::Locale::reinit;

  # enable VT100 emulation or fall back to ANSI emulation if unsuccessful
  # ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004 (not exported by Win32::Console)
  my $mode = $W32_STDERR->Mode();
  unless ($W32_STDERR->Mode($mode | 0x0004) && $W32_STDERR->Mode() & 0x0004) {
    require Win32::Console::ANSI; } }

my %color_scheme = (
  details => 'bold',
  success => 'green',
  info    => 'bright_blue',
  warning => 'yellow',
  error   => 'bold red',
  fatal   => 'bold red underline',
);

sub Message {
  my ($severity, $category, $object, $where, $summary) = @_;
  my $prefix = "$severity:$category:$object";
  print STDERR ($IS_TERMINAL ? colored($prefix, $color_scheme{ lc($severity) }) : $prefix) . " $summary\n";
  exit 1 if $severity eq 'Fatal';
  return;
}

sub Warn {
  return Message('Warning', @_);
}

sub Error {
  return Message('Error', @_);
}

sub Fatal {
  my ($category, $object, $where, $summary) = @_;
  return Message('Fatal', @_);
}
