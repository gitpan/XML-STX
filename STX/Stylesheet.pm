package XML::STX::Stylesheet;

require 5.005_02;
BEGIN { require warnings if $] >= 5.006; }
use strict;

# --------------------------------------------------

sub new {
    my $class = shift;

    my $properties = {
		      'pass-through' => 0,
		      'recognize-cdata' => 1,
		      'default-stxpath-namespace' => '',
		      'output-encoding' => undef,
		     };

    my $group = XML::STX::Group->new(0, undef);

    my $self = bless {
		      Options => $properties,
		      dGroup => $group,
		      global => [], # global templates
		      next_gid => 1,
		      next_tid => 1,
		      named_templates => {},
		     }, $class;
    return $self;
}

# --------------------------------------------------

package XML::STX::Group;

sub new {
    my ($class, $gid, $group) = @_;

    my $self = bless {
		      gid => $gid,
		      group => $group, # parent group
		      templates => {},
		      public => [], # public & global templates
		      visible => [], # visible templates
		      groups => {},
		      vars => [{}], # variables declared in this group
		     }, $class;
    return $self;
}

# --------------------------------------------------

package XML::STX::Template;

sub new {
    my $class = shift;
    my $tid = shift;
    my $group = shift;

    my $self = bless {
		      tid => $tid,
		      group => $group,
		      instructions => [],
		      vars => [{}], # local variables
		      _attr => 0,
		      _attr_only => 1,
		      _self => 0,
		     }, $class;
    return $self;
}

1;
__END__

=head1 NAME

XML::STX::Stylesheet - stylesheet objects for XML::STX

=head1 SYNOPSIS

no API

=head1 AUTHOR

Petr Cimprich (Ginger Alliance), petr@gingerall.cz

=head1 SEE ALSO

XML::STX, perl(1).

=cut
