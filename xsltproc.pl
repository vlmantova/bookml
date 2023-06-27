#!/usr/bin/env perl
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
