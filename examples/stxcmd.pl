#!/usr/bin/perl

BEGIN {
    unshift @INC, "blib/lib", "blib/arch",
}

use strict;
use XML::STX;

sub _help {
    print "\n'stxcmd.pl' is a command line interface to XML::STX\n\n";
    print "Usage: stxcmd.pl [-m|h|v] stylesheet.stx data.xml\n\n";
    print "-m : measures and displays duration of transformation\n";
    print "-h : displays this help info\n";
    print "-v : displays versions of XML::STX and parser/writer to be used\n\n";
    print "copyright (C) 2002 - 2003 Ginger Alliance (www.gingerall.com)\n";
}

(@ARGV >= 1) || (_help and exit);

my $v; 
my $m; 
my $templ_uri; 
my $data_uri;

if ($ARGV[0] =~ /^-([m|h|v])$/) {

    if ($1 eq 'h') {
	_help and exit;

    } elsif ($1 eq 'v') {
	print "\nXML::STX $XML::STX::VERSION\n";
	$v = 1;

    } else { # $1 eq 'm'

	if (@ARGV >= 3) {
	    $templ_uri = $ARGV[1];
	    $data_uri = $ARGV[2];
	    $m = 1;

	} else {
	    _help and exit;
	}
    }

} else {

    if (@ARGV >= 2) {
	$templ_uri = $ARGV[0];
	$data_uri = $ARGV[1];

    } else {
	_help and exit;
    }
}

my $parser1;
my $parser2;

my $try = "require XML::SAX::Expat;";
eval $try;

if ($@) {
    $try = "require XML::SAX::PurePerl;";
    $@ = undef;
    eval $try;

    if ($@) {
	print "Either XML::SAX::Expat or XML::SAX::PurePerl is required!\n";
	exit;

    } else {
	print "parser: XML::SAX::PurePerl $XML::SAX::PurePerl::VERSION\n" if $v;
	$parser1 = XML::SAX::PurePerl->new();
	$parser2 = XML::SAX::PurePerl->new();
    }

} else {
    print "parser: XML::SAX::Expat $XML::SAX::Expat::VERSION\n" if $v;
    $parser1 = XML::SAX::Expat->new();
    $parser2 = XML::SAX::Expat->new();
}

my $handler;

my $try = "require XML::SAX::Writer;";
$@ = undef;
eval $try;

if ($@) {
    print "XML::SAX::Writer is required!\n";
    exit;

} else {
    print "writer: XML::SAX::Writer $XML::SAX::Writer::VERSION\n" if $v;
    $handler = XML::SAX::Writer->new();    
}

exit if $v;

if ($m) {
    my $try = "require Time::HiRes;";
    $@ = undef;
    eval $try;

    if ($@) {
	print "Time::HiRes is required to measure times!\n";
	exit;
    }
}

my $stx = XML::STX->new();

my $t1 = Time::HiRes::time() if $m;
my $templ = $stx->get_stylesheet($parser1, $templ_uri);
my $t2 = Time::HiRes::time() if $m;
my $rc = $stx->transform($templ, $parser2, $data_uri, $handler);
my $t3 = Time::HiRes::time() if $m;

if ($m) {
    my $t_comp = $t2 - $t1;
    my $t_trans = $t3 - $t2;
    my $t_tot = $t3 - $t1;

    print "\n--------------------------------\n";
    print "Compile  : $t_comp \[s\]\n";
    print "Transform: $t_trans \[s\]\n";
    print "Total    : $t_tot \[s\]\n";
}

exit 0;
