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

use warnings;
use strict;

package bookml;
use Exporter 'import';

use Cwd;
use Encode qw(decode decode_utf8 encode);
use Encode::Locale;
use File::Spec;
use Term::ANSIColor qw(colored);

our @EXPORT = qw(Message Info Warn Error Fatal Note NoteLog NoteSTDERR ProgressStep IN_LATEXML);

our $IN_LATEXML;
our $LOG;

my $IS_TERMINAL;

BEGIN {
  # portable platform-dependent I/O functions to handle path name encoding
  require Encode;

  $IS_TERMINAL = -t STDERR;

  sub get_raw_cwd {
    return Cwd::getcwd;
  }

  if ($^O eq 'MSWin32') {
    require Win32;
    require Win32::Console;

    *decode_fs = sub {
      my ($path) = @_;
      return Win32::GetLongPathName($path) // $path;
    };

    *encode_fs = sub {
      my ($path) = @_;
      return Win32::GetANSIPathName($path) // $path;
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
  }

  if ($^O eq 'MSWin32' && eval { require Win32::LongPath; }) {
    *get_long_path_name = sub {
      my ($path) = @_;
      return Win32::LongPath::abspathL($path);
    };

    *get_cwd = \&Win32::LongPath::getcwdL;

    *open_file = sub {
      my ($fh, $mode, $path) = @_;
      mk_path(dirname($path)) if $mode =~ m/>|\+/;
      return \&Win32::LongPath::openL(\$_[0], $_[1], $_[2]);
    };

    *open_dir = sub {
      my $dir = Win32::LongPath->new();
      $dir->opendirL($_[0]);
      return $dir;
    };

    *read_dir = sub {
      return $_[0]->readdirL;
    };

    *close_dir = sub {
      return $_[0]->closedirL;
    };

    *ch_dir = \&Win32::LongPath::chdirL;

    *mk_dir = \&Win32::LongPath::mkdirL;

    *test_d = sub {
      my ($path) = @_;
      return Win32::LongPath::testL('d', $path);
    };

    *test_f = sub {
      my ($path) = @_;
      return Win32::LongPath::testL('f', $path);
    };
  } else {
    *get_cwd = sub {
      return decode_fs(get_raw_cwd);
    };

    *open_dir = sub {
      my ($path) = @_;
      my $ret = opendir(my $dh, encode_fs($path));
      return $dh if $ret;
    };

    *read_dir = sub {
      my $dh = $_[0];
      if (wantarray()) {
        return map { decode_fs($_) } readdir($dh);
      } else {
        my $ret = readdir($dh);
        return decode_fs($ret) if defined $ret;
      }
    };

    *close_dir = sub {
      return $_[0]->closedirL;
    };

    *ch_dir = sub {
      my ($path) = @_;
      return chdir(encode_fs($path));
    };

    *test_d = sub {
      my ($path) = @_;
      return -d encode_fs($path);
    };

    *test_f = sub {
      my ($path) = @_;
      return -f encode_fs($path);
    };

    if ($^O eq 'MSWin32') {
      *get_long_path_name = sub {
        my ($path) = @_;
        return Win32::GetLongPathName($path) // $path;
      };

      *mk_dir = \&Win32::CreateDirectory;

      *open_file = sub {
        my ($fh, $mode, $path) = @_;
        mk_path(dirname($path))                                                     if $mode =~ m/>|\+/;
        Win32::CreateFile($path) or Fatal('I/O', $path, "cannot write to file: $!") if $mode =~ m/>|\+/;
        return open($_[0], $_[1], encode_fs($_[2]));
      };
    } else {
      *mk_dir = sub {
        my ($path) = @_;
        return mkdir(encode_fs($path));
      };

      *open_file = sub {
        my ($fh, $mode, $path) = @_;
        mk_path(dirname($path)) if $mode =~ m/>|\+/;
        return open($_[0], $_[1], encode_fs($_[2]));
      };
    }
  }

  if (!eval { require LaTeXML::Common::Error; 1; }) {
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

    *Info = sub {
      return Message('Info', @_);
    };

    *Warn = sub {
      return Message('Warning', @_);
    };

    *Error = sub {
      return Message('Error', @_);
    };

    *Fatal = sub {
      my ($category, $object, $where, $summary) = @_;
      return Message('Fatal', @_);
    };

    *Note = sub {
      my ($message) = @_;
      NoteSTDERR($message);
      NoteLog($message);
    };

    *NoteLog = sub {
      my ($message) = @_;
      print $LOG "$message\n" if $LOG;
    };

    *NoteSTDERR = sub {
      my ($message) = @_;
      print STDERR "$message\n";
    };

    *UseLog = sub {
      my ($path) = @_;
      open_file($LOG, '>', $path) or Error('I/O', "$path", "cannot open log file for writing: $!");
    };

    *ProgressStep = \&NoteSTDERR;
  } else {
    if ($LaTeXML::Common::Error::USE_STDERR) {
      LaTeXML::Common::Error->import;
      $IN_LATEXML = 1;
    } else {
      LaTeXML::Common::Error->import(qw(:DEFAULT !ProgressStep));
      UseSTDERR();
      *ProgressStep = \&NoteSTDERR;
    }
  }
}

Encode::Locale::decode_argv(Encode::FB_CROAK);

use open ':std', ':encoding(UTF-8)';
binmode(STDERR, ':encoding(UTF-8)');
binmode(STDOUT, ':encoding(UTF-8)');
*STDERR->autoflush();

# Pretty print messages like LaTeXML (adapted from LaTeXML::Common::Error)
sub dirname {
  my ($path) = @_;
  my ($v, $d, $f) = File::Spec->splitpath(File::Spec->canonpath($path));
  return File::Spec->catpath($v, $d);
}

sub mk_path {
  my ($path) = @_;

  return unless $path;

  my $parent = dirname($path);

  if ($parent && $path ne $parent) {
    mk_path($parent);
  }

  if (!test_d($path)) {
    mk_dir($path) or Fatal('I/O', $path, undef, "cannot create directory: $!");
  }

  return;
}

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

sub find_files {
  my ($path) = @_;

  if (bookml::test_d($path)) {
    my $dir = bookml::open_dir($path);
    my @files = map { File::Spec->catfile($path, $_) } (sort File::Spec->no_upwards(bookml::read_dir($dir)));
    return map { find_files($_) } @files;
  } elsif (bookml::test_f($path)) {
    return $path;
  } else {
    return ();
  }
}

1;
