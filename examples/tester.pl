#!/usr/bin/perl

BEGIN {
    unshift @INC, "blib/lib", "blib/arch", "test";
}

use strict;
use XML::STX;
use XML::SAX::PurePerl;
use TestHandler;

(@ARGV == 2 ) || die ("Usage: tester.pl stylesheet.stx data.xml\n\n");

my $templ_uri = shift;
my $data_uri = shift;

my $parser_t = XML::SAX::PurePerl->new();
my $parser = XML::SAX::PurePerl->new();

my $handler = TestHandler->new();
my $stx = XML::STX->new();

my $templ = $stx->get_stylesheet($parser_t, $templ_uri);
$stx->transform($templ, $parser, $data_uri, $handler);

print "$handler->{result}\n";

exit 0;
