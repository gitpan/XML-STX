package XML::STX::Base;

require 5.005_02;
BEGIN { require warnings if $] >= 5.006; }
use strict ('refs', 'subs');
use vars qw(@EXPORT);
use Carp;
use XML::STX::Writer;
use XML::SAX::PurePerl;
require Exporter;
@XML::STX::Base::ISA = qw(Exporter);

# --------------------------------------------------
# common constants
# --------------------------------------------------
@EXPORT = qw( STX_ELEMENT_NODE 
	      STX_TEXT_NODE
	      STX_CDATA_NODE
	      STX_PI_NODE
	      STX_COMMENT_NODE
	      STX_ATTRIBUTE_NODE
	      STX_ROOT_NODE

              STX_NODE
              STX_BOOLEAN
              STX_NUMBER
              STX_STRING

	      STX_NS_URI
	      STX_VERSION
	      XMLNS_URI

              STXE_START_DOCUMENT
	      STXE_END_DOCUMENT
	      STXE_START_ELEMENT
	      STXE_END_ELEMENT
	      STXE_CHARACTERS
	      STXE_PI
	      STXE_START_CDATA
	      STXE_END_CDATA
	      STXE_COMMENT
	      STXE_START_BUFFER
	      STXE_END_BUFFER

	      I_LITERAL_START
	      I_LITERAL_END
	      I_ELEMENT_START
	      I_ELEMENT_END
	      I_P_CHILDREN
	      I_P_SELF
	      I_P_BUFFER
	      I_P_ATTRIBUTES
              I_CALL_PROCEDURE
	      I_CHARACTERS
	      I_COPY_START
	      I_COPY_END
              I_ATTRIBUTE_START
	      I_ATTRIBUTE_END
	      I_CDATA_START
	      I_CDATA_END
	      I_COMMENT_START
	      I_COMMENT_END
	      I_PI_START
	      I_PI_END
	      
	      I_IF_START
	      I_IF_END
	      I_VARIABLE_START
	      I_VARIABLE_END
	      I_VARIABLE_SCOPE_END
	      I_ASSIGN_START
	      I_ASSIGN_END
	      I_ELSE_START
	      I_ELSE_END
	      I_ELSIF_START
	      I_ELSIF_END
              I_BUFFER_START
              I_BUFFER_END
              I_BUFFER_SCOPE_END
              I_RES_BUFFER_START
              I_RES_BUFFER_END

	      $NCName
	      $QName
	      $NCWild
	      $QNWild
	      $NODE_TYPE
	      $NUMBER_RE
	      $DOUBLE_RE
	      $LITERAL
	      $FUNCTION
	    );

# node types
sub STX_ELEMENT_NODE(){1;}
sub STX_TEXT_NODE(){2;}
sub STX_CDATA_NODE(){3;}
sub STX_PI_NODE(){4;}
sub STX_COMMENT_NODE(){5;}
sub STX_ATTRIBUTE_NODE(){6;}
sub STX_ROOT_NODE(){7;}

# atomic data types
sub STX_NODE(){1;}
sub STX_BOOLEAN(){2;}
sub STX_NUMBER() {3;}
sub STX_STRING() {4;}

# STX constants
sub STX_NS_URI() {'http://stx.sourceforge.net/2002/ns'};
sub STX_VERSION() {'1.0'};
sub XMLNS_URI() {'http://www.w3.org/2000/xmlns/'};

# events
sub STXE_START_DOCUMENT(){1;}
sub STXE_END_DOCUMENT(){2;}
sub STXE_START_ELEMENT(){3;}
sub STXE_END_ELEMENT(){4;}
sub STXE_CHARACTERS(){5;}
sub STXE_PI(){6;}
sub STXE_START_CDATA(){7;}
sub STXE_END_CDATA(){8;}
sub STXE_COMMENT(){9;}
sub STXE_START_BUFFER(){10;}
sub STXE_END_BUFFER(){11;}

# instructions
sub I_LITERAL_START(){1;}
sub I_LITERAL_END(){2;}
sub I_ELEMENT_START(){3;}
sub I_ELEMENT_END(){4;}
sub I_P_CHILDREN(){5;}
sub I_CHARACTERS(){6;}
sub I_COPY_START(){7;}
sub I_COPY_END(){8;}
sub I_ATTRIBUTE_START(){9;}
sub I_ATTRIBUTE_END(){10;}
sub I_CDATA_START(){11;}
sub I_CDATA_END(){12;}
sub I_COMMENT_START(){13;}
sub I_COMMENT_END(){14;}
sub I_PI_START(){15;}
sub I_PI_END(){16;}
sub I_P_SELF(){17;}
sub I_P_ATTRIBUTES(){18;}
sub I_CALL_PROCEDURE(){19;}
sub I_P_BUFFER(){20;}

sub I_IF_START(){101;}
sub I_IF_END(){102;}
sub I_VARIABLE_START(){103;}
sub I_VARIABLE_END(){104;}
sub I_VARIABLE_SCOPE_END(){105;}
sub I_ASSIGN_START(){106;}
sub I_ASSIGN_END(){107;}
sub I_ELSE_START(){108;}
sub I_ELSE_END(){109;}
sub I_ELSIF_START(){110;}
sub I_ELSIF_END(){111;}
sub I_BUFFER_START(){112;}
sub I_BUFFER_END(){113;}
sub I_BUFFER_SCOPE_END(){114;}
sub I_RES_BUFFER_START(){115;}
sub I_RES_BUFFER_END(){116;}

# tokens
$NCName = '[A-Za-z_][\w\\.\\-]*';
$QName = "($NCName:)?$NCName";
$NCWild = "${NCName}:\\*|\\*:${NCName}";
$QNWild = "\\*";
$NODE_TYPE = '((text|comment|processing-instruction|node|cdata)\\(\\))';
$NUMBER_RE = '\d+(\\.\d*)?|\\.\d+';
$DOUBLE_RE = '\d+(\\.\d*)?[eE][+-]?\d+';
$LITERAL = '\\"[^\\"]*\\"|\\\'[^\\\']*\\\'';
$FUNCTION = '(boolean|string|number|true|false|not|name|namespace-uri|local-name|prefix|normalize-space|position|get-node|level|starts-with|contains|substring|substring-before|substring-after|string-length|concat|translate|has-child-nodes|count|empty|item-at|sublist)';

# --------------------------------------------------
# error processing
# --------------------------------------------------

sub doError {
    my ($self, $no, $sev, @params) = @_;
    my ($pkg, $file, $line, $sub) = caller(1);

    my %severity = ( 1 => 'Warning', 
		     2 => 'Recoverable Error', 
		     3 => 'Fatal Error' );

    my $orig;
    if ($no == 1)      { $orig = 'STXPath Tokenizer'   } 
    elsif ($no < 100)  { $orig = 'STXPath Analyzer'    }
    elsif ($no < 200)  { $orig = 'STXPath Function'    }
    elsif ($no < 500)  { $orig = 'Stylesheet Parser' }
    elsif ($no < 1000) { $orig = 'STX Runtime Engine'  }
    else               { $orig = 'Parser'}

    my $msg = $self->_err_msg($no, @params);

    my $txt = "[XML::STX $severity{$sev} $no] $orig: $msg!\n";

    if (exists $self->{locator}) {
	$txt .= "URI: $self->{locator}->{SystemId}, ";
	$txt .= "LINE: $self->{locator}->{LineNumber}\n";
    }

    if ($self->{DBG} or $self->{STX}->{DBG}) {
	$txt .= "DEBUG INFO: subroutine: $sub, line: $line\n"
    }

    if ($sev > 2) {
	croak $txt;
    } else {
	print STDERR $txt;
    }
}

sub set_document_locator {
    my ($self, $locator) = @_;
    
    $self->{locator} = $locator;
}

sub _err_msg {
    my $self = shift;
    my $no = shift;
    my @params = @_;

    my %msg = (

	# STXPath engine       
	1 => "Invalid query:\n_P\n_P^^^",
	2 => "_P expression failed to parse - junk after end: _P",
	3 => "Invalid parenthesized expression: _P not expected",
	4 => "Error in expression - //..",
	5 => "Error in expression - .._P",
	6 => "Error in expression - _P not expected",
	7 => "Incorrect match pattern: [ expected instead of _P",
	8 => "Unknown kind-test - something is wrong",
	9 => "Predicate not terminated: ] expected instead of _P",
	10 => "Prefix _P not bound",
	11 => "Conversion of _P to number failed: NaN",
	12 => "Function _P not supported",
	13 => "( expected after function name (_P), _P found instead",
	14 => ", or ) expected after function argument (_P), _P found instead",
	15 => "Incorrect number (_P) of arguments; _P() has _P arguments",
	16 => "Variable _P not visible",
	17 => "Namespace nodes can only be associated with elements, _P found",

	# STXPath functions
        101 => "Unknown data type: _P",
        102 => "String value not defined for _P nodes",
        103 => "Unknown node type: _P",
        104 => "Empty sequence can't be converted to _P",
        105 => "_P() function requires a _P argument (_P passed)",
        106 => "count(): item _P requested for sequence with _P members",
        107 => "count(): item _P requested. Indexes start from 1",

	# Stylesheet parser
        201 => "Chunk after the end of document element",
        202 => "_P not allowed as document element (use <stx:transform>)",
        203 => "<_P> must be present only once",
        204 => "visibility=\"_P\" (must be 'public', 'private' or 'global')",
        205 => "_P=\"_P\" (must be either 'yes' or 'no')",
        206 => "pass-through=\"_P\" (must be 'none','all' or 'text')",
        207 => "stx:attribute must be preceded by element start (i_P found)",
        208 => "_P instructions must not be nested",
        209 => "_P instruction not supported",
        210 => "_P - literal elements must be NS qualified outside templates",
        211 => "_P _P is redeclared in the same scope",
        212 => "_P must contain the _P mandatory attribute",
        213 => "_P attribute of _P can't contain {...}",
        214 => "_P attribute of _P must be _P",
        215 => "_P not allowed at this point (as child of _P)",
        216 => "Static evaluation failed, _P requires a context",
        217 => "Value of _P attribute (_P) must be _P",
        218 => "_P must follow immediately behind _P (found behind i_P)",
        219 => "Duplicate name of _P: _P",

	# Runtime
        501 => "Prefix in <stx:element name=\"_P\"> not declared",
        502 => "_P attribute of _P must evaluate to _P (_P)",
        503 => "Output not well-formed: </_P> expected instead of </_P>",
        504 => "Output not well-formed: </_P> found after end of document",
        505 => "Assignment failed: _P _P not declared in this scope",
        506 => "Position not defined for attributes",
        507 => "Group named '_P' not defined",
        508 => "Called procedure _P not visible",
        509 => "_P is not valid _P for TrAX API",
        510 => "Required parameter _P hasn't been not supplied",
	);

    my $msg = $msg{$no};
    foreach (@params) {	$msg =~ s/_P/$_/; }
    return $msg;
}

# --------------------------------------------------
# utils
# --------------------------------------------------

sub _type($) {
    my ($self, $seq) = @_;
    my $type = 'unknown';

    if ($seq->[0]) {
	if ($seq->[0]->[1] == STX_STRING) {$type = 'string'}
	elsif ($seq->[0]->[1] == STX_BOOLEAN) {$type = 'boolean'}
	elsif ($seq->[0]->[1] == STX_NUMBER) {$type = 'number'}
	elsif ($seq->[0]->[1] == STX_NODE) {
	    $type = 'node';
	    if ($seq->[0]->[0]->{Type} == STX_ELEMENT_NODE) {
		$type .= '-element';
	    } elsif ($seq->[0]->[0]->{Type} == STX_ATTRIBUTE_NODE) {
		$type .= '-attribute';
	    } elsif ($seq->[0]->[0]->{Type} == STX_TEXT_NODE) {
		$type .= '-text';
	    } elsif ($seq->[0]->[0]->{Type} == STX_CDATA_NODE) {
		$type .= '-cdata';
	    } elsif ($seq->[0]->[0]->{Type} == STX_PI_NODE) {
		$type .= '-processing-instruction';
	    } elsif ($seq->[0]->[0]->{Type} == STX_COMMENT_NODE) {
		$type .= '-comment';
	    } else {
		$type .= '-root';
	    }
	}

    } else {
	$type = 'empty sequence';	
    }
    return $type;
}

sub _counter_key($) {
    my ($self, $tok) = @_;

    $tok =~ s/^node\(\)$/\/node/ 
      or $tok =~ s/^text\(\)$/\/text/ 
	or $tok =~ s/^cdata\(\)$/\/cdata/ 
	  or $tok =~ s/^comment\(\)$/\/comment/
	    or $tok =~ s/^processing-instruction\(\)$/\/pi/ 
	      or $tok =~ s/^processing-instruction:(.*)$/\/pi:$1/ 
		or $tok = index($tok, ':') > 0 ? $tok : ':' . $tok;
    $tok =~ s/\*/\/star/;

    return $tok;
}

sub _get_parser() {
    my $self = shift;

    my @preferred = ('XML::SAX::Expat',
		     'XML::LibXML::SAX::Parser');

    unshift @preferred, $self->{Parser} if $self->{Parser};

    foreach (@preferred) {
	$@ = undef;
	eval "require $_;";
	unless ($@) {
	    return eval "$_->new()";
	}    }
    # fallback
    return XML::SAX::PurePerl->new();
}

sub _get_writer() {
    my $self = shift;

    my @preferred = ('XML::SAX::Writer');

    unshift @preferred, $self->{Writer} if $self->{Writer};

    foreach (@preferred) {
	$@ = undef;
	eval "require $_;";
	unless ($@) {
	    return eval "$_->new()";
	}    }
    # fallback
    return XML::STX::Writer->new();
}

sub _check_source {
    my ($self, $source) = @_;

    if (ref $source eq 'XML::STX::TrAX::SAXSource') {
	return $source;

    } elsif (ref $source eq 'HASH' and defined $source->{SystemId}) {
	my $reader = $self->_get_parser();
	return XML::STX::TrAX::SAXSource->new($reader, $source);

    } elsif (ref $source eq '') {
	my $reader = $self->_get_parser();
	return XML::STX::TrAX::SAXSource->new($reader, {SystemId => $source});

     } else {
	     $self->doError(509, 3, ref $source, 'source');
     }
}

sub _check_result {
    my ($self, $result) = @_;

    if (ref $result eq 'XML::STX::TrAX::SAXResult') {
	return $result;

    } elsif (not defined $result) {
	my $writer = $self->_get_writer();
	return XML::STX::TrAX::SAXResult->new($writer);

     } else {
	 $self->doError(509, 3, ref $result, 'result');
     }
}

sub _to_sequence {
    my ($self, $value) = @_;

    if ($value =~ /^($NUMBER_RE|$DOUBLE_RE)$/) {
	return [[$1, STX_NUMBER]]

    } else {
	return [[$value, STX_STRING]];
    }

}

1;
__END__

=head1 XML::STX::Base

XML::STX::Base - basic definitions for XML::STX

=head1 SYNOPSIS

no API

=head1 AUTHOR

Petr Cimprich (Ginger Alliance), petr@gingerall.cz

=head1 SEE ALSO

XML::STX, perl(1).

=cut


