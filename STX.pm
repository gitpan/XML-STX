package XML::STX;

require 5.005_02;
BEGIN { require warnings if $] >= 5.006; }
use strict;
use vars qw($VERSION);
use XML::SAX::Base;
use XML::NamespaceSupport;
use XML::STX::Base;
use XML::STX::TrAX;
use XML::STX::STXPath;
use XML::STX::Compiler;
use Clone qw(clone);

@XML::STX::ISA = qw(XML::SAX::Base XML::STX::Base XML::STX::TrAX);
$VERSION = '0.20';

# --------------------------------------------------

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $options = ($#_ == 0) ? shift : { @_ };

    my $self = bless $options, $class;
    # turn NS processing on by default
    $self->set_feature('http://xml.org/sax/features/namespaces', 1);
    return $self;
}

# API ----------------------------------------

sub get_stylesheet {
    my ($self, $parser, $uri) = @_;

    my $comp = XML::STX::Compiler->new();
    $comp->{DBG} = $self->{DBG};

    $parser->{Handler} = $comp;
    return $parser->parse_uri($uri);
}

sub transform {
    my ($self, $sheet, $parser, $uri, $handler) = @_;

    $parser->{Handler} = $self;
    $self->{Handler} = $handler;
    $self->{Sheet} = $sheet;

    return $parser->parse_uri($uri);
}

# content ----------------------------------------

sub start_document {
    my $self = shift;
    #print "STX: start_document\n";

    $self->{Stack} = []; # ancestor stack
    $self->{CharBuffer} = ''; # to join consequent text on input

    my $frame = {Type => STX_ROOT_NODE, 
		 Index => 0, 
		 Name => '/',
		};

    $self->_current_node([STXE_START_DOCUMENT, $frame]);
}

sub end_document {
    my $self = shift;
    #print "STX: end_document\n";

    $self->_current_node([STXE_END_DOCUMENT]);

    # lookahead clean-up
    $self->_current_node;

    return scalar @{$self->{Stack}};
}

sub start_element {
    my $self = shift;
    my $el = shift;
    #print "STX: start_element: $el->{Name}\n";

    my $frame = {
		 Type => STX_ELEMENT_NODE,
		 Name => $el->{Name},
		 Attributes => $el->{Attributes},
		 NamespaceURI => $el->{NamespaceURI},
		 Prefix => $el->{Prefix},
		 LocalName => $el->{LocalName},
		};

    $self->_current_node([STXE_START_ELEMENT, $frame]);
}

sub end_element {
    my $self = shift;
    my $el = shift;
    #print "STX: end_element: $el->{Name}\n";

    $self->_current_node([STXE_END_ELEMENT]);
}

sub characters {
    my $self = shift;
    my $char = shift;
    #print "STX: characters: $char->{Data}\n";

    return if $self->{Sheet}->{Options}->{'strip-space'}
      and $char->{Data} =~ /^\s*$/;

    if ($self->{lookahead}->[0] == STXE_CHARACTERS) {
	$self->{lookahead}->[1]->{Data} .= $char->{Data};
	
    } else {
	my $type = $self->{CDATA} ? STX_CDATA_NODE : STX_TEXT_NODE;
	my $frame = {
		     Type => $type,
		     Data => $char->{Data},
		    };

	$self->_current_node([STXE_CHARACTERS, $frame]);
    }
}

sub processing_instruction {
    my $self = shift;
    my $pi = shift;
    #print "STX: pi: $pi->{Target}\n";

    my $frame = {
		 Type => STX_PI_NODE,
		 Target => $pi->{Target},
		 Data => $pi->{Data},
		};

    $self->_current_node([STXE_PI, $frame]);
}

sub ignorable_whitespace {
}

sub start_prefix_mapping {
}

sub end_prefix_mapping {
}

sub skipped_entity {
}

# lexical ----------------------------------------

sub start_cdata {
    my $self = shift;
    #print "STX: start_cdata\n";

    if ($self->{Sheet}->{Options}->{'recognize-cdata'}) {
	$self->_current_node([STXE_START_CDATA]);
	$self->{CDATA} = 1 
    }
}

sub end_cdata {
    my $self = shift;
    #print "STX: end_cdata\n";

    if ($self->{Sheet}->{Options}->{'recognize-cdata'}) {
	$self->_current_node([STXE_END_CDATA]);
	$self->{CDATA} = 0;
    }
}

sub comment {
    my $self = shift;
    my $comment = shift;
    #print "STX: comment: $comment->{Data}\n";

    my $frame = {
		 Type => STX_COMMENT_NODE,
		 Data => $comment->{Data},
		};

    $self->_current_node([STXE_COMMENT, $frame]);
}

sub start_dtd {
}

sub end_dtd {
}

sub start_entity {
}

sub end_entity {
}

# error ----------------------------------------

sub warning {
}

sub error {
}

sub fatal_error {
}

# SAX1 ----------------------------------------

sub xml_decl {
}

# internal ----------------------------------------

sub change_stream {
    my ($self, $event) = @_;
    #print "STX: change_stream: $event\n";

    $self->_current_node([$event]);
}

# --------------------------------------------------

sub _current_node {
    my ($self, $next) = @_;

    my $current;

    if ($next->[0] == STXE_START_BUFFER) {
	push @{$self->{_sla}}, $self->{lookahead};
	$self->{lookahead} = $next;
	return;

    } elsif ($next->[0] == STXE_END_BUFFER) {
	$current = $self->{lookahead};
	$self->{lookahead} = pop @{$self->{_sla}};

    } else {
	$current = $self->{lookahead};
	$self->{lookahead} = $next;
    }
    
    if ($current) {

	if ($current->[0] == STXE_START_DOCUMENT) {
	    $self->{root} = $current->[1];
	    $self->_start_document($current->[1]);

	} elsif ($current->[0] == STXE_END_DOCUMENT) {
	    $self->_end_document;

	} elsif ($current->[0] == STXE_START_ELEMENT) {
	    $self->_start_element($current->[1]);

	} elsif ($current->[0] == STXE_END_ELEMENT) {
	    $self->_end_element;

	} elsif ($current->[0] == STXE_CHARACTERS) {
	    $self->_characters($current->[1]);

	} elsif ($current->[0] == STXE_PI) {
	    $self->_processing_instruction($current->[1]);

	} elsif ($current->[0] == STXE_COMMENT) {
	    $self->_comment($current->[1]);

	}
    }
}

sub _start_document {
    my ($self, $root) = @_;
    #print "STX: > _start_document\n";

    $self->{Counter} = []; # position()
    $self->{byEnd} = {}; # stack for instructions after process-children
    $self->{OutputStack} = []; # output stack
    $self->{LookUp} = [1]; # lookup for templates
    $self->{SP} = XML::STX::STXPath->new($self);

    $self->{ns} = XML::NamespaceSupport->new({ xmlns => 1 });
    $self->{ns_out} = XML::NamespaceSupport->new({ xmlns => 1 });
    $self->{_g_prefix} = 0;
    $self->{_stx_element} = [];
    $self->{_self} = 0;
    $self->{_handlers} = [];
    $self->{_drivers} = [];
    $self->{_c_template} = [];

    $self->{ns}->pushContext;
    # default NS for STXPath
    if ($self->{Sheet}->{Options}->{'default-stxpath-namespace'}) {
	$self->{ns}->declare_prefix('#default', 
		    $self->{Sheet}->{Options}->{'default-stxpath-namespace'});
    }

    # counter
    $self->{Counter}->[0] = {};
    $self->_counter(0, '/root', '/node');

    $self->SUPER::start_document;

    #new
    push @{$self->{Stack}}, $root;
    push @{$self->{LookUp}}, 0;
    $self->_process;
}

sub _end_document {
    my $self = shift;
    #print "STX: > _end_document\n";

    my $node = $self->{Stack}->[0];

    # run 2nd part of template if any
    if (defined $self->{byEnd}->{0}) {

	while ($#{$self->{byEnd}->{0}} > -1) {
	    $self->_run_template(0, undef, 0, $node);
	    #shift @{$self->{exG}->{$node->{Index} + 1}};
	}
    }
    $self->{exG}->{1} = undef;
    $self->{byEnd}->{0} = undef;

    $self->{ns}->popContext;
    $self->SUPER::end_document;

    $self->doError(504, 3, 
		   $self->{OutputStack}->[$#{$self->{OutputStack}}]->{Name})
      if $#{$self->{OutputStack}} >= 0;    
}

sub _start_element {
    my ($self, $el) = @_;
    #print "STX: > _start_element: $el->{Name}\n";

    my $index = scalar @{$self->{Stack}};
    $self->{Counter}->[$index] or $self->{Counter}->[$index] = {};

    $el->{Prefix} = '' unless defined $el->{Prefix};
    $self->_counter($index, '/node', '/star', "$el->{Prefix}:/star", 
		    "/star:$el->{LocalName}", "$el->{Prefix}:$el->{LocalName}");

    $el->{Index} = $index;
    $el->{Counter} = $self->{Counter}->[$index];

    # string value
    if ($self->{lookahead}->[0] == STXE_CHARACTERS) {
	$el->{Value} = $self->{lookahead}->[1]->{Data};
    } else {
	$el->{Value} = '';
    }

    # NS context + declarations
    $self->{ns}->pushContext;
    foreach (keys %{$el->{Attributes}}) {
	$el->{Attributes}->{$_}->{Type} = STX_ATTRIBUTE_NODE;
	$el->{Attributes}->{$_}->{Index} = $index + 1;

 	# default NS
 	if ($el->{Attributes}->{$_}->{Name} eq 'xmlns') {
 	    $self->{ns}->declare_prefix('#data_default',
 					$el->{Attributes}->{$_}->{Value});

	# prefixed NS
	} elsif ($el->{Attributes}->{$_}->{Prefix} eq 'xmlns') {
	    $self->{ns}->declare_prefix($el->{Attributes}->{$_}->{LocalName}, 
					$el->{Attributes}->{$_}->{Value})
	}
    }

    push @{$self->{Stack}}, $el;
    push @{$self->{LookUp}}, 0;
    $self->_process;
}

sub _end_element {
    my $self = shift;

    my $node = $self->{Stack}->[$#{$self->{Stack}}];
    #print "STX: > _end_element $node->{Name} ($node->{Index})\n";

    # run 2nd part of template if any
    if (defined $self->{byEnd}->{$node->{Index}}) {

	while ($#{$self->{byEnd}->{$node->{Index}}} > -1) {
	    $self->_run_template(0, undef, $node->{Index}, $node);
	    #shift @{$self->{exG}->{$node->{Index} + 1}};
	}
    }
    $self->{exG}->{$node->{Index} + 1} = undef;
    $self->{byEnd}->{$node->{Index}} = undef;

    # cleaning counters
    my $index = scalar @{$self->{Stack}};
    $self->{Counter}->[$index] = {};

    pop @{$self->{LookUp}};
    pop @{$self->{Stack}};
    $self->{ns}->popContext;
}

sub _characters {
    my $self = shift;
    my $char = shift;
    #print "STX: > _characters: $char->{Data}\n";

    my $index = scalar @{$self->{Stack}};
    $self->{Counter}->[$index] or $self->{Counter}->[$index] = {};

    $self->_counter($index, '/node', '/text');
    $self->_counter($index, '/cdata') if $self->{CDATA};

    $char->{Index} = $index;
    $char->{Counter} = $self->{Counter}->[$index];

    push @{$self->{Stack}}, $char;
    push @{$self->{LookUp}}, 0;

    $self->_process;

    pop @{$self->{LookUp}};
    pop @{$self->{Stack}};
}

sub _processing_instruction {
    my $self = shift;
    my $pi = shift;
    #print "STX: > _pi: $pi->{Target}\n";

    my $index = scalar @{$self->{Stack}};
    $self->{Counter}->[$index] or $self->{Counter}->[$index] = {};

    $self->_counter($index, '/node', '/pi', "/pi:$pi->{Target}");

    $pi->{Index} = $index;
    $pi->{Counter} = $self->{Counter}->[$index];

    push @{$self->{Stack}}, $pi;
    push @{$self->{LookUp}}, 0;

    $self->_process;

    pop @{$self->{LookUp}};
    pop @{$self->{Stack}};
}

sub _comment {
    my $self = shift;
    my $comment = shift;
    #print "STX: > _comment: $comment->{Data}\n";

    my $index = scalar @{$self->{Stack}};
    $self->{Counter}->[$index] or $self->{Counter}->[$index] = {};

    $self->_counter($index, '/node', '/comment');

    $comment->{Index} = $index;
    $comment->{Counter} = $self->{Counter}->[$index];

    push @{$self->{Stack}}, $comment;
    push @{$self->{LookUp}}, 0;

    $self->_process;

    pop @{$self->{LookUp}};
    pop @{$self->{Stack}};
}

# process ----------------------------------------

sub _process {
    my $self = shift;
    #print "STX: process> LookUp $self->{LookUp}->[$#{$self->{LookUp}} - 1]\n";

#     $self->_frameDBG;
#     $self->_counterDBG;
#     $self->_nsDBG;
#     $self->_grpDBG;

    if ($self->{LookUp}->[$#{$self->{LookUp}} - 1]) {

	# visible namespaces
	my $ns;
	foreach ($self->{ns}->get_prefixes) {
	    $ns->{$_} = $self->{ns}->get_uri($_);
	}
	# current node
	my $node = $self->{Stack}->[$#{$self->{Stack}}];

	# current group
	my $g;
	if ($#{$self->{Stack}} == 0) {
	    # default group
	    $g = $self->{Sheet}->{dGroup};
	} else {
	    my $exG = $self->{exG}->{$node->{Index}}->[$#{$self->{exG}->{$node->{Index}}}];
	    if ($exG) {
		# explicit group
		if ($self->{Sheet}->{named_groups}->{$exG}) {
		    $g = $self->{Sheet}->{named_groups}->{$exG};
		} else {
		    $self->doError(507, 2, $exG);
		    $g = $self->{Stack}->[$#{$self->{Stack}} - 1]->{Group}->[$#{$self->{Stack}->[$#{$self->{Stack}} - 1]->{Group}}];	    
		}
	    } else {
		# group of the recent matching template
		$g = $self->{Stack}->[$#{$self->{Stack}} - 1]->{Group}->[$#{$self->{Stack}->[$#{$self->{Stack}} - 1]->{Group}}];
	    }
	}
	#print "STX: base group $g->{gid}\n";

	my $templates = $self->_match($ns, $node, $g);

	$self->{_child_nodes} = $self->_child_nodes;

	# run the best match template if any
	if ($templates->[0]) {
	    $node->{Group} = [$templates->[0]->{group}];

	    my $k = $templates->[0]->{_pos_key}->{step}->[0] 
	      ? $self->_counter_key($templates->[0]->{_pos_key}->{step}->[0])
		: '/root';
	    my $pos = $self->{Counter}->[$#{$self->{Stack}}]->{$k};

	    $self->_run_template(1, $templates, $ns, $node, $pos);

        # default rule is applied
	} else {
	    #print "STX: default rule\n";
	    $node->{Group} = [$g];

	    my $t = $self->_get_def_template;
	    $self->_run_template(1, [$t], $ns, $node);
	}
    }
}

sub _process_attributes {
    my ($self, $node, $ns) = @_;
    #print "STX: processing attributes\n";
    
    # current group
    my $g;
    my $exG = $self->{exG}->{$node->{Index}}->[$#{$self->{exG}->{$node->{Index}}}];
    if ($exG) {
	# explicit group
	if ($self->{Sheet}->{named_groups}->{$exG}) {
	    $g = $self->{Sheet}->{named_groups}->{$exG};
	} else {
	    $self->doError(507, 2, $exG);
	    $g = $node->{Group}->[$#{$node->{Group}}];
	}
    } else {
	# group of the recent matching template
	$g = $node->{Group}->[$#{$node->{Group}}];
    }
    #print "STX: base group $g->{gid}\n";

    foreach (keys %{$node->{Attributes}}) {
	my $templates = $self->_match($ns, $node->{Attributes}->{$_}, $g, 1);

	# run the best match template if any
	if ($templates->[0]) {

	    $node->{Attributes}->{$_}->{Group} = [$templates->[0]->{group}];

	    $self->{_pos} = undef;
	    push @{$self->{Stack}}, $node->{Attributes}->{$_};

	    $self->_run_template(1, $templates, $ns, $node->{Attributes}->{$_}, 1);

	    pop @{$self->{Stack}};
	    $node->{Attributes}->{$_}->{Group} = undef;
	    
        # default rule is applied
	} else {
	    #print "STX: default rule\n";
	    my $t = $self->_get_def_template;
	    $self->_run_template(1, [$t], $ns, $node);
	}
    }
}

sub _process_self {
    my ($self, $node, $ns, $env) = @_;
    #print "STX: processing self\n";

    # current group
    my $g;
    my $exG = $self->{exG}->{$node->{Index}}->[$#{$self->{exG}->{$node->{Index}}}];
    if ($exG) {
	# explicit group
	if ($self->{Sheet}->{named_groups}->{$exG}) {
	    $g = $self->{Sheet}->{named_groups}->{$exG};
	} else {
	    $self->doError(507, 2, $exG);
	    $g = $node->{Group}->[$#{$node->{Group}}];   
	}
    } else {
	# group of the recent matching template
	$g = $node->{Group}->[$#{$node->{Group}}];   
    }
    #print "STX: base group $g->{gid}\n";
    
    my $templates = $self->_match($ns, $node, $g);

    # excluded templates are excluded
    my $new_templates = [];
    foreach my $t (@$templates) {
	push @$new_templates, $t 
	  unless grep($t->{tid} == $_, @{$self->{_excluded_templates}});
    }

    # run the best match template if any sss
    if ($new_templates->[0]) {
	push @{$node->{Group}}, $templates->[0]->{group};

	my $k = $new_templates->[0]->{_pos_key}->{step}->[0] 
	  ? $self->_counter_key($new_templates->[0]->{_pos_key}->{step}->[0])
	    : '/root';
	my $pos = $self->{Counter}->[$#{$self->{Stack}}]->{$k};

	$self->_run_template(2, $new_templates, $env, $node);

    # default rule is applied
    } else {
	#print "STX: default rule\n";
	push @{$node->{Group}}, $g;
	my $t = $self->_get_def_template;
	$self->_run_template(1, [$t], $ns, $node);
    }
    pop @{$node->{Group}};
}

sub _call_procedure {
    my ($self, $name, $node, $env) = @_;
    #print "STX: call procedure: $name\n";

    # current group
    my $g;
    my $exG = $self->{exG}->{$node->{Index}}->[$#{$self->{exG}->{$node->{Index}}}];
    if ($exG) {

	# explicit group
	if ($self->{Sheet}->{named_groups}->{$exG}) {
	    $g = $self->{Sheet}->{named_groups}->{$exG};
	} else {
	    $self->doError(507, 2, $exG);
	    $g = $node->{Group}->[$#{$node->{Group}}];
	}
    } else {
	# group of the recent matching template
	$g = $node->{Group}->[$#{$node->{Group}}];
    }
    #print "STX: base group $g->{gid}\n";
    
    # procedure
    my $p = $g->{proc_visible}->{$name};

    $self->doError(508, 3, $name) unless $p;

    # run the template
    push @{$node->{Group}}, $p->{group};
    $self->_run_template(2, [$p], $env, $node);
    pop @{$node->{Group}}, $p->{group};
}

# matching ----------------------------------------

sub _match {
    my ($self, $ns, $node, $group, $att) = @_;

    my $templates = [];
    # there are different lists of templates for attributes and
    # all other nodes (in order to keep lists shorter)
    my $visible = $att ? 'att_visible' : 'visible';
    my $global = $att ? 'att_global' : 'global';

    if ($group->{$visible}->[0]) {
	my $templ_p1 = $self->_match_p1($node, $ns, $group, $visible);
	push @$templates, @$templ_p1;
    }

    if ($self->{Sheet}->{$global}->[0]) {
	if ($templates->[0]) {
	    if ($self->{_self}) {

		my $templ_p2 = $self->_match_p2($node, $ns, $global);
		push @$templates, @$templ_p2;
	    }

	} else {
	    my $templ_p2 = $self->_match_p2($node, $ns, $global);
	    push @$templates, @$templ_p2;
	}
    }

    #print "STX: >winner $templates->[0]->{tid}\n" if $templates->[0];
    return $templates;
}

# match templates visible from the current group
sub _match_p1 {
    my ($self, $node, $ns, $group, $visible) = @_;

    my $templates = [];
    my $current_p = -1e20;

    # the same group + public/global children
    foreach my $t (@{$group->{$visible}}) {
	#print "STX: match visible -> template $t->{tid}\n";
	#print "STX:  ->self:$self->{_self} complex:$group->{_complex_priority}\n";

	next if grep($current_p >= $_, @{$t->{priority}})
	  and not($group->{_complex_priority} or $self->{_self});

	my $res = $self->{SP}->match($node, 
				     $t->{match},
				     $t->{priority},
				     $ns,
				     {}  # variables
				    );
	
	#print "STX: >matching $res->[0] | priority $res->[1]\n";

	if ($res->[0]) {

	    if (($group->{_complex_priority} or $self->{_self}) 
		and $current_p > $res->[1]) {
		push @$templates, $t;
	    } else {
		unshift @$templates, $t;
	    }
	    
	    $t->{_pos_key} = $res->[2]->[$#{$res->[2]}];
	    last unless $group->{_complex_priority} or $self->{_self};
	    $current_p = $res->[1] if $current_p < $res->[1];
	}
    }

    return $templates;
}

# match global templates
sub _match_p2 {
    my ($self, $node, $ns, $global) = @_;

    my $templates = [];
    my $current_p = -1e20;

    # global templates
    foreach my $t (@{$self->{Sheet}->{$global}}) {
	#print "STX: match global -> template $t->{tid}\n";

	next if grep($current_p >= $_, @{$t->{priority}})
	  and not($self->{Sheet}->{dGroup}->{_complex_priority} or $self->{_self});

	my $res = $self->{SP}->match($node, 
				     $t->{match},
				     $t->{priority},
				     $ns,
				     {}  # variables
				    );
	
	#print "STX: >matching $res->[0] | priority $res->[1]\n";

	if ($res->[0]) {

	    if (($self->{Sheet}->{dGroup}->{_complex_priority} or $self->{_self}) 
		and $current_p > $res->[1]) {
		push @$templates, $t;
	    } else {
		unshift @$templates, $t;
	    }
	    
	    $t->{_pos_key} = $res->[2]->[$#{$res->[2]}];
	    last unless $self->{Sheet}->{dGroup}->{_complex_priority} 
	      or $self->{_self};
	    $current_p = $res->[1] if $current_p < $res->[1];
	}
    }

    return $templates;
}

# run template ----------------------------------------

# run template instructions
sub _run_template {
    my ($self, $ctx, $templates, $i_ns, $c_node, $position) = @_;
    my $t;         # template to be run
    my $start = 0; # the first instruction to be processed
    my $env;       # environment (ns, condition stack, etc.)
    my $ns;        # namespaces

    # new template
    if ($ctx == 1) {
	$t = $templates->[0];
	$env = { condition => [1], 
		 position => $position, 
		 ns => $i_ns,
	       };
	$self->{position} = $position;
	$ns = $i_ns;

    # self & procedures
    } elsif ($ctx == 2) {
	$t = $templates->[0];
	$env = $i_ns;
	$self->{position} = $env->{position};
	$ns = $env->{ns};

    # 2nd part of template
    } else {
	my $byEnd = shift @{$self->{byEnd}->{$i_ns}};
	$t = $byEnd->[0];
	$start = $byEnd->[1];
	$env = $byEnd->[2];
	$self->{position} = $env->{position};
	$ns = $env->{ns};
    }

    # new variables on recursion
    if ($t->{'new-scope'} and ($ctx == 1 or $ctx == 2)) {
	push @{$t->{group}->{vars}}, {};

	foreach (keys %{$t->{group}->{vars}->[$#{$t->{group}->{vars}}-1]}) {

	    $t->{group}->{vars}->[$#{$t->{group}->{vars}}]->{$_} 
	      = clone($t->{group}->{vars}->[$#{$t->{group}->{vars}}-1]->{$_});

 	    $t->{group}->{vars}->[$#{$t->{group}->{vars}}]->{$_}->[0]
 	      = clone($t->{group}->{vars}->[$#{$t->{group}->{vars}}]->{$_}->[1])
 		unless $t->{group}->{vars}->[$#{$t->{group}->{vars}}]->{$_}->[2];
	}
    }
    # new local variables
    push @{$t->{vars}}, {} if $ctx == 1 or $ctx == 2;

    # new buffers on recursion
    if ($t->{'new-scope'} and ($ctx == 1 or $ctx == 2)) {
	push @{$t->{group}->{bufs}}, {};

	foreach (keys %{$t->{group}->{bufs}->[$#{$t->{group}->{bufs}}-1]}) {

	    $t->{group}->{bufs}->[$#{$t->{group}->{bufs}}]->{$_} 
	      = clone($t->{group}->{bufs}->[$#{$t->{group}->{bufs}}-1]->{$_});

 	    $t->{group}->{bufs}->[$#{$t->{group}->{bufs}}]->{$_}->[0]
 	      = clone($t->{group}->{bufs}->[$#{$t->{group}->{bufs}}]->{$_}->[1])
 		unless $t->{group}->{bufs}->[$#{$t->{group}->{bufs}}]->{$_}->[2];
	}
    }
    # new local buffers
    push @{$t->{bufs}}, {} if $ctx == 1 or $ctx == 2;

    #print "STX: running template $t->{tid}\n";
    
    my $out = {};       # out element buffer
    my $text = '';      # out text buffer
    my $children = 0;   # interrupted by process-children
    my $skipped_if = 0; # number of nested skipped stx:if
    $env->{elsif}  = 0; # elsif (when) has already been evaluated

    push @{$self->{_c_template}}, $t;
    $self->{c_group} = $t->{group};

    # the main loop over instructions
    for (my $j = $start; $j < @{$t->{instructions}}; $j++) {

	my $i = $t->{instructions}->[$j];
	#print "STX: =>$j:$i->[0]\n";
	#print "STX: cond: $env->{condition}->[$#{$env->{condition}}]\n";

	# resolving conditions
	unless ($env->{condition}->[$#{$env->{condition}}]) {

	    if ($i->[0] == I_IF_START) {
		$skipped_if++;
		next;

	    } elsif ($i->[0] == I_IF_END or $i->[0] == I_ELSIF_END 
		     or $i->[0] == I_ELSE_END) {
		if ($skipped_if > 0) { 
		    $skipped_if--; 
		    next; 
		}

	    } else { 
		next;		
	    }
	}

	# I_LITERAL_START ----------------------------------------
	if ($i->[0] == I_LITERAL_START) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};

	    $out->{Name} = $i->[1]->{Name};
	    $out->{LocalName} = $i->[1]->{LocalName};
	    $out->{Prefix} = $i->[1]->{Prefix}
	      if exists $i->[1]->{Prefix};
	    $out->{NamespaceURI} = $i->[1]->{NamespaceURI}
	      if exists $i->[1]->{NamespaceURI};

	    $out->{Attributes} = clone($i->[1]->{Attributes})
	      if exists $i->[1]->{Attributes};

 	    foreach (keys %{$out->{Attributes}}) {
		$out->{Attributes}->{$_}->{Name} 
		  = $out->{Attributes}->{$_}->{Name};
		$out->{Attributes}->{$_}->{LocalName} 
		  = $out->{Attributes}->{$_}->{LocalName};
		$out->{Attributes}->{$_}->{Prefix} 
		  = $out->{Attributes}->{$_}->{Prefix}
		    if exists $out->{Attributes}->{$_}->{Prefix};  
		$out->{Attributes}->{$_}->{NamespaceURI} 
		  = $out->{Attributes}->{$_}->{NamespaceURI}
		    if exists $out->{Attributes}->{$_}->{NamespaceURI};
		$out->{Attributes}->{$_}->{Value} 
		  = $self->_expand($out->{Attributes}->{$_}->{Value}, $ns)
		    if exists $out->{Attributes}->{$_}->{Value};  
	    }

	# I_LITERAL_END ----------------------------------------
	} elsif ($i->[0] == I_LITERAL_END) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};

	    $out->{Name} = $i->[1]->{Name};
	    $out->{LocalName} = $i->[1]->{LocalName};
	    $out->{Prefix} = $i->[1]->{Prefix}
	      if exists $i->[1]->{Prefix};
	    $out->{NamespaceURI} = $i->[1]->{NamespaceURI}
	      if exists $i->[1]->{NamespaceURI};

	    $out = $self->_send_element_end($out);


	# I_ELEMENT_START ----------------------------------------
	} elsif ($i->[0] == I_ELEMENT_START) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};

	    $out = $self->_resolve_element($i);

	    push @{$self->{_stx_element}}, $out;

	# I_ELEMENT_END ----------------------------------------
	} elsif ($i->[0] == I_ELEMENT_END) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};

	    if ($i->[1]) {
		$out = $self->_resolve_element($i);

	    } else {
		$out = $self->{_stx_element}->[$#{$self->{_stx_element}}];
	    }
	    pop @{$self->{_stx_element}};
	    $out = $self->_send_element_end($out);

	# I_ATTRIBUTE_START ----------------------------------------
	} elsif ($i->[0] == I_ATTRIBUTE_START) {

	    my $at = $self->_resolve_element($i, 1); # aflag set
	    my $nsuri = $at->{NamespaceURI} ? $at->{NamespaceURI} : '';
	    $out->{Attributes}->{"{$nsuri}$at->{LocalName}"} = $at;

	    if ($i->[3]) {
		my $val = $self->_expand($i->[3], $ns);
		$val = $self->{SP}->F_normalize_space([[$val,STX_STRING]]);

		$out->{Attributes}->{"{$nsuri}$at->{LocalName}"}->{Value}
		  = $val->[0]->[0];

	    } else {
		$self->{_TTO} = $at; # text template object
		$self->{_text_cache} = '';
	    }

	# I_ATTRIBUTE_END ----------------------------------------
	} elsif ($i->[0] == I_ATTRIBUTE_END) {

	    if ($self->{_TTO}) {

		my $val = $self->{SP}->F_normalize_space([[$self->{_text_cache},
							   STX_STRING]]);
		my $nsuri = $self->{_TTO}->{NamespaceURI} 
		  ? $self->{_TTO}->{NamespaceURI} : '';
		$out->{Attributes}->{"{$nsuri}$self->{_TTO}->{LocalName}"}->{Value} 
		  = $val->[0]->[0];

		$self->{_TTO} = undef;
		$self->{_text_cache} = undef;
	    }

	# I_P_CHILDREN ----------------------------------------
	} elsif ($i->[0] == I_P_CHILDREN) {

	    next unless $self->{_child_nodes};
	    $out = $self->_send_element_start($out) if exists $out->{Name};

	    my $fi = $c_node->{Index};
	    # pointer to the template, the number of the next
	    # instruction, and environment is put to 'byEnd' stack

	    $self->{byEnd}->{$fi} = [[$t, $j+1, $env]];
	    $self->{LookUp}->[$#{$self->{LookUp}}] = 1;

	    my $exg = $i->[1] ? $i->[1] : undef;
	    $self->{exG}->{$fi + 1} = [$exg];
	    $children = 1;
	    last;

	# I_P_ATTRIBUTES ----------------------------------------
	} elsif ($i->[0] == I_P_ATTRIBUTES) {
	    next unless $c_node->{Type} == STX_ELEMENT_NODE;
	    $out = $self->_send_element_start($out) if exists $out->{Name};

	    my $exg = $i->[1] ? $i->[1] : undef;
	    push @{$self->{exG}->{$c_node->{Index}}}, $exg;

	    $self->_process_attributes($c_node, $ns);

	    pop @{$self->{exG}->{$c_node->{Index}}};

	# I_P_SELF ----------------------------------------
	} elsif ($i->[0] == I_P_SELF) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};

	    $self->{_self} = 1;

	    # explicit group
	    my $exg = $i->[1] ? $i->[1] : undef;
	    push @{$self->{exG}->{$c_node->{Index}}}, $exg;

	    #excluded templates
	    if (ref $self->{_excluded_templates}) {
		push @{$self->{_excluded_templates}}, $t->{tid};
	    } else {
		$self->{_excluded_templates} = [$t->{tid}];
	    }

	    $self->_process_self($c_node, $ns, $env);

	    # process-children has been called inside
 	    if ($self->{byEnd}->{$c_node->{Index}}) {
 		push @{$self->{byEnd}->{$c_node->{Index}}}, [$t, $j+1, $env];
 		$children = 1;
 		last;
 	    }

	    pop @{$self->{exG}->{$c_node->{Index}}};
	    pop @{$self->{_excluded_templates}};
	    $self->{_self} = 0;

	# I_CALL_PROCEDURE ----------------------------------------
	} elsif ($i->[0] == I_CALL_PROCEDURE) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};
	    
	    # explicit group
	    my $exg = $i->[2] ? $i->[2] : undef;
	    push @{$self->{exG}->{$c_node->{Index}}}, $exg;

	    $self->_call_procedure($i->[1], $c_node, $env);

	    # process-children has been called inside
 	    if ($self->{byEnd}->{$c_node->{Index}}) {
 		push @{$self->{byEnd}->{$c_node->{Index}}}, [$t, $j+1, $env];
 		$children = 1;
 		last;
 	    }

	    pop @{$self->{exG}->{$c_node->{Index}}};

	# I_CHARACTERS ----------------------------------------
	} elsif ($i->[0] == I_CHARACTERS) {
	    $out = $self->_send_element_start($out) 
	      if (exists $out->{Name} and not($self->{_TTO}));

	    $self->_send_text($self->_expand($i->[1], $ns));

	# I_COPY_START ----------------------------------------
	} elsif ($i->[0] == I_COPY_START) {

	    my $type = $c_node->{Type};

	    if ($type == STX_ELEMENT_NODE) {
		$out = $self->_send_element_start($out) if exists $out->{Name};

		$out->{Name} = $c_node->{Name};
		$out->{LocalName} = $c_node->{LocalName};
		$out->{Prefix} = $c_node->{Prefix} 
		  if exists $c_node->{Prefix};
		$out->{NamespaceURI} = $c_node->{NamespaceURI}
		  if exists $c_node->{NamespaceURI};

		$out->{Attributes} = {};
		my @att = split(' ', $i->[1]);

		foreach my $a (keys %{$c_node->{Attributes}}) {

		    if ($i->[1] eq '#all' 
			or grep($_ eq $c_node->{Attributes}->{$a}->{Name}, @att)) {

			$out->{Attributes}->{$a}->{Name} 
			  = $c_node->{Attributes}->{$a}->{Name};
			$out->{Attributes}->{$a}->{LocalName}
			  = $c_node->{Attributes}->{$a}->{LocalName};
			$out->{Attributes}->{$a}->{Prefix} 
			  = $c_node->{Attributes}->{$a}->{Prefix}
			    if exists $c_node->{Attributes}->{$a}->{Prefix};  
			$out->{Attributes}->{$a}->{NamespaceURI} 
			  = $c_node->{Attributes}->{$a}->{NamespaceURI}
			    if exists $c_node->{Attributes}->{$a}->{NamespaceURI};  
			$out->{Attributes}->{$a}->{Value} 
			  = $c_node->{Attributes}->{$a}->{Value}
			    if exists $c_node->{Attributes}->{$a}->{Value};  
		    }
		}

	    } elsif ($type == STX_TEXT_NODE) {
		$out = $self->_send_element_start($out) if exists $out->{Name};

		$self->_send_text($c_node->{Data});

	    } elsif ($type == STX_CDATA_NODE) {
		$out = $self->_send_element_start($out) if exists $out->{Name};

		$self->SUPER::start_cdata() unless $self->{_TTO};
		$self->_send_text($c_node->{Data});
		$self->SUPER::end_cdata() unless $self->{_TTO};

	    } elsif ($type == STX_PI_NODE) {
		$out = $self->_send_element_start($out) if exists $out->{Name};

		$self->SUPER::processing_instruction(
				{Target => $c_node->{Target}, 
				 Data => $c_node->{Data}});

	    } elsif ($type == STX_COMMENT_NODE) {
		$out = $self->_send_element_start($out) if exists $out->{Name};

		$self->SUPER::comment({Data => $c_node->{Data}});

	    } elsif ($type == STX_ATTRIBUTE_NODE) {
		#tbd !!!

	    }

	# I_COPY_END ----------------------------------------
	} elsif ($i->[0] == I_COPY_END) {

	    my $type = $c_node->{Type};
	    if ($type == STX_ELEMENT_NODE) {
		$out = $self->_send_element_start($out) if exists $out->{Name};

		$out->{Name} = $c_node->{Name};
		$out->{LocalName} = $c_node->{LocalName};
		$out->{Prefix} = $c_node->{Prefix}
		  if exists $c_node->{Prefix};
		$out->{NamespaceURI} = $c_node->{NamespaceURI}
		  if exists $c_node->{NamespaceURI};

		$out = $self->_send_element_end($out);
	    }
	    # else: ignore </copy> for other types of nodes

	# I_CDATA_START ----------------------------------------
	} elsif ($i->[0] == I_CDATA_START) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};

	    $self->SUPER::start_cdata();

	# I_CDATA_END ----------------------------------------
	} elsif ($i->[0] == I_CDATA_END) {

	    $self->SUPER::end_cdata();

	# I_COMMENT_START ----------------------------------------
	} elsif ($i->[0] == I_COMMENT_START) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};

	    $self->{_TTO} = 'COM'; # comment
	    $self->{_text_cache} = '';

	# I_COMMENT_END ----------------------------------------
	} elsif ($i->[0] == I_COMMENT_END) {

	    $self->SUPER::comment({ Data => $self->{_text_cache} });

	    $self->{_TTO} = undef;
	    $self->{_text_cache} = undef;

	# I_PI_START ----------------------------------------
	} elsif ($i->[0] == I_PI_START) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};

	    my $target = $self->_expand($i->[1], $ns);
	    $self->doError(502, 3, 'name', 
			   '<stx:processing-instruction>', 
			   'non-qualified name', $target)
	      unless $target =~ /^$NCName$/;

	    $self->{_TTO} = $target; # PI target
	    $self->{_text_cache} = '';

	# I_PI_END ----------------------------------------
	} elsif ($i->[0] == I_PI_END) {

	    $self->SUPER::processing_instruction({
					Data => $self->{_text_cache},
					Target => $self->{_TTO},
					});

	    $self->{_TTO} = undef;
	    $self->{_text_cache} = undef;

	# I_VARIABLE_START ----------------------------------------
	} elsif ($i->[0] == I_VARIABLE_START) {

	    if ($i->[2] and $i->[3] == 0) {
		$t->{vars}->[$#{$t->{vars}}]->{$i->[1]} 
		  = [$self->_eval($i->[2], $ns)];

	    } else {
		$self->{_TTO} = $i->[1]; # text template object
		$self->{_text_cache} = '';
	    }

	# I_VARIABLE_END ----------------------------------------
	} elsif ($i->[0] == I_VARIABLE_END) {

	    if ($self->{_TTO}) {

		$t->{vars}->[$#{$t->{vars}}]->{$self->{_TTO}} 
		  = [$self->{SP}->F_normalize_space([[$self->{_text_cache},
						      STX_STRING]])];

		$self->{_TTO} = undef;
		$self->{_text_cache} = undef;
	    }

	# I_VARIABLE_SCOPE_END ----------------------------------------
	} elsif ($i->[0] == I_VARIABLE_SCOPE_END) {

	    $t->{vars}->[$#{$t->{vars}}]->{$i->[1]} = undef;

	# I_ASSIGN_START ----------------------------------------
	} elsif ($i->[0] == I_ASSIGN_START) {

	    if ($i->[2]) {
		my $var = $self->_get_objects($i->[1]);
		$self->doError(505, 3, 'variable', $i->[1]) unless $var; 

		$var->{$i->[1]}->[0] = $self->_eval($i->[2], $ns);

	    } else {
		$self->{_TTO} = $i->[1]; # text template object
		$self->{_text_cache} = '';
	    }

	# I_ASSIGN_END ----------------------------------------
	} elsif ($i->[0] == I_ASSIGN_END) {

	    if ($self->{_TTO}) {

		my $var = $self->_get_objects($self->{_TTO});
		$self->doError(505, 3, 'variable', $self->{_TTO}) unless $var; 
		$var->{$self->{_TTO}} = 
		  $self->{SP}->F_normalize_space([[$self->{_text_cache},
						   STX_STRING]]);

		$self->{_TTO} = undef;
		$self->{_text_cache} = undef;
	    }

	# I_BUFFER_START ----------------------------------------
	} elsif ($i->[0] == I_BUFFER_START) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};

	    # new buffer
	    my $b = XML::STX::Buffer->new($i->[1]);
	    $t->{bufs}->[$#{$t->{bufs}}]->{$i->[1]} = $b;

 	    push @{$self->{_handlers}}, $self->{Handler};
 	    $self->{Handler} = $b;
	    $self->{Methods} = {}; # to empty methods cached by XML::SAX::Base
 	    $self->{Handler}->init($self); # to initialize buffer
 	    #print "STX: new handler:$self->{Handler}\n";

	# I_BUFFER_END ----------------------------------------
	} elsif ($i->[0] == I_BUFFER_END) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};

 	    $self->{Handler} = pop @{$self->{_handlers}};
	    $self->{Methods} = {}; # to empty methods cached by XML::SAX::Base
 	    #print "STX: orig handler:$self->{Handler}\n";

	# I_BUFFER_SCOPE_END ----------------------------------------
	} elsif ($i->[0] == I_BUFFER_SCOPE_END) {

	    $t->{bufs}->[$#{$t->{bufs}}]->{$i->[1]} = undef;

 	# I_RES_BUFFER_START ----------------------------------------
 	} elsif ($i->[0] == I_RES_BUFFER_START) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};

 	    my $buf = $self->_get_objects($i->[1], 1);
 	    $self->doError(505, 3, 'buffer', $i->[1]) unless $buf; 

 	    push @{$self->{_handlers}}, $self->{Handler};
 	    $self->{Handler} = $buf->{$i->[1]};
	    $self->{Methods} = {}; # to empty methods cached by XML::SAX::Base
 	    $self->{Handler}->init($self, $i->[2]); # to initialize buffer
 	    #print "STX: new handler:$self->{Handler}\n";

 	# I_RES_BUFFER_END ----------------------------------------
 	} elsif ($i->[0] == I_RES_BUFFER_END) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};

 	    $self->{Handler} = pop @{$self->{_handlers}};
	    $self->{Methods} = {}; # to empty methods cached by XML::SAX::Base
 	    #print "STX: orig handler:$self->{Handler}\n";

	# I_P_BUFFER ----------------------------------------
	} elsif ($i->[0] == I_P_BUFFER) {
	    $out = $self->_send_element_start($out) if exists $out->{Name};

	    my $exg = $i->[2] ? $i->[2] : undef;
	    push @{$self->{exG}->{$c_node->{Index} + 1}}, $exg;

 	    my $buf = $self->_get_objects($i->[1], 1);
	    $self->{LookUp}->[$#{$self->{LookUp}}] = 1;

	    $buf->{$i->[1]}->process();

	    $self->{_child_nodes} = $self->_child_nodes;
	    pop @{$self->{LookUp}};
	    pop @{$self->{exG}->{$c_node->{Index} + 1}};

	# I_IF_START ----------------------------------------
	} elsif ($i->[0] == I_IF_START) {

	    my $bool = $self->{SP}->F_boolean($self->_eval($i->[1], $ns));

	    if ($bool->[0]) {
		push @{$env->{condition}}, 1;			

	    } else {
		push @{$env->{condition}}, 0;			
	    }

	# I_IF_END ----------------------------------------
	} elsif ($i->[0] == I_IF_END) {

	    $env->{otherwise} = pop @{$env->{condition}} ? 0 : 1;

	# I_ELSIF_START ----------------------------------------
	} elsif ($i->[0] == I_ELSIF_START) {

	    my $bool = $env->{elsif}
	      ? [0] : $self->{SP}->F_boolean($self->_eval($i->[1], $ns));

	    if ($bool->[0]) {
		push @{$env->{condition}}, 1;
		$env->{elsif} = 1;

	    } else {
		push @{$env->{condition}}, 0;			
	    }
	    
	# I_ELSIF_END ----------------------------------------
	} elsif ($i->[0] == I_ELSIF_END) {

	    $env->{otherwise} = (pop @{$env->{condition}} or $env->{elsif}) 
	      ? 0 : 1;

	# I_ELSE_START ----------------------------------------
	} elsif ($i->[0] == I_ELSE_START) {

	    push @{$env->{condition}}, $env->{otherwise};			

	# I_ELSE_END ----------------------------------------
	} elsif ($i->[0] == I_ELSE_END) {

	    pop @{$env->{condition}};

	}

    }
    # send element after the last instruction
    $out = $self->_send_element_start($out) if exists $out->{Name};

    if ($t->{'new-scope'} and not($children)) {
	pop @{$t->{group}->{vars}};
	pop @{$t->{group}->{bufs}};
    }
    pop @{$t->{vars}} unless $children;
    pop @{$t->{bufs}} unless $children;
    pop @{$self->{_c_template}};
}

sub _expand {
    my ($self, $val, $ns) = @_;

    if (ref $val) {
	my $seq = $self->{SP}->expr(
			[ $self->{Stack}->[$#{$self->{Stack}}] ],
			$val,
			$ns,
			{}
			);
	my $res = $self->{SP}->F_string($seq);
	return $res->[0];

    } else {
	return $val;
    }
}

sub _eval {
    my ($self, $val, $ns) = @_;

    my $seq = $self->{SP}->expr(
			[ $self->{Stack}->[$#{$self->{Stack}}] ],
			$val,
			$ns,
			{}
			);
    return $seq;
}

sub _send_element_start {
    my ($self, $out) = @_;

    $self->{ns_out}->pushContext;
    $self->{ns_out}->declare_prefix($out->{Prefix}, $out->{NamespaceURI})
      if $out->{NamespaceURI} or $out->{Prefix};

    foreach (keys %{$out->{Attributes}}) {
	$self->{ns_out}->declare_prefix($out->{Attributes}->{$_}->{Prefix}, 
					$out->{Attributes}->{$_}->{NamespaceURI})
	  if $out->{Attributes}->{$_}->{NamespaceURI} 
	    or $out->{Attributes}->{$_}->{Prefix};
    }

    my @declared = $self->{ns_out}->get_declared_prefixes;
    foreach (@declared) {

	my $key = $_ ? '{'. XMLNS_URI . "}$_" : '{}xmlns';

	$out->{Attributes}->{$key}->{Name} 
	  = $_ ? "xmlns:$_" : 'xmlns';
	$out->{Attributes}->{$key}->{NamespaceURI} 
	  = XMLNS_URI;
  	$out->{Attributes}->{$key}->{LocalName} 
  	  = $_;
  	$out->{Attributes}->{$key}->{Prefix} 
  	  = $_ ? 'xmlns' : '';
  	$out->{Attributes}->{$key}->{Value} 
  	  = $self->{ns_out}->get_uri($_);

  	my $mapping = {Prefix => $_, 
  		       NamespaceURI => $out->{Attributes}->{$key}->{Value}};
  	$self->SUPER::start_prefix_mapping($mapping);
    }

    $self->SUPER::start_element($out);
    push @{$self->{OutputStack}}, $out;

    return {};
}

sub _send_element_end {
    my ($self, $out) = @_;

    $self->SUPER::end_element($out);

    $self->{ns_out}->popContext;
    my $os =  pop @{$self->{OutputStack}};

    my $ns_out = defined $out->{NamespaceURI} ? $out->{NamespaceURI} : '';
    my $ns_os = defined $os->{NamespaceURI} ? $os->{NamespaceURI} : '';

    if (($ns_out ne $ns_os) or ($out->{LocalName} ne $os->{LocalName})) {
	
	$self->doError(503, 3, $os->{Name}, $out->{Name});
    }
    return {};
}

sub _send_text {
    my ($self, $text) = @_;

    if ($self->{_TTO}) {
	$self->{_text_cache} .= $text;

    } else {
	$self->SUPER::characters({ Data => $text });
    }
}

# util ----------------------------------------

sub _counter {
    my ($self, $index, @names) = @_;

    foreach (@names) {
	if (defined $self->{Counter}->[$index]->{$_}) {
	    $self->{Counter}->[$index]->{$_}++
	} else {
	    $self->{Counter}->[$index]->{$_} = 1;
	}
    }
}

sub _generate_prefix {
    my $self = shift;

    my $g_pref = "g$self->{_g_prefix}";
    $self->{_g_prefix}++;

    my @prefixes = $self->{ns_out}->get_prefixes;
    while (grep($_ eq $g_pref, @prefixes)) {
	$g_pref = "g$self->{_g_prefix}";
	$self->{_g_prefix}++;
    }
    return $g_pref;
}

sub _resolve_element {
    my ($self, $i, $aflag) = @_;

    my $out = {};
    my $qname = $self->_expand($i->[1]);
    my $lname = $qname;
    my $pref = undef;
    ($pref, $lname) = split(':', $qname, 2) if index($qname,':') > -1;

    if (defined $i->[2]) {
	my $ns_uri = $self->_expand($i->[2]);
	
	my $pre = $self->{ns}->get_prefix($ns_uri);

	# prefix already declared
	if ($pre) {
	    $out->{Name} = "$pre:$lname";
	    $out->{NamespaceURI} = $ns_uri;
	    $out->{Prefix} = $pre;
	    $out->{LocalName} = $lname;

	# prefix not declared yet
	} else {
	    $pref = $self->_generate_prefix unless $pref; 
	    $out->{Name} = "$pref:$lname";
	    $out->{NamespaceURI} = $ns_uri;
	    $out->{Prefix} = $pref;
	    $out->{LocalName} = $lname;
	}
		
    # namespace not defined	
    } else {
	my @ns = $aflag ? $self->{ns}->process_attribute_name($qname) 
	  : $self->{ns}->process_element_name($qname);
	$self->doError(501, 3, $qname)
	  unless @ns;
	$out->{Name} = $qname;
	$out->{NamespaceURI} = $ns[0] if $ns[0];
	$out->{Prefix} = $ns[1] if $ns[1];
	$out->{LocalName} = $ns[2];
    }
    return $out;
}

sub _get_def_template {
    my $self = shift;

    my $type = $self->{Stack}->[$#{$self->{Stack}}]->{Type};
    my $mode = $self->{Sheet}->{Options}->{'pass-through'};
    #print "STX: default rule: mode->$mode, type->$type\n";
    my $t = {};
    $t->{tid} = 'default';

    my $i_cs = [ I_COPY_START, '#all' ];
    my $i_pc = [ I_P_CHILDREN, undef ];
    my $i_ce = [ I_COPY_END, '#all' ];

    my $ii_e = [];
    my $ii_p = [ $i_pc ];
    my $ii_c = [ $i_cs, $i_ce ];
    my $ii_cpc = [ $i_cs, $i_pc, $i_ce ];

    if ($type == STX_ELEMENT_NODE or $type == STX_ROOT_NODE) {
	if ($mode == 1) {
	    $t->{instructions} = $ii_cpc;
	    #print "STX: default rule: CPC\n";
	} else {
	    $t->{instructions} = $ii_p;
	    #print "STX: default rule: P\n";
	}

    } elsif ($type == STX_TEXT_NODE or $type == STX_CDATA_NODE) {
	if ($mode) {
	    $t->{instructions} = $ii_c;
	    #print "STX: default rule: C\n";
	} else {
	    $t->{instructions} = $ii_e;
	    #print "STX: default rule: E\n";
	}

    } else { # STX_COMMENT_NODE, STX_PI_NODE, STX_ATTRIBUTE_NODE
	if ($mode == 1) {
	    $t->{instructions} = $ii_c;
	    #print "STX: default rule: C\n";
	} else {
	    $t->{instructions} = $ii_e;
	    #print "STX: default rule: E\n";
	}
    }
    return $t;
}

# dynamic retrieval of either variable or buffer sss
sub _get_objects {
    my ($self, $name, $type) = @_;

    my $tp = $type ? 'bufs' : 'vars';
    my $ct = $self->{_c_template}->[$#{$self->{_c_template}}];

    # local object
    return $ct->{$tp}->[$#{$ct->{$tp}}]
      if $ct->{$tp}->[$#{$ct->{$tp}}]->{$name};

    # current group
    my $g = $self->{c_group};
    return $g->{$tp}->[$#{$g->{$tp}}]
      if $g->{$tp}->[$#{$g->{$tp}}]->{$name};

    # descendant groups
    while ($g->{group}) {
	$g = $g->{group};
	return $g->{$tp}->[$#{$g->{$tp}}]
	  if $g->{$tp}->[$#{$g->{$tp}}]->{$name};
    }
    return undef;
}

sub _child_nodes {
    my $self = shift;

    return 1 
      if $self->{Stack}->[$#{$self->{Stack}}]->{Type} == STX_ELEMENT_NODE 
      and $self->{lookahead}->[0] != STXE_END_ELEMENT;

    return 1 
      if $self->{Stack}->[$#{$self->{Stack}}]->{Type} == STX_ROOT_NODE 
      and $self->{lookahead}->[0] != STXE_END_DOCUMENT;

    return 0;
}

# debug ----------------------------------------

sub _frameDBG {
    my $self = shift;

    my $index = scalar @{$self->{Stack}} - 1;
    print "===STACK:$index ";
    foreach (@{$self->{Stack}}) {
	if ($_->{Type} == STX_ELEMENT_NODE) {
	    print "/", $_->{Name};	    
	} elsif ($_->{Type} == STX_TEXT_NODE) {
	    my $norm = $_->{Data};
	    $norm =~ s/\s+/ /g;
	    print "/[text]$norm";	    
	} elsif ($_->{Type} == STX_CDATA_NODE) {
	    my $norm = $_->{Data};
	    $norm =~ s/\s+/ /g;
	    print "/[cdata]$norm";	    
	} elsif ($_->{Type} == STX_COMMENT_NODE) {
	    my $norm = $_->{Data};
	    $norm =~ s/\s+/ /g;
	    print "/[comment]$norm";	    
	} elsif ($_->{Type} == STX_PI_NODE) {
	    my $norm = $_->{Target};
	    $norm =~ s/\s+/ /g;
	    print "/[pi]$norm";	    
	} elsif ($_->{Type} == STX_ROOT_NODE) {
	    print "^";	    
	} else {
	    print "/unknown node: ", $_->{Type};	    
	}
    }
    print "\n";
}

sub _counterDBG {
    my $self = shift;

    my $index = scalar @{$self->{Stack}} - 1;
    print "COUNTER:$index";
     foreach (keys %{$self->{Counter}->[$index]}) {
	 my $cnt = $self->{Counter}->[$index]->{$_};
	 print " $_->$cnt";
     }
    print "\n";
}

sub _nsDBG {
    my $self = shift;

    my @prefixes = $self->{ns}->get_prefixes;
    print "PREFIXES: ", join("|",@prefixes), "\n";

#     foreach (@prefixes) {
# 	my $uri = $self->{ns}->get_uri($_);
# 	print " >$_:$uri\n";
#     }

    my @prefixes2 = $self->{ns_out}->get_prefixes;
    print "RESULT PREFIXES: ", join("|",@prefixes2), "\n";
}

sub _grpDBG {
    my $self = shift;

    print "exG: ";
    foreach my $frm (@{$self->{Stack}}) {
	print "/";
	foreach (@{$self->{exG}->{$frm->{Index}}}) {
	    print "{$_}";
	}
    }
    print "\n";
}

1;
__END__

=head1 NAME

XML::STX - a pure Perl STX processor

=head1 SYNOPSIS

 use XML::STX;

 $stx = XML::STX->new();

 $transformer = $stx->new_transformer($stylesheet_uri);
 $transformer->transform($source_uri);

=head1 DESCRIPTION

XML::STX is a pure Perl implementation of STX processor. Streaming 
Transformations for XML (STX) is a one-pass transformation language for 
XML documents that builds on the Simple API for XML (SAX). See 
http://stx.sourceforge.net/ for more details.

XML::STX makes a use of XML::SAX, XML::NamespaceSupport and Clone as its 
prerequisites. Any SAX2 parser can be used to parse an STX stylesheet. 
XML::SAX::Expat and XML::SAX::PurePerl have been tested successfully. 
Any PerlSAX2 compliant driver or handler can be used as a data source or an 
output handler, respectively.

The current version is an alpha version and it doesn't cover the 
complete STX specification yet.

=head1 USAGE

=head2 Shortcut TrAX-like API

Thanks to various shortcuts of the TrAX-like API, this is the simplest way to 
run transformations. This can be what you want if you are happy with just one
transformation context per stylesheet, and your input data is in files. 
Otherwise, you may want to use some more features of this API 
(see L<Full TrAX-like API|full trax-like api>).

 use XML::STX;

 $stx = XML::STX->new();

 $transformer = $stx->new_transformer($stylesheet_uri);
 $transformer->transform($source_uri);

=head2 Full TrAX-like API

This is the regular interface to XML::STX allowing to run independent 
transformations for single template, bind external parameters,
and associate drivers/handlers with input/output channels.

=for html See <a href="TrAXref.html">TrAX-like API Reference</a> for more details.

 use XML::STX;

 $stx = XML::STX->new();

 $stylesheet = $stx->new_source($stylesheet_uri);
 $templates = $stx->new_templates($stylesheet);
 $transformer = $templates->new_transformer();

 $transformer->{Parameters} = {par1 => 5, par2 => 'foo'}';

 $source = $stx->new_source($source_uri);
 $result = $stx->new_result();

 $transformer->transform($source, $result);

=head2 SAX Filter

 use XML::STX;
 use SAX2Parser;
 use SAX2Handler;

 $stx = XML::STX->new();
 $comp = XML::STX::Compiler->new();
 $parser_t = SAX2Parser->new(Handler => $comp);
 $stylesheet =  $parser_t->parse_uri($templ_uri);

 $writer = XML::SAX::Writer->new();
 $stx = XML::STX->new(Handler => $writer, Sheet => $stylesheet );
 $parser = SAX2Parser->new(Handler => $stx);
 $parser->parse_uri($data_uri);

=head2 Legacy API (deprecated)

 use XML::STX;

 $stx = XML::STX->new();
 $parser_t = SAX2Parser->new();
 $stylesheet = $stx->get_stylesheet($parser_t, $templ_uri);

 $parser = SAX2Parser->new();
 $handler = SAX2Handler->new();
 $stx->transform($stylesheet, $parser, $data_uri, $handler);

=head2 Command-line Interface

XML::STX is shipped with B<stxcmd.pl> script allowing to run STX transformations
from the command line.

Usage: 

 stxcmd.pl [OPTIONS] <stylesheet> <data> [PARAMS]

Run C<stxcmd.pl -h> for more details.

=head1 AUTHOR

Petr Cimprich (Ginger Alliance), petr@gingerall.cz

=head1 SEE ALSO

XML::SAX, XML::NamespaceSupport, perl(1).

=cut
