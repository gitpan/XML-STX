# An example of simple SAX handler

package TestHandler;

sub new {
    my $type = shift;
    return bless {result => ''}, $type;
}

# content --------------------------------------------------

sub start_document {
    my ($self, $document) = @_;
}

sub end_document {
    my ($self, $document) = @_;

    return $self->{result};
}

sub start_element {
    my ($self, $element) = @_;
    
    $self->{result} .= "<$element->{Name} ";
    foreach (keys %{$element->{Attributes}}) {
	$self->{result} .= "$element->{Attributes}->{$_}->{Name}=\"$element->{Attributes}->{$_}->{Value}\" ";
    }
    $self->{result} .= ">";
}

sub end_element {
    my ($self, $element) = @_;
    
    $self->{result} .= "</$element->{Name}>";
}

sub characters {
    my ($self, $characters) = @_;
    
    $characters->{Data} =~ s/\n//g;
    $characters->{Data} =~ s/\s{2,}/ /g;
    $self->{result} .= "$characters->{Data}";
}

sub processing_instruction {
    my ($self, $pi) = @_;

    $self->{result} .= "<?$pi->{Target} $pi->{Data}?>";
}

# lexical --------------------------------------------------

sub start_cdata {
    my $self = shift;

    $self->{result} .= "<![CDATA[";
}

sub end_cdata {
    my $self = shift;

    $self->{result} .= "]]>";
}

sub comment {
    my ($self, $comment) = @_;

    $self->{result} .= "<!-- $comment->{Data} -->";
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
    
    $self->{result} .= "Warning: $exception->{Message}\n";
}

sub error {
    my ($self, $exception) = @_;
    
    $self->{result} .= "Error: $exception->{Message}\n";
}

sub fatal_error {
    my ($self, $exception) = @_;
    
    $self->{result} .= "Fatal Error: $exception->{Message}\n";
}

1;
