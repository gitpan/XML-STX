require 5.005_02;
BEGIN { require warnings if $] >= 5.006; }
use strict;
use XML::STX;
use XML::STX::Compiler;


# --------------------------------------------------
package XML::STX::TrAX;
# only base class for XML::STX; it acts as TransformerFactory

sub new_templates {
    my ($self, $source) = @_;

    $source = $self->_check_source($source);

    my $comp = XML::STX::Compiler->new();
    $comp->{DBG} = $self->{DBG};

    $source->{XMLReader}->{Handler} = $comp;
    $source->{XMLReader}->{Source} = $source->{InputSource};
    my $sheet = $source->{XMLReader}->parse();

    return XML::STX::TrAX::Templates->new($sheet);
}

sub new_source {
    my ($self, $uri, $reader) = @_;

    $reader = $self->_get_parser() unless $reader;

    return XML::STX::TrAX::SAXSource->new($reader, {SystemId => $uri});
}

sub new_result {
    my ($self, $handler) = @_;

    $handler = $self->_get_writer() unless $handler;

    return XML::STX::TrAX::SAXResult->new($handler);
}

# shortcut: new transformation context for default templates
sub new_transformer {
    my ($self, $source) = @_;

    my $templates = $self->new_templates($source);
    return $templates->new_transformer;
}


# --------------------------------------------------
package XML::STX::TrAX::Templates;

sub new {
    my ($class, $sheet) = @_;

    my $self = bless {Stylesheet => $sheet,
		     }, $class;
    return $self;
}

# new transformation context
sub new_transformer {
    my $self = shift;

    return XML::STX::TrAX::Transformer->new($self->{Stylesheet});
}


# --------------------------------------------------
package XML::STX::TrAX::Transformer;
use Clone qw(clone);
@XML::STX::TrAX::Transformer::ISA = qw(XML::STX::Base);

sub new {
    my ($class, $sheet) = @_;

    my $stx = XML::STX->new();

    my $self = bless {Stylesheet => $sheet,
		      STX => $stx,
		      Parameters => {},
		      URIResolver => undef,
		      ErrorListener => undef,
		     }, $class;
    return $self;
}

sub transform {
    my ($self, $source, $result) = @_;

    $source = $self->_check_source($source);
    $result = $self->_check_result($result);

    $source->{XMLReader}->{Handler} = $self->{STX};
    $source->{XMLReader}->{Source} = $source->{InputSource};
    $self->{STX}->{Handler} = $result->{Handler};
    $self->{STX}->{Sheet} = $self->{Stylesheet};

    # stylesheet parameters
    foreach (keys %{$self->{STX}->{Sheet}->{dGroup}->{pars}}) {
	if (exists $self->{Parameters}->{$_}) {
	    my $seq = $self->_to_sequence($self->{Parameters}->{$_});
	    $self->{STX}->{Sheet}->{dGroup}->{vars}->[0]->{$_}->[0] = $seq;
	    $self->{STX}->{Sheet}->{dGroup}->{vars}->[0]->{$_}->[1] = clone($seq);

	} else {
	    $self->doError(510, 3, $_) 
	      if $self->{STX}->{Sheet}->{dGroup}->{pars}->{$_};
	}
    }

    return $source->{XMLReader}->parse();
}

sub clear_parameters {
    my $self = shift;

    $self->{Parameters} = {};
}


# --------------------------------------------------
package XML::STX::TrAX::SAXSource;

sub new {
    my ($class, $XMLReader, $InputSource) = @_;

    my $self = bless {XMLReader => $XMLReader,
		      InputSource => $InputSource,
		      SystemId => $InputSource->{SystemId},
		     }, $class;
    return $self;
}


# --------------------------------------------------
package XML::STX::TrAX::SAXResult;

sub new {
    my ($class, $Handler, $SystemId) = @_;

    my $self = bless {Handler => $Handler,
		      SystemId => $SystemId,
		     }, $class;
    return $self;
}


1;
__END__

=head1 NAME

XML::STX::TrAX - objects for TrAX-like interface

=head1 SYNOPSIS

see XML::STX

=head1 AUTHOR

Petr Cimprich (Ginger Alliance), petr@gingerall.cz

=head1 SEE ALSO

XML::STX, perl(1).

=cut
