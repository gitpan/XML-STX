# A fallback SAX writer 

package XML::STX::Writer;
$VERSION = '0.01';

sub new {
    my $class = shift;
    return bless {}, $class;
}

# content --------------------------------------------------

sub start_document {
    my ($self, $document) = @_;
    print '<?xml version="1.0"?>';
}

sub end_document {
    my ($self, $document) = @_;
}

sub start_element {
    my ($self, $element) = @_;
    
    my $out= "<$element->{Name}";

    foreach (keys %{$element->{Attributes}}) {
	$out .= " $element->{Attributes}->{$_}->{Name}=\"$element->{Attributes}->{$_}->{Value}\"";
    }

    print "$out>";
}

sub end_element {
    my ($self, $element) = @_;
    
    print "</$element->{Name}>";
}

sub characters {
    my ($self, $characters) = @_;
    
    print $characters->{Data};
}

sub processing_instruction {
    my ($self, $pi) = @_;

    print "<?$pi->{Target} $pi->{Data}?>";
}

# lexical --------------------------------------------------

sub start_cdata {
    my $self = shift;

    print '<![CDATA[';
}

sub end_cdata {
    my $self = shift;

    print ']]>';
}

sub comment {
    my ($self, $comment) = @_;

    print "<!-- $comment->{Data} -->";
}

sub start_dtd {
    my ($self, $options) = @_;
}

sub end_dtd {
    my ($self, $options) = @_;
}

# error --------------------------------------------------

sub warning {
    my ($self, $exception) = @_;
    
    print "Warning: $exception->{Message}\n";
}

sub error {
    my ($self, $exception) = @_;
    
    print "Error: $exception->{Message}\n";
}

sub fatal_error {
    my ($self, $exception) = @_;
    
    print "Fatal Error: $exception->{Message}\n";
}

1;
