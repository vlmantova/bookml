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

package bookml::bmlimages;

use warnings;
use strict;
use Getopt::Long;
use DB_File;
use IPC::Open3;
use XML::LibXSLT;

use lib 'bookml';
use bookml;
require 'xsltproc.pl';

# code to activate bmlimages and add dvisvgm,hypertex as global options
# hypertex ensures hyperref does not emit PDF specials which confuse dvisvgm
my $preclass = '\PassOptionsToPackage{_bmlimages}{bookml/bookml}';       # activate bmlimages
$preclass .= '\makeatletter';
$preclass .= '\let\bml@dcl@ss\documentclass';                            # save \documentclass
$preclass .= '\renewcommand{\documentclass}[1][]{';                      # renew \documentclass[]
$preclass .= '\def\bml@dcl@ss@pts{#1}';                                  # save options
$preclass .= '\let\documentclass\bml@dcl@ss';                            # restore \documentclass
$preclass .= '\ifx\bml@dcl@ss@pts\@empty';                               # no options?
$preclass .= '\def\bml@dcl@ss@{\documentclass[dvisvgm,hypertex]}';       # add dvisvgm,hypertex
$preclass .= '\else';                                                    # with options?
$preclass .= '\def\bml@dcl@ss@{\documentclass[dvisvgm,hypertex,#1]}';    # prepend dvisvgm,hypertex
$preclass .= '\fi\bml@dcl@ss@}';                                         # close definition
$preclass .= '\makeatother';

__PACKAGE__->main unless caller;

sub generate {
  my ($source, $jobname, $imagescale) = @_;

  my $outdir  = "bmlimages/dvi/$jobname";
  my $dvifile = "$outdir/$jobname.dvi";
  my $svgfmt  = 'bmlimages/%f-%0p.svg';
  my $dpth    = "$outdir/$jobname.dpth";
  my $log     = "$outdir/$jobname.bmllog";

  if (!$bookml::IN_LATEXML) {
    bookml::UseLog($log);
  }

  my @lmk_invocation = ('latexmk', '-output-format=dvi',
    '-interaction=nonstopmode',     '-halt-on-error',          '-file-line-error',
    '-output-directory=' . $outdir, '-usepretex=' . $preclass, '-g',
    '-jobname=' . $jobname,         $source);

  if ($^O =~ /^(MSWin|cygwin)/) {
    require Win32::ShellQuote;
    @lmk_invocation = Win32::ShellQuote::quote_system_list(@lmk_invocation); }

  NoteLog('Calling ' . join(' ', @lmk_invocation));
  ProgressStep('Calling ' . join(' ', @lmk_invocation));

  my $lmk_pid = IPC::Open3::open3(undef, my $lmk_stdout, undef,
    @lmk_invocation);

  my $rebuild    = 1;
  my $print_next = 0;
  my @depths     = ();

  # report progress and remember if latexmk did anything
  while (<$lmk_stdout>) {
    chomp;
    NoteLog($_);
    if (!$rebuild || m/^Latexmk: Nothing to do for/) {
      ProgressStep($_); }
    if (m/^Latexmk: Run number .*/) {
      ProgressStep($_); }
    else {
      chomp;
      # copied from texfot.pl v1.47 by Karl Berry (public domain)
      if ($print_next) {
        ProgressStep($_);
        $print_next = 0; }
      # lines that can be ignored
      elsif (/^\ (?:
      LaTeX\ Warning:\ You\ have\ requested\ package
      |LaTeX\ Font\ Warning:\ Some\ font\ shapes
      |LaTeX\ Font\ Warning:\ Size\ substitutions
      |Package\ auxhook\ Warning:\ Cannot\ patch
      |Package\ biditools\ Warning:\ Patching
      |Package\ caption\ Warning:\ Un(?:supported|known)\ document\ class
      |Package\ fixltx2e\ Warning:\ fixltx2e\ is\ not\ required
      |Package\ frenchb?\.ldf\ Warning:\ (?:Figures|The\ definition)
      |Package\ layouts\ Warning:\ Layout\ scale
      |\*\*\*\ Reloading\ Xunicode\ for\ encoding  # spurious ***
      |This\ is\ `?(?:epsf\.tex|.*\.sty|TAP) # so what
      |pdfTeX\ warning:.*inclusion:\ fou   #nd PDF version ...
      |pdfTeX\ warning:.*inclusion:\ mul   #tiple pdfs with page group
      |libpng\ warning:\ iCCP:\ Not\ recognizing
      |!\ $
      )/x) { }
      # error messages followed by an additional line
      elsif (/^\ (?:
      .*?:[0-9]+:         # usual file:lineno: form
      |!                  # usual ! form
      |>\ [^<]            # from \show..., but not "> <img.whatever"
      |.*pdfTeX\ warning  # pdftex complaints often cross lines
      |LaTeX\ Font\ Warning:\ Font\ shape
      |Package\ hyperref\ Warning:\ Token\ not\ allowed
      |removed\ on\ input\ line  # hyperref
      |Runaway\ argument
      )/x) {
        $print_next = 1;
        ProgressStep($_); }
      # remaining errors and diagnostic messages
      elsif (/^\ (?:
      This\ is
      |Output\ written
      |No\ pages\ of\ output
      |\(?:.*end\ occurred\ inside\ a\ group
      # |(?:Und|Ov)erfull                           # bookml does not care about und|overfulls
      |(?:LaTeX|Package|Class).*(?:Error) # |Warning) # bookml can ignore warnings
      |.*Citation.*undefined                      # bookml can ignore warnings
      |.*\ Error           # as in \Url Error ->...
      |Missing\ character: # good to show (need \tracinglostchars=1)
      |\\endL.*problem     # XeTeX?
      |\*\*\*\s            # *** from some packages or subprograms
      |l\.[0-9]+\          # line number marking
      |all\ text\ was\ ignored\ after\ line
      |.*Fatal\ error
      |.*for\ symbol.*on\ input\ line
      |\#\#
      )/x) {
        ProgressStep($_); } }
  }

  close($lmk_stdout);
  waitpid($lmk_pid, 0);
  if ($! || $?) {
    return Error('bookml', 'latexmk', undef, "problem while running latexmk, some images will be missing; read the log for more details\n" .
        ($! ? "Error closing pipe: $!" : 'Exit status ' . ($? >> 8)) .
        "\nInvocation: " . join(' ', @lmk_invocation)); }

  # if the DVI has changed, or the depth cache is invalid, rebuild the images
  # convert DVI to images
  my $dsvg_version = version->parse(split(' ', `dvisvgm --version`));
  return Error('bookml', 'dvisvgm', undef, "version $dsvg_version is too old, please upgrade to v1.6 or above") if $dsvg_version < v1.6;
  my @dsvg_invocation = ('dvisvgm', '--page=1-', '--bbox=preview',
    '--no-fonts', '--exact', ($imagescale && $imagescale != 1 ? '--zoom=' . $imagescale : ()),
    ('--optimize') x ($dsvg_version >= v2.7),
    '--output=' . $svgfmt, $dvifile);
  if ($^O =~ /^(MSWin|cygwin)/) {
    require Win32::ShellQuote;
    @dsvg_invocation = Win32::ShellQuote::quote_system_list(@dsvg_invocation); }

  NoteLog('Calling ' . join(' ', @dsvg_invocation));
  ProgressStep('Calling ' . join(' ', @dsvg_invocation));

  my $dsvg_pid = IPC::Open3::open3(undef, my $dsvg_stdout, undef,
    @dsvg_invocation);

  # report progress
  my $counter;
  while (<$dsvg_stdout>) {
    chomp;
    NoteLog($_);
    if (m/^processing page (\d+)/) {
      $counter = $1;
      ProgressStep("dvisvgm: processing image $counter"); }
    elsif (m/.*=(\d*(?:\.\d+)?)pt,.*=(\d*(?:\.\d+)?)pt,.*=(\d*(?:\.\d+)?)pt/) {
      ProgressStep($_);
      push(@depths, "$counter:$1:$2:$3"); }
    chomp $_;
  }

  close($dsvg_stdout);
  waitpid($dsvg_pid, 0);
  if ($! || $?) {
    return Error('bookml', 'dvisvgm', undef, 'problem while running dvisvgm, some images will be missing or misaligned; read the log for more details' .
        (($! ? "Error closing pipe: $!" : 'Exit status ' . ($? >> 8)) .
          "\nInvocation: " . join(' ', @dsvg_invocation))); }

  foreach my $d (@depths) {
    if ($d =~ m/^(\d+):/) {
      my $svg = "bmlimages/$jobname-$1.svg";
      bookml::xsltproc::proc('bookml/XSLT/proc-svg.xsl', $svg, $svg) or Error('bookml', 'proc-svg', undef, "could not fix the size of $svg"); } }

  return @depths;
}

sub main {
  my $imagescale;
  my $jobname;
  my $source;

  GetOptions('imagescale=s' => \$imagescale, 'jobname=s' => \$jobname);

  Fatal('expected', 'jobname', undef, 'you must specify a jobname with --jobname') unless $jobname;

  $source = $ARGV[0] or Fatal('expected', 'source', undef, 'you must specify a source');

  print join("\n", generate($source, $jobname, $imagescale), '');

  return 1;
}

1;
