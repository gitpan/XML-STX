# XML-STX test suite
BEGIN { 
    $| = 1;
    unshift @INC, 
      "blib/lib", "blib/arch", "test";
}

use strict;
use XML::STX;
use TestHandler;

print '-' x 42, "\n";
print "loaded\n";

my $total = 0;
my $passed = 0;
my @failed = ();

open(INDEX,'test/_index');

while (<INDEX>) {

    next if $_ =~ /^#/ or $_ =~ /^\s*$/;

    chomp;
    $total++;
    my @ln = split('\|', $_, 4);

    my $templ_uri = "test/$ln[0].stx";
    my $data_uri = "test/_data$ln[1].xml";

    my $stx = XML::STX->new();

    my $transformer = $stx->new_transformer($templ_uri);

    # external parameters
    unless ($ln[2] =~ /^\d+$/) {
	foreach (split(' ', $ln[2])) {
	    my ($name, $value) = split('=',$_,2);
	    $transformer->{Parameters}->{$name} = $value;
	}
    }

    my $source = $stx->new_source($data_uri);
    my $handler = TestHandler->new();
    my $result = $stx->new_result($handler);

    $transformer->transform($source, $result);

    $handler->{result} =~ s/\s//g;
    $ln[3] =~ s/\s//g;

    #print "->$handler->{result}\n";
    #print "->$ln[3]\n";

    my $dots = 40 - length($ln[0]);

    if ($handler->{result} eq $ln[3]) {
	print "$ln[0]", '.' x $dots, "OK\n";
	$passed++;

    } else {
	print "$ln[0]", '.' x $dots, "FAILED!\n";
	push @failed, $ln[0];
    }
}

close INDEX;
print '-' x 42, "\n";

if ($passed == $total) {
    print "All tests passed successfully: $passed/$total\n";

} else {
    print "There were problems: $passed/$total\n";
    print '(', join(', ', @failed), ")\n";
}

print '-' x 42, "\n";
