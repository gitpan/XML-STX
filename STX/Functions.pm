package XML::STX::Functions;

require 5.005_02;
BEGIN { require warnings if $] >= 5.006; }
use strict;
use XML::STX::Base;

# --------------------------------------------------
# functions
# --------------------------------------------------
# string()
# boolean()
# number()
# normalize-space()
# name()
# namespace-uri()
# local-name()
# prefix()
# get-node()
# level()
# starts-with()
# contains()
# substring()
# substring-before()
# substring-after()
# string-length()
# concat()
# translate()
# count()
# empty()
# item-at()
# sublist()

# NUMBER = number(VALUE) --------------------
sub F_number($$){
    my ($self, $val) = @_;
    
    # item -> singleton sequence
    my $seq = ($val->[1] and not(ref $val->[1])) ? [$val] : $val;

    if (@{$seq} == 0) {
	$self->doError('104', 3, 'number');

    } else {

	if ($seq->[0]->[1] == STX_NODE) {
	    return $self->F_number($self->F_string($seq));

	} elsif ($seq->[0]->[1] == STX_STRING) {
	    return [$1,STX_NUMBER] if $seq->[0]->[0] =~ /^\s*(-?\d+\.?\d*)\s*$/;
	    return [$1 * 10**$2,STX_NUMBER] 
	      if $seq->[0]->[0] =~ /^\s*(-?\d+(?:\.\d*)?)[eE]([+-]?\d+)\s*$/;
	    return ['NaN',STX_NUMBER];

	} elsif ($seq->[0]->[1] == STX_BOOLEAN) {
	    $seq->[0]->[0] ? return [1,STX_NUMBER] : return [0,STX_NUMBER];

	} elsif ($seq->[0]->[1] == STX_NUMBER) {
	    return $seq->[0];
   
	} else { # unknown type
	    $self->doError('101', 3, $seq->[0]->[1]);
	}
    }
}

# BOOLEAN = boolean(seq) --------------------
sub F_boolean($$){
    my ($self, $val) = @_;

    # item -> singleton sequence
    my $seq = ($val->[1] and not(ref $val->[1])) ? [$val] : $val;

    if (@{$seq} == 0) {
	return [0,STX_BOOLEAN];

    } else {
	
	if (grep($_->[1] == STX_NODE, @$seq)) {
	    return [1,STX_BOOLEAN];

	} elsif ($seq->[0]->[1] == STX_STRING) {
	    return [0,STX_BOOLEAN] if $seq->[0]->[0] eq '';
	    return [0,STX_BOOLEAN] if $seq->[0]->[0] eq 'false';
	    return [0,STX_BOOLEAN] if $seq->[0]->[0] eq '0';
	    return [1,STX_BOOLEAN];

	} elsif ($seq->[0]->[1] == STX_BOOLEAN) {
	    return $seq->[0];

	} elsif ($seq->[0]->[1] == STX_NUMBER) {
	    return [0,STX_BOOLEAN] if $seq->[0]->[0] == 0;
	    return [0,STX_BOOLEAN] if $seq->[0]->[0] eq 'NaN';
	    return [1,STX_BOOLEAN];
   
	} else { # unknown type
	    $self->doError('101', 3, $seq->[0]->[1]);
	}
    }
}

# STRING = string(seq) --------------------
sub F_string($$){
    my ($self, $val) = @_;

    # item -> singleton sequence
    my $seq = ($val->[1] and not(ref $val->[1])) ? [$val] : $val;

    if (@{$seq} == 0) {
	return ['',STX_STRING];

    } else {

	if ($seq->[0]->[1] == STX_NODE) {

	    if ($seq->[0]->[0]->{Type} == STX_ROOT_NODE) {
		$self->doError('102', 2, 'root');
		return ['',STX_STRING];

	    } elsif ($seq->[0]->[0]->{Type} == STX_ELEMENT_NODE) {
		my $look = ref $self->_lookahead 
		  ? $self->_lookahead()->{Data} : '';
		return [$look,STX_STRING];

	    } elsif ($seq->[0]->[0]->{Type} == STX_ATTRIBUTE_NODE
		     or $seq->[0]->[0]->{Type} == STX_NS_NODE) {
		return [$seq->[0]->[0]->{Value},STX_STRING];

	    } elsif ($seq->[0]->[0]->{Type} == STX_TEXT_NODE
		     or $seq->[0]->[0]->{Type} == STX_CDATA_NODE
		     or $seq->[0]->[0]->{Type} == STX_PI_NODE
		     or $seq->[0]->[0]->{Type} == STX_COMMENT_NODE) {
		return [$seq->[0]->[0]->{Data},STX_STRING];
		
	    } else {
		$self->doError('103', 3, $seq->[0]->[1]);
	    }

	} elsif ($seq->[0]->[1] == STX_STRING) {
	    return $seq->[0];

	} elsif ($seq->[0]->[1] == STX_BOOLEAN) {
	    $seq->[0]->[0] ? return ['true',STX_STRING] 
	      : return ['false',STX_STRING];

	} elsif ($seq->[0]->[1] == STX_NUMBER) {
	    return [$1,STX_STRING] if $seq->[0]->[0] =~ /^\s*(-?\d+\.?\d*)\s*$/;
	    return [$1 * 10**$2,STX_STRING] 
	      if $seq->[0]->[0] =~ /^\s*(-?\d+(?:\.\d*)?)[eE]([+-]?\d+)\s*$/;
	    return ['NaN',STX_STRING];
   
	} else { # unknown type
	    $self->doError('101', 3, $seq->[0]->[1]);
	}
    }
}

# BOOL = not(seq) --------------------
sub F_not($$){
    my ($self, $seq) = @_;

    my $bool = $self->F_boolean($seq);

    if ($bool->[0]) {
	return [[0, STX_BOOLEAN]];

    } else {
	return [[1, STX_BOOLEAN]];
    }
}

# STRING = normalize-space(string) --------------------
sub F_normalize_space($$){
    my ($self, $seq) = @_;

    if (@{$seq} == 0) {
	return $seq;

    } else {
	my $str = $self->F_string($seq);
	$str->[0] =~ s/^\s+([^\s]*)/$1/;
	$str->[0] =~ s/([^\s]*)\s+$/$1/;
	$str->[0] =~ s/\s{2,}/ /g;
	return [ $str ];
    }
}

# STRING = name(node) --------------------
sub F_name($$){
    my ($self, $seq) = @_;

    if ($seq->[0] and $seq->[0]->[1] == STX_NODE 
	and ($seq->[0]->[0]->{Type} == 1 or $seq->[0]->[0]->{Type} == 6)) {

	return [[$seq->[0]->[0]->{Name},STX_STRING]];

    } else {
	$self->doError('105', 3, 'name', 
		       'node-element/attribute', $self->_type($seq));
    }
}

# STRING = namespace-uri(node) --------------------
sub F_namespace_uri($$){
    my ($self, $seq) = @_;

    if ($seq->[0] and $seq->[0]->[1] == STX_NODE
	and ($seq->[0]->[0]->{Type} == 1 or $seq->[0]->[0]->{Type} == 6)) {

	return [[$seq->[0]->[0]->{NamespaceURI},STX_STRING]]
	  if $seq->[0]->[0]->{NamespaceURI};
	return [['',STX_STRING]];

    } else {
	$self->doError('105', 3, 'namespace-uri', 
		       'node-element/attribute', $self->_type($seq));
    }
}

# STRING = local-name(node) --------------------
sub F_local_name($$){
    my ($self, $seq) = @_;

    if ($seq->[0] and $seq->[0]->[1] == STX_NODE
	and ($seq->[0]->[0]->{Type} == 1 or $seq->[0]->[0]->{Type} == 6)) {

	return [[$seq->[0]->[0]->{LocalName},STX_STRING]]
	  if $seq->[0]->[0]->{LocalName};
	return [[$seq->[0]->[0]->{Name},STX_STRING]];

    } else {
	$self->doError('105', 3, 'local-name', 
		       'node-element/attribute', $self->_type($seq));
    }
}

# STRING = prefix(node) --------------------
sub F_prefix($$){
    my ($self, $seq) = @_;

    if ($seq->[0] and $seq->[0]->[1] == STX_NODE
	and ($seq->[0]->[0]->{Type} == 1 or $seq->[0]->[0]->{Type} == 6)) {

	return [[$seq->[0]->[0]->{Prefix},STX_STRING]] 
	  if $seq->[0]->[0]->{Prefix};
	return [['',STX_STRING]];

    } else {
	$self->doError('105', 3, 'prefix', 
		       'node-element/attribute', $self->_type($seq));
    }
}

# NODE = get-node(number) --------------------
sub F_get_node($$){
    my ($self, $seq) = @_;

    my $n = ($seq->[0] and $seq->[0]->[1] == STX_NUMBER)
      ? $seq->[0] : $self->F_number($seq);

    my $index = sprintf("%.0f", $n->[0]);

    return [[$self->{STX}->{Stack}->[$index], STX_NODE]]
      if $self->{STX}->{Stack}->[$index];
    return [];
}

# NUMBER = level(node) --------------------
sub F_level($$){
    my ($self, $seq) = @_;

    if ($seq->[0] and $seq->[0]->[1] == STX_NODE) {
	return [[$seq->[0]->[0]->{Index}, STX_NUMBER]];

    } else {
	return [] unless $seq->[0];
	$self->doError('105', 3, 'level', 'node', $self->_type($seq));
    }
}

# BOOLEAN = starts-with(string, string) --------------------
sub F_starts_with($$){
    my ($self, $seq1, $seq2) = @_;

    return [] unless $seq1->[0] and $seq2->[0];

    my $str = $seq1->[0]->[1] == STX_STRING 
      ? $seq1->[0] : $self->F_string($seq1->[0]);

    my $start = $seq2->[0]->[1] == STX_STRING 
      ? $seq2->[0] : $self->F_string($seq2->[0]);

    return [[1, STX_BOOLEAN]] if index($str->[0], $start->[0]) == 0;
    return [[0, STX_BOOLEAN]];
}

# BOOLEAN = contains(string, string) --------------------
sub F_contains($$){
    my ($self, $seq1, $seq2) = @_;

    return [] unless $seq1->[0] and $seq2->[0];

    my $str = $seq1->[0]->[1] == STX_STRING 
      ? $seq1->[0] : $self->F_string($seq1->[0]);

    my $start = $seq2->[0]->[1] == STX_STRING 
      ? $seq2->[0] : $self->F_string($seq2->[0]);

    return [[1, STX_BOOLEAN]] if index($str->[0], $start->[0]) >= 0;
    return [[0, STX_BOOLEAN]];
}

# STRING = substring(string, number, number?) --------------------
sub F_substring(){
    my ($self, $seq1, $seq2, $seq3) = @_;

    return [] unless $seq1->[0] and $seq2->[0] 
      and (not($seq3) or $seq3->[0]);

    my $str = $seq1->[0]->[1] == STX_STRING 
      ? $seq1->[0] : $self->F_string($seq1->[0]);

    my $offset = $seq2->[0]->[1] == STX_NUMBER 
      ? $seq2->[0] : $self->F_number($seq2->[0]);
    my $off = sprintf("%.0f", $offset->[0]);

    $off = 1 if $off < 1;
    return [['', STX_STRING]] if $off > length($str->[0]);

    if ($seq3) {
	my $count = $seq3->[0]->[1] == STX_NUMBER 
      ? $seq3->[0] : $self->F_number($seq3->[0]);
	my $cnt = sprintf("%.0f", $count->[0]);

	return [[substr($str->[0], $off - 1, $cnt), STX_STRING]];

    } else {
	return [[substr($str->[0], $off - 1), STX_STRING]];
    }
}

# STRING = substring-before(string, string) --------------------
sub F_substring_before(){
    my ($self, $seq1, $seq2) = @_;

    return [] unless $seq1->[0] and $seq2->[0];

    my $str = $seq1->[0]->[1] == STX_STRING 
      ? $seq1->[0] : $self->F_string($seq1->[0]);

    my $marker = $seq2->[0]->[1] == STX_STRING 
      ? $seq2->[0] : $self->F_string($seq2->[0]);

    $str->[0] =~ /^(.*?)$marker->[0]/ and return [[$1, STX_STRING]];
    return [['', STX_STRING]];
}

# STRING = substring-after(string, string) --------------------
sub F_substring_after(){
    my ($self, $seq1, $seq2) = @_;

    return [] unless $seq1->[0] and $seq2->[0];

    my $str = $seq1->[0]->[1] == STX_STRING 
      ? $seq1->[0] : $self->F_string($seq1->[0]);

    my $marker = $seq2->[0]->[1] == STX_STRING 
      ? $seq2->[0] : $self->F_string($seq2->[0]);

    $str->[0] =~ /$marker->[0](.*)$/ and return [[$1, STX_STRING]];
    return [['', STX_STRING]];
}

# NUMBER = string-length(string) --------------------
sub F_string_length(){
    my ($self, $seq) = @_;

    return [] unless $seq->[0];

    my $str = $seq->[0]->[1] == STX_STRING 
      ? $seq->[0] : $self->F_string($seq->[0]);

    return [[length($str->[0]), STX_NUMBER]];
}

# STRING = concat(string+) --------------------
sub F_concat(){
    my ($self, @arg) = @_;
    my $res = '';

    foreach (@arg) {
	return [] unless $_->[0];

	my $str = $_->[0]->[1] == STX_STRING 
	  ? $_->[0] : $self->F_string($_);

	$res .= $str->[0];
    }
    return [[$res, STX_STRING]];
}

# STRING = translate(string, string, string) --------------------
sub F_translate($$$$){
    my ($self, $s, $o, $n) = @_;

    return [] unless $s->[0] and $o->[0] and $n->[0];

    my $str = $s->[0]->[1] == STX_STRING ? $s->[0] : $self->F_string($s);
    my $old = $o->[0]->[1] == STX_STRING ? $o->[0] : $self->F_string($o);
    my $new = $n->[0]->[1] == STX_STRING ? $n->[0] : $self->F_string($n);

    $_ = $str->[0];
    eval "tr/$old->[0]/$new->[0]/d";

    return [[$_, STX_STRING]];
}

# NUMBER = count(seq) --------------------
sub F_count($){
    my ($self, $seq) = @_;

    if (ref($seq) eq 'ARRAY') {
	return [[scalar @$seq, STX_NUMBER]];

     } else {
	 $self->doError('105', 3, 'count', 'sequence', ref($seq));
     }
}

# BOOLEAN = empty(seq) --------------------
sub F_empty($){
    my ($self, $seq) = @_;

    if (ref($seq) eq 'ARRAY') {
	return [[1, STX_BOOLEAN]] if scalar @$seq == 0;
	return [[0, STX_BOOLEAN]];

     } else {
	 $self->doError('105', 3, 'empty', 'sequence', ref($seq));
     }
}

# ITEM = item-at(seq, number) --------------------
sub F_item_at($$){
    my ($self, $seq, $idx) = @_;

    my $n = ($idx->[0] and $idx->[0]->[1] == STX_NUMBER)
      ? $idx->[0] : $self->F_number($idx);

    my $i = sprintf("%.0f", $n->[0]);

    if (ref($seq) eq 'ARRAY') {
	return [] unless $seq->[0];
	$self->doError('106', 3, $i, scalar @$seq) unless $seq->[$i-1];
	$self->doError('107', 3, $i) unless $i>0;
	return $seq->[$i-1];

     } else {
	 $self->doError('105', 3, 'item-at', 'sequence', ref($seq));
     }
}

# seq = sublist(seq, number) --------------------
sub F_sublist(){
    my ($self, $seq, $idx, $len) = @_;

    my $n = ($idx->[0] and $idx->[0]->[1] == STX_NUMBER)
      ? $idx->[0] : $self->F_number($idx);
    my $i = sprintf("%.0f", $n->[0]);

    my $l = undef;
    if ($len) {
	my $n = ($len->[0] and $len->[0]->[1] == STX_NUMBER)
	  ? $len->[0] : $self->F_number($len);
	$l = sprintf("%.0f", $n->[0]);
    }

    if (ref($seq) eq 'ARRAY') {
	return [] unless $seq->[0];
	$self->doError('106', 3, $i, scalar @$seq) unless $seq->[$i-1];
	$self->doError('107', 3, $i) unless $i>0;
	my @res = @$seq;
	return [splice(@res, $i-1, $l)] if $l;
	return [splice(@res, $i-1)];

     } else {
	 $self->doError('105', 3, 'sublist', 'sequence', ref($seq));
     }
}

1;
__END__

=head1 XML::STX::Base

XML::STX::Functions - STXPath functions

=head1 SYNOPSIS

no public API

=head1 AUTHOR

Petr Cimprich (Ginger Alliance), petr@gingerall.cz

=head1 SEE ALSO

XML::STX, perl(1).

=cut



