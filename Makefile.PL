use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

#mandatory stuff
my $ok = 1;
my @deps = ('XML::SAX',
	    'XML::NamespaceSupport',
	    'Clone',
	   );

foreach (@deps) {
    my $try = "require $_;";
    eval $try;
    if ($@) {
	print "$_ is missing!\n";
	print "It must be installed before you can install XML::STX.\n";
	$ok = 0;
    } else {
	print "$_ found\n";
    }
}

exit unless $ok;

WriteMakefile(
    'NAME'		=> 'XML::STX',
    'VERSION_FROM'	=> 'STX.pm',
    'PREREQ_PM'		=> {XML::SAX => 0.10, 
			    XML::NamespaceSupport => 1.04,
			    Clone => 0.13},
    dist	        => {COMPRESS => 'gzip', SUFFIX => 'tar.gz'},
);
