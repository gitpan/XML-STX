package XML::STX::Compiler;

require 5.005_62;
use strict;
use warnings;
use XML::STX::Base;
use XML::STX::Stylesheet;
use Clone qw(clone);

@XML::STX::Compiler::ISA = qw(XML::STX::Base);

my $ATT_NUMBER = '\d+(\\.\d*)?|\\.\d+';
my $ATT_URIREF = '[a-z][\w\;\/\?\:\@\&\=\+\$\,\-\_\.\!\~\*\'\(\)\%]+';
my $ATT_STRING = '[\w][\w-]*';
my $ATT_NCNAME = '[A-Za-z_][\w\\.\\-]*';
my $ATT_QNAME  = "($ATT_NCNAME:)?$ATT_NCNAME";
my $ATT_QNAMES = "$ATT_QNAME( $ATT_QNAME)*";

# --------------------------------------------------

sub new {
    my $class = shift;

    my $self = bless {}, $class;
    return $self;
}

# content ----------------------------------------

sub start_document {
    my $self = shift;

    $self->{e_stack} = [];
    $self->{g_stack} = [];
}

sub end_document {
    my $self = shift;

    return $self->{Sheet};
}

sub start_element {
    my $self = shift;
    my $el = shift;

    #print "COMP: $el->{Name}\n";
    $self->doError(201, 3) if $self->{end};

    $el->{vars} = [];

    my $a = exists $el->{Attributes} ? $el->{Attributes} : {};
    my $e_stack_top = $#{$self->{e_stack}} == -1 ? undef 
      : $self->{e_stack}->[$#{$self->{e_stack}}];
    my $g_stack_top = $#{$self->{g_stack}} == -1 ? undef 
      : $self->{g_stack}->[$#{$self->{g_stack}}];

    # STX instructions ==================================================
    if (defined $el->{NamespaceURI} and $el->{NamespaceURI} eq STX_NS_URI) {

	# <stx:transform> ----------------------------------------
	if ($el->{LocalName} eq 'transform') {

	    if ($self->_allowed($el->{LocalName})) {

		$self->{Sheet} = XML::STX::Stylesheet->new();
		push @{$self->{g_stack}}, $self->{Sheet}->{dGroup};
		#print "COMP: >new stylesheet $self->{Sheet}\n";
		#print "COMP: >default group $self->{Sheet}->{dGroup}->{gid}\n";

		$self->doError(212, 3, '<stx:transform>', 'version')
		  unless exists $el->{Attributes}->{'{}version'};

		$self->doError(214, 3, 'version', '<stx:transform>', '1.0')
		  unless $el->{Attributes}->{'{}version'}->{Value} eq STX_VERSION;
	    }
	    #$self->_dump_options;

	# <stx:options> ----------------------------------------
	} elsif ($el->{LocalName} eq 'options') {

	    $self->doError(203, 3, 'stx:options') if $self->{options};

	    if ($self->_allowed($el->{LocalName})) {
		
		if (exists $a->{'{}default-stxpath-namespace'}) {
		    ($a->{'{}default-stxpath-namespace'}->{Value} 
		      =~ /^$ATT_URIREF$/)
		      ? $self->{Sheet}->{Options}->{'default-stxpath-namespace'}
			= $a->{'{}default-stxpath-namespace'}->{Value} 
			  : $self->doError(217, 3, 
				'default-stxpath-namespace', 
				$a->{'{}default-stxpath-namespace'}->{Value}, 
				'uri-reference', );	  
		}

		if (exists $a->{'{}recognize-cdata'}) {
		    if ($a->{'{}recognize-cdata'}->{Value} eq 'no') {
			$self->{Sheet}->{Options}->{'recognize-cdata'} = 0
		    } elsif ($a->{'{}recognize-cdata'}->{Value} ne 'yes') {
			$self->doError(205, 3, 'recognize-data', 
				       $a->{'{}recognize-cdata'}->{Value});
		    }
		}

		if (exists $a->{'{}output-encoding'}) {
		    ($a->{'{}output-encoding'}->{Value} 
		      =~ /^$ATT_STRING$/)
		      ? $self->{Sheet}->{Options}->{'output-encoding'}
			= $a->{'{}output-encoding'}->{Value} 
			  : $self->doError(217, 3, 
					   'output-encoding', 
					   $a->{'{}output-encoding'}->{Value},
					   'string');	  
		}

		if (exists $a->{'{}pass-through'}) {
		    if ($a->{'{}pass-through'}->{Value} eq 'all') {
			$self->{Sheet}->{Options}->{'pass-through'} = 1

		    } elsif ($a->{'{}pass-through'}->{Value} eq 'text') {
			$self->{Sheet}->{Options}->{'pass-through'} = 2

		    } elsif ($a->{'{}pass-through'}->{Value} ne 'none') {
			$self->doError(206, 3, 
				       $a->{'{}pass-through'}->{Value});
		    }
		}
		
		if (exists $a->{'{}strip-space'}) {
		    if ($a->{'{}strip-space'}->{Value} eq 'yes') {
			$self->{Sheet}->{Options}->{'strip-space'} = 1
		    } elsif ($a->{'{}strip-space'}->{Value} ne 'no') {
			$self->doError(205, 3, 'strip-space',
				       $a->{'{}strip-space'}->{Value});
		    }
		}

	    }
	    $self->{options} = 1;
	    #$self->_dump_options;

	# <stx:include> ----------------------------------------
	} elsif ($el->{LocalName} eq 'include') {

	    if ($self->_allowed($el->{LocalName})) {
		#tbd
	    }

	# <stx:namespace-alias> ----------------------------------------
	} elsif ($el->{LocalName} eq 'namespace-alias') {

	    if ($self->_allowed($el->{LocalName})) {
		#tbd
	    }

	# <stx:group> ----------------------------------------
	} elsif ($el->{LocalName} eq 'group') {

	    if ($self->_allowed($el->{LocalName})) {

		my $g = XML::STX::Group->new($self->{Sheet}->{next_gid},
					     $g_stack_top);
		#print "COMP: >new group $self->{Sheet}->{next_gid} $g\n";
		# the group is linked from the previous group
		$g_stack_top->{groups}->{$self->{Sheet}->{next_gid}} = $g;

		if (exists $a->{'{}name'}) {
		    $self->doError(214,3,'name','<stx:group>', 'qname') 
		      unless $a->{'{}name'}->{Value} =~ /^$ATT_QNAME$/;
		    $g->{name} = $a->{'{}name'}->{Value};

		    $self->doError(219, 2, $g->{name}) 
		      if exists $self->{Sheet}->{named_templates}->{$g->{name}};

		    $self->{Sheet}->{named_groups}->{$g->{name}} = $g;
		}

		push @{$self->{g_stack}}, $g;
		$self->{Sheet}->{next_gid}++;
	    }

	# <stx:template> ----------------------------------------
	} elsif ($el->{LocalName} eq'template') {

	    if ($self->_allowed($el->{LocalName})) {

		my $t = XML::STX::Template->new($self->{Sheet}->{next_tid},
						$g_stack_top
					       );

		# --- match ---
		$self->doError(212, 3, '<stx:template>', 'match')
		  unless exists $el->{Attributes}->{'{}match'};

		$t->{match} = $self->tokenize_match($a->{'{}match'}->{Value});

		if ($#{$t->{match}->[0]->[0]->{step}} > -1) {
		    foreach (@{$t->{match}}) {
			if ($_->[$#$_]->{step}->[0] =~ /^@/) {
			    $t->{_att} = 1;
			    $t->{_not_att} = 0;
			} elsif ($_->[$#$_]->{step}->[0] =~ /^node\(\)/) {
			    $t->{_att} = 1;
			    $t->{_not_att} = 1;
			} else {
			    $t->{_att} = 0;
			    $t->{_not_att} = 1;
			}
		    }
		} else { # '/' root
			$t->{_att} = 0;
			$t->{_not_att} = 1;
		}
		#print "COMP: att: $t->{_att}, not att: $t->{_not_att}\n";

		# --- priority ---
		if (exists $a->{'{}priority'}) {
		    $self->doError(214, 3, 'priority', 
				   '<stx:template>', 'number')
		      unless $a->{'{}priority'}->{Value} 
			=~ /^$ATT_NUMBER$/;
		    $t->{priority} = [$a->{'{}priority'}->{Value}];
		    $t->{eff_p} = $a->{'{}priority'}->{Value};
		}
		unless (exists $t->{priority}) {
		    $t->{priority}
		      = $self->match_priority($a->{'{}match'}->{Value});
			
		    if (defined $t->{priority}->[1]) {
			$t->{eff_p} = 10;
			$g_stack_top->{_complex_priority} = 1;
			
		    } else {
			$t->{eff_p} = $t->{priority}->[0];
		    }
		}

		# --- visibility ---
		if (exists $a->{'{}visibility'}) {
			
		    if ($a->{'{}visibility'}->{Value} eq 'public') {
			$t->{visibility} = 2;
			push @{$g_stack_top->{public}}, $t;
			if ($t->{_not_att}) {
			    # the current group can see
			    unshift @{$g_stack_top->{visible}}, $t;
			    # the parent group can see as well
			    unshift @{$self->{g_stack}->[$#{$self->{g_stack}} - 1]->{visible}}, $t if $#{$self->{g_stack}} > 0;
			}
			if ($t->{_att}) { # to match against attributes
			    # the current group can see
			    unshift @{$g_stack_top->{att_visible}}, $t;
			    # the parent group can see as well
			    unshift @{$self->{g_stack}->[$#{$self->{g_stack}} - 1]->{att_visible}}, $t if $#{$self->{g_stack}} > 0;
			}
			    
		    } elsif ($a->{'{}visibility'}->{Value} eq 'global') {
			$t->{visibility} = 3;
			push @{$g_stack_top->{public}}, $t;
			if ($t->{_not_att}) {
			    # visible from any group
			    unshift @{$self->{Sheet}->{global}}, $t;
			    # the current group can see
			    unshift @{$g_stack_top->{visible}}, $t;
			    # the parent group can see as well
			    unshift @{$self->{g_stack}->[$#{$self->{g_stack}} - 1]->{visible}}, $t if $#{$self->{g_stack}} > 0;
			}
			if ($t->{_att}) { # to match against attributes
			    # visible from any group
			    unshift @{$self->{Sheet}->{att_global}}, $t;
			    # the current group can see
			    unshift @{$g_stack_top->{att_visible}}, $t;
			    # the parent group can see as well
			    unshift @{$self->{g_stack}->[$#{$self->{g_stack}} - 1]->{att_visible}}, $t if $#{$self->{g_stack}} > 0;
			}
			
		    } elsif ($a->{'{}visibility'}->{Value} ne 'private') {
			$self->doError(204, 3, 
				       $a->{'{}visibility'}->{Value})
		    }

		} else { # default is 'private'
		    $t->{visibility} = 1;
		    unshift @{$g_stack_top->{visible}}, $t if $t->{_not_att};
		    unshift @{$g_stack_top->{att_visible}}, $t if $t->{_att};
		}
		
		# --- new-scope ---
		if (exists $a->{'{}new-scope'}) {
		    if ($a->{'{}new-scope'}->{Value} eq 'yes') {
			$t->{'new-scope'} = 1
		    } elsif ($a->{'{}new-scope'}->{Value} ne 'no') {
			$self->doError(205, 3, 'new-scope',
				       $a->{'{}new-scope'}->{Value});
		    }
		}
		
		#print "COMP: >new template $self->{Sheet}->{next_tid} $t\n";
		#print "COMP: >matching $t->{match}\n";
		$g_stack_top->{templates}->{$self->{Sheet}->{next_tid}} = $t;

		$self->{c_template} = $t;
		$self->{Sheet}->{next_tid}++;
	    }

	# <stx:procedure> ---------------------------------------- 
        # needs attention !!!

	} elsif ($el->{LocalName} eq'procedure') {

	    if ($self->_allowed($el->{LocalName})) {


	    }

	# <stx:process-children> ----------------------------------------
	} elsif ($el->{LocalName} eq'process-children') {

	    if ($self->_allowed($el->{LocalName})) {

		my $group;
		if (exists $a->{'{}group'}) {
		    $self->doError(214,3,'group','<stx:process-children>',
				   'qname') 
		      unless $a->{'{}group'}->{Value} =~ /^$ATT_QNAME$/;
		    $group = $a->{'{}group'}->{Value};
		}

		push @{$self->{c_template}->{instructions}}, 
		  [I_P_CHILDREN, $group];
		#print "COMP: >PROCESS CHILDREN\n";
	    }

	# <stx:process-attributes> ----------------------------------------
	} elsif ($el->{LocalName} eq'process-attributes') {

	    if ($self->_allowed($el->{LocalName})) {

		my $group;
		if (exists $a->{'{}group'}) {
		    $self->doError(214,3,'group','<stx:process-attributes>',
				   'qname') 
		      unless $a->{'{}group'}->{Value} =~ /^$ATT_QNAME$/;
		    $group = $a->{'{}group'}->{Value};
		}

		push @{$self->{c_template}->{instructions}}, 
		  [I_P_ATTRIBUTES, $group];
		#print "COMP: >PROCESS ATTRIBUTES\n";
	    }

	# <stx:if> ----------------------------------------
	} elsif ($el->{LocalName} eq 'if') {

	    if ($self->_allowed($el->{LocalName})) {

		$self->doError(212, 3, '<stx:if>', 'test')
		  unless exists $a->{'{}test'};

		my $expr = $self->tokenize($a->{'{}test'}->{Value});
		push @{$self->{c_template}->{instructions}},
		  [I_IF_START, $expr];
		#print "COMP: >IF\n";
	    }

	# <stx:else> ----------------------------------------
	} elsif ($el->{LocalName} eq 'else') {

	    if ($self->_allowed($el->{LocalName})) {

		my $last = $self->{c_template}->{instructions}->
		  [$#{$self->{c_template}->{instructions}}]->[0];
		$self->doError(218, 3, 'stx:else', 'stx:if', $last) 
		  if $last != I_IF_END;

		push @{$self->{c_template}->{instructions}}, [I_ELSE_START];
		#print "COMP: >ELSE\n";
	    }

	# <stx:choose> ----------------------------------------
	} elsif ($el->{LocalName} eq 'choose') {

	    if ($self->_allowed($el->{LocalName})) {

		$self->doError(208, 3, 'stx:choose') if $self->{_choose};

		$self->{_choose} = 1;
		#print "COMP: >CHOOSE\n";
	    }

	# <stx:when> ----------------------------------------
	} elsif ($el->{LocalName} eq 'when') {

	    if ($self->_allowed($el->{LocalName})) {

		$self->doError(212, 3, '<stx:when>', 'test')
		  unless exists $a->{'{}test'};

		my $expr = $self->tokenize($a->{'{}test'}->{Value});
		push @{$self->{c_template}->{instructions}},
		  [I_ELSIF_START, $expr];
		#print "COMP: >WHEN\n";
	    }

	# <stx:otherwise> ----------------------------------------
	} elsif ($el->{LocalName} eq 'otherwise') {

	    if ($self->_allowed($el->{LocalName})) {

 		my $last = $self->{c_template}->{instructions}->
 		  [$#{$self->{c_template}->{instructions}}]->[0];
 		$self->doError(218, 3, 'stx:otherwise', 'stx:when', $last)
		  if $last != I_ELSIF_END;

		push @{$self->{c_template}->{instructions}}, [I_ELSE_START];
		#print "COMP: >OTHERWISE\n";
	    }

	# <stx:value-of> ----------------------------------------
	} elsif ($el->{LocalName} eq 'value-of') {

	    if ($self->_allowed($el->{LocalName})) {

		$self->doError(212, 3, '<stx:value-of>', 'select')
		  unless exists $a->{'{}select'};
		
		$self->doError(213, 3, 'select', '<stx:value-of>')
		  if $a->{'{}select'}->{Value} =~ /\{|\}$/;

		my $expr = $self->tokenize($a->{'{}select'}->{Value});
		push @{$self->{c_template}->{instructions}},
		  [I_CHARACTERS, $expr];
		#print "COMP: >CHARACTER\n";
	    }

	# <stx:copy> ----------------------------------------
	} elsif ($el->{LocalName} eq 'copy') {

	    if ($self->_allowed($el->{LocalName})) {
		
		my $attributes = '#all';
		if (exists $a->{'{}attributes'}) {
		    $self->doError(217, 3, 'attributes',
				   $a->{'{}attributes'}->{Value}, 
				   'list of qnames')
		      unless $a->{'{}attributes'}->{Value} 
			=~ /^($ATT_QNAMES|#none|#all)$/ 
			  or $a->{'{}attributes'}->{Value} eq '';

		$attributes = $a->{'{}attributes'}->{Value};
		}
		
		push @{$self->{c_template}->{instructions}}, 
		  [I_COPY_START, $attributes];
		#print "COMP: >COPY_START $attributes\n";
	    }

	# <stx:element> or <stx:start-element> -----------------
	} elsif ($el->{LocalName} eq 'element'
		or $el->{LocalName} eq 'start-element') {

	    if ($self->_allowed($el->{LocalName})) {

		$self->doError(212, 3, "<stx:$el->{LocalName}>", 'name')
		  unless exists $el->{Attributes}->{'{}name'};

		my $qn = $self->_avt($a->{'{}name'}->{Value});

		my $ns; 
		if (exists $a->{'{}namespace'}) {
		    $ns = $self->_avt($a->{'{}namespace'}->{Value});

		} else {
		    $ns = undef;
		}

		push @{$self->{c_template}->{instructions}},
		  [I_ELEMENT_START, $qn, $ns];
		#print "COMP: >ELEMENT_START\n";
	    }

	# <stx:end-element> ----------------------------------------
	} elsif ($el->{LocalName} eq'end-element') {

	    if ($self->_allowed($el->{LocalName})) {

		$self->doError(212, 3, '<stx:end-element>', 'name')
		  unless exists $el->{Attributes}->{'{}name'};

		my $qn = $self->_avt($a->{'{}name'}->{Value});

		my $ns; 
		if (exists $a->{'{}namespace'}) {
		    $ns = $self->_avt($a->{'{}namespace'}->{Value});

		} else {
		    $ns = undef;
		}

		push @{$self->{c_template}->{instructions}},
		  [I_ELEMENT_END, $qn, $ns];
		#print "COMP: >ELEMENT_END\n";
	    }

	# <stx:attribute> ----------------------------------------
	} elsif ($el->{LocalName} eq'attribute') {

	    if ($self->_allowed($el->{LocalName})) {
		
		my $ok;
		my $insts = $self->{c_template}->{instructions};
		for (my $i = 0; $i < @$insts; $i++) {

		    last if $insts->[$#$insts - $i]->[0] == I_ATTRIBUTE_END
		      or $insts->[$#$insts - $i]->[0] == I_ELEMENT_START
			or $insts->[$#$insts - $i]->[0] == I_LITERAL_START
			  or $insts->[$#$insts - $i]->[0] == I_COPY_START;
		    # these instructions don't output anything
		    $self->doError(207, 3, $insts->[$#$insts - $i]->[0]) 
		      unless $insts->[$#$insts - $i]->[0] > 100;
		}

		$self->doError(212, 3, "<stx:$el->{LocalName}>", 'name')
		  unless exists $el->{Attributes}->{'{}name'};

		my $qn = $self->_avt($a->{'{}name'}->{Value});

		my $ns; 
		if (exists $a->{'{}namespace'}) {
		    $ns = $self->_avt($a->{'{}namespace'}->{Value});

		} else {
		    $ns = undef;
		}

		my $sel = exists $a->{'{}select'} ? 
		  $self->tokenize($a->{'{}select'}->{Value}) : undef;

		$self->{_attribute_select} = $sel;
		push @{$self->{c_template}->{instructions}},
		  [I_ATTRIBUTE_START, $qn, $ns, $sel];
		#print "COMP: >ATTRIBUTE_START\n";
	    }

	# <stx:text> ----------------------------------------
	} elsif ($el->{LocalName} eq 'text') {

	    $self->_allowed($el->{LocalName});

	# <stx:cdata> ----------------------------------------
	} elsif ($el->{LocalName} eq 'cdata') {

	    if ($self->_allowed($el->{LocalName})) {

		push @{$self->{c_template}->{instructions}}, 
		  [I_CDATA_START];
		#print "COMP: >CDATA_START\n";
	    }

	# <stx:comment> ----------------------------------------
	} elsif ($el->{LocalName} eq'comment') {

	    if ($self->_allowed($el->{LocalName})) {
		
		push @{$self->{c_template}->{instructions}}, 
		  [I_COMMENT_START];
		#print "COMP: >COMMENT_START\n";
	    }

	# <stx:processing-instruction> -----------------------------------
	} elsif ($el->{LocalName} eq'processing-instruction') {

	    if ($self->_allowed($el->{LocalName})) {

		$self->doError(212, 3, "<stx:$el->{LocalName}>", 'name')
		  unless exists $el->{Attributes}->{'{}name'};

		my $target = $self->_avt($el->{Attributes}->{'{}name'}->{Value});

		push @{$self->{c_template}->{instructions}}, 
		  [I_PI_START, $target];
		#print "COMP: >PI_START\n";
	    }

	# <stx:variable> ----------------------------------------
	} elsif ($el->{LocalName} eq 'variable') {

	    if ($self->_allowed($el->{LocalName})) {
		
		$self->doError(212, 3, "<stx:$el->{LocalName}>", 'name')
		  unless exists $el->{Attributes}->{'{}name'};

		$self->doError(217, 3, 'name', 
			       $a->{'{}name'}->{Value}, 'qname')
		  unless $a->{'{}name'}->{Value} =~ /^($ATT_QNAME)$/;

		my $name = $a->{'{}name'}->{Value};

		my $select;
		my $default_select;
		if (exists $a->{'{}select'}) {
		    $self->doError(213, 3, 'select', '<stx:variable>')
		      if $a->{'{}select'}->{Value} =~ /\{|\}$/;
		    $select = $self->tokenize($a->{'{}select'}->{Value});
		    $default_select = 0;
		} else {
		    $select = ['(',')'];
		    $default_select = 1;
		}

		$self->{_variable_select} = $select;

		# local variable ------------------------------
		if ($self->{c_template}) {

		    # variable already declared
		    $self->doError(211, 3, 'Local', "\'$name\'") 
		      if exists $self->{c_template}->{vars}->[0]->{$name};

		    push @{$e_stack_top->{vars}}, $name;
		    $self->{c_template}->{vars}->[0]->{$name} = [];

		    push @{$self->{c_template}->{instructions}}, 
		      [I_VARIABLE_START, $name, $select, $default_select];
		    #print "COMP: >VARIABLE_START\n";

		# group variable ------------------------------
		} else {

		    # variable already declared
		    $self->doError(211, 3, 'Group', "\'$name\'") 
		      if $self->{c_group}->{vars}->[0]->{$name};

		    my $keep_value = 0; 
 		    if (exists $a->{'{}keep-value'}) {
 			if ($a->{'{}keep-value'}->{Value} eq 'yes') {
 			    $keep_value = 1
 			} elsif ($a->{'{}keep-value'}->{Value} ne 'no') {
 			    $self->doError(205, 3, 'keep-value',
 					   $a->{'{}keep-value'}->{Value});
 			}
 		    }

		    # actual value
		    $g_stack_top->{vars}->[0]->{$name}->[0]
		      = $self->_static_eval($select);
		    # init value
		    $g_stack_top->{vars}->[0]->{$name}->[1]
		      = clone($g_stack_top->{vars}->[0]->{$name}->[0]);
		    # keep value
		    $g_stack_top->{vars}->[0]->{$name}->[2]
		      = $keep_value;
 		    #print "COMP: >GROUP_VARIABLE\n";

		}

	    }

	# <stx:assign> ---------------------------------------- zzz
	} elsif ($el->{LocalName} eq 'assign') {

	    if ($self->_allowed($el->{LocalName})) {
		
		$self->doError(212, 3, "<stx:$el->{LocalName}>", 'name')
		  unless exists $el->{Attributes}->{'{}name'};

		$self->doError(217, 3, 'name', 
			       $a->{'{}name'}->{Value}, 'qname')
		  unless $a->{'{}name'}->{Value} =~ /^($ATT_QNAME)$/;

		my $name = $a->{'{}name'}->{Value};

		my $select;
		if (exists $a->{'{}select'}) {
		    $self->doError(213, 3, 'select', '<stx:assign>')
		      if $a->{'{}select'}->{Value} =~ /\{|\}$/;
		    $select = $self->tokenize($a->{'{}select'}->{Value});
		}

		$self->{_variable_select} = $select;

		push @{$self->{c_template}->{instructions}},
		  [I_ASSIGN_START, $name, $select];
		#print "COMP: >ASSIGN_START\n";
	    }


	} else {
	    $self->doError(209, 3, "<stx:$el->{LocalName}>")
	}

    # literals ==================================================
    } else {
	
	if ($self->_allowed('_literal')) {
	    my $i = [I_LITERAL_START, $el];

	    # tokenize AVT in attributes
	    if (exists $i->[1]->{Attributes}) {
		foreach (keys %{$i->[1]->{Attributes}}) {
		    $i->[1]->{Attributes}->{$_}->{Value} 
		      = $self->_avt($i->[1]->{Attributes}->{$_}->{Value});
		}
	    }
		
	    push @{$self->{c_template}->{instructions}}, $i;
	    #print "COMP: >LITERAL_START $el->{Name}\n";

	} else {
	    $self->doError(210, 3, $el->{Name}) 
	      unless $el->{NamespaceURI};
	}
    }

    push @{$self->{e_stack}}, $el;
}

sub end_element {
    my $self = shift;
    my $el = shift;

    #print "COMP: \/$el->{Name}\n";

    # STX instructions ==================================================
    if (defined $el->{NamespaceURI} and $el->{NamespaceURI} eq STX_NS_URI) {

	# <stx:transform> ----------------------------------------
	if ($el->{LocalName} eq 'transform') {
	    # nothing else is allowed
	    $self->_sort_templates($self->{Sheet}->{dGroup}->{visible});
	    $self->_sort_templates($self->{Sheet}->{global});
	    $self->{end} = 1;

	# <stx:variable> ----------------------------------------
	} elsif ($el->{LocalName} eq 'variable') {

	    # local variable
	    if ($self->{c_template}) {
		# select and content in the same time
# 		$self->doError(208, 3, 'stx:variable') 
# 		  if $self->{_variable_select} and $self->{c_template}->{instructions}->[$#{$self->{c_template}->{instructions}}]->[0] != I_VARIABLE_START;
		
		push @{$self->{c_template}->{instructions}}, [I_VARIABLE_END];
		#print "COMP: >VARIABLE_END\n";
	    } else {
		# kontrola pres lookahead
	    }
	    
	# <stx:assign> ----------------------------------------
	} elsif ($el->{LocalName} eq 'assign') {

	    # select and content in the same time
# 	    $self->doError(208, 3, 'stx:assign') 
# 	      if $self->{_variable_select} and $self->{c_template}->{instructions}->[$#{$self->{c_template}->{instructions}}]->[0] != I_ASSIGN_START;
		
	    push @{$self->{c_template}->{instructions}}, [I_ASSIGN_END];
	    #print "COMP: >ASSIGN_END\n";

	# <stx:group> ----------------------------------------
	} elsif ($el->{LocalName} eq 'group') {
	    #$self->_dump_g_stack;
	    my $g = pop @{$self->{g_stack}};
	    $self->_sort_templates($g->{visible});

	# <stx:template> ----------------------------------------
	} elsif ($el->{LocalName} eq 'template') {
	    $self->{c_template} = undef;

	# <stx:copy> ----------------------------------------
	} elsif ($el->{LocalName} eq 'copy') {

	    push @{$self->{c_template}->{instructions}}, [I_COPY_END];
	    #print "COMP: >COPY_END\n";

	# <stx:element> ----------------------------------------
	} elsif ($el->{LocalName} eq 'element') {

	    push @{$self->{c_template}->{instructions}}, [I_ELEMENT_END];
	    #print "COMP: >ELEMENT_END /$el->{Name}\n";

	# <stx:attribute> ----------------------------------------
	} elsif ($el->{LocalName} eq 'attribute') {

	    push @{$self->{c_template}->{instructions}}, [I_ATTRIBUTE_END];
	    #print "COMP: >ATTRIBUTE_END\n";

        # <stx:cdata> ----------------------------------------
	} elsif ($el->{LocalName} eq 'cdata') {

	    push @{$self->{c_template}->{instructions}}, [I_CDATA_END];
	    #print "COMP: >CDATA_END\n";

        # <stx:comment> ----------------------------------------
	} elsif ($el->{LocalName} eq 'comment') {

	    push @{$self->{c_template}->{instructions}}, [I_COMMENT_END];
	    #print "COMP: >COMMENT_END\n";

        # <stx:processing-instruction> -----------------------------------
	} elsif ($el->{LocalName} eq 'processing-instruction') {

	    push @{$self->{c_template}->{instructions}}, [I_PI_END];
	    #print "COMP: >PI_END\n";

	# <stx:if> ----------------------------------------
	} elsif ($el->{LocalName} eq 'if') {

	    push @{$self->{c_template}->{instructions}}, [I_IF_END];
	    #print "COMP: >IF_END\n";

	# <stx:else> ----------------------------------------
	} elsif ($el->{LocalName} eq 'else') {

	    push @{$self->{c_template}->{instructions}}, [I_ELSE_END];
	    #print "COMP: >ELSE_END\n";

	# <stx:choose> ----------------------------------------
	} elsif ($el->{LocalName} eq 'choose') {

	    $self->{_choose} = undef;
	    #print "COMP: >CHOOSE_END\n";

	# <stx:when> ----------------------------------------
	} elsif ($el->{LocalName} eq 'when') {

	    push @{$self->{c_template}->{instructions}}, [I_ELSIF_END];
	    #print "COMP: >WHEN_END\n";

	# <stx:otherwise> ----------------------------------------
	} elsif ($el->{LocalName} eq 'otherwise') {

	    push @{$self->{c_template}->{instructions}}, [I_ELSE_END];
	    #print "COMP: >OTHERWISE_END\n";

	}

	# end tags for empty elements (process-children/self/attributes)
	# can be happily ignored, their emptiness is checked elsewhere

    # literals
    } else {

	push @{$self->{c_template}->{instructions}}, [I_LITERAL_END, $el];
	#print "COMP: >LITERAL_END /$el->{Name}\n";
    }

    # end of local variable visibility
    my $e = pop @{$self->{e_stack}};
    foreach (@{$e->{vars}}) {
	push @{$self->{c_template}->{instructions}}, 
	  [I_VARIABLE_SCOPE_END, $_];
	$self->{c_template}->{vars}->[0]->{$_} = undef;
	#print "COMP: >VARIABLE_SCOPE_END $_\n";
    }
}

sub characters {
    my $self = shift;
    my $char = shift;

    # whitespace only
    if ($char->{Data} =~ /^\s*$/) {
	my $parent = $self->{e_stack}->[$#{$self->{e_stack}}];
	if ($parent->{NamespaceURI} eq STX_NS_URI
	   and $parent->{LocalName} =~ /^(text|cdata)$/) {

	    if ($self->_allowed('_text')) {
		push @{$self->{c_template}->{instructions}},
		  [I_CHARACTERS, $char->{Data}];
		#print "COMP: >CHARACTERS - $char->{Data}\n";
	    }
	}

    # not whitespace only
    } else {
	if ($self->_allowed('_text')) {
	    push @{$self->{c_template}->{instructions}},
	      [I_CHARACTERS, $char->{Data}];
	    #print "COMP: >CHARACTERS - $char->{Data}\n";
	}	
    }
}

sub processing_instruction {
    my $self = shift;
    my $pi = shift;
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
}

sub end_cdata {
    my $self = shift;
}

sub comment {
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

# static evaluation ----------------------------------------

sub _static_eval {
    my ($self, $val) = @_;

    my $spath = XML::STX::STXPath->new();
    my $seq = $spath->expr(undef, $val);

    return $seq;
}

# tokenize ----------------------------------------

sub tokenize_match {
    my ($self, $pattern) = @_;
    my $tokens = [];

    foreach my $path (split('\|',$pattern)) {

	my $steps = [];

	$path =~ s/^\/\///g;
	$path =~ s/^\//&R/g;
	$path =~ s/\/\//&&&A/g;
	$path =~ s/\//&&&P/g;
	$path = '&N' . $path unless substr($path,0,2) eq '&R';

	foreach (split('&&', $path)) {
	    my $left = substr($_,1,1);
	    my $step = $self->tokenize(substr($_,2));
	    push @$steps, { left => $left, step => $step};
	}
	push @$tokens, $steps;
    }
    return $tokens;
}

sub match_priority {
    my ($self, $pattern) = @_;
    my $priority = [];

    foreach my $path (split('\|',$pattern)) {

	my @steps = split('/|//',$path);
	my $last = $steps[$#steps];
	my $p = 0.5;

	if ($#steps == 0) {

	    if ($last =~ /^($AXIS_NAME)?$QName$/) {
		$p = 0;
		
	    } elsif ($last =~ /^processing-instruction\(?:$LITERAL\)$/) {
		$p = 0;

	    } elsif ($last =~ /^cdata\(\)$/) {
		$p = 0;
		
	    } elsif ($last =~ /^(?:$AXIS_NAME)?(?:$NCWild)$/) {
		$p = -0.25;
		
	    } elsif ($last =~ /^(?:$AXIS_NAME)?(?:$QNWild)$/) {
		$p = -0.25;
		
	    } elsif ($last =~ /^(?:$AXIS_NAME)?$NODE_TYPE$/) {
		$p = -0.5;
	    }
	}
	#print "TOK: last step: $last, more steps: $#steps, priority: $p\n";
	push @$priority, $p;
    }
    return $priority;
}

sub tokenize {
    my ($self, $path) = @_;
    study $path;

    my @tokens = ();
    #print "TOK: tokenizing: $path\n";
    
    while($path =~ m/\G
        \s* # ignore all whitespace
        ( # tokens
            $LITERAL|
            $DOUBLE_RE| # Match double numbers
            $NUMBER_RE| # Match digits
            \.\.| # match parent
            \.| # match current
            $AXIS_NAME| # match axis
            $NODE_TYPE| # match node type
            processing-instruction|
            \@($NCWild|$QName|$QNWild)| # match attrib
            \$$QName| # match variable reference
            $NCWild|$QName|$QNWild| # NCName,NodeType
            \!=|<=|\-|>=|\/\/|and|or|mod|div| # multi-char seps
            [,\+=\|<>\/\(\[\]\)]| # single char seps
            (?<!(\@|\(|\[))\*| # multiply operator rules (see xpath spec)
            (?<!::)\*|
	    $FUNCTION|
            $ # match end of query
        )
        \s* # ignore all whitespace
        /gcxso) {

        my ($token) = ($1);

        if (length($token)) {
            #print "TOK: token: $token\n";
            push @tokens, $token;
        }
    }
    
    if (pos($path) < length($path)) {
        my $marker = ("." x (pos($path)-1));
        $path = substr($path, 0, pos($path) + 8) . "...";
        $path =~ s/\n/ /g;
        $path =~ s/\t/ /g;
	$self->doError(1, 3, $path, $marker);
    }
    return \@tokens;
}

# structure ----------------------------------------

my $s_group = ['variable','template','procedure','include','group'];

my $s_top_level = [@$s_group, 'options', 'namespace-alias'];

my $s_text_constr = ['text','cdata','value-of','if','else','choose','_text'];

my $s_content_constr = [@$s_text_constr ,'call-template', 'copy',
			  'process-attributes', 'process-self','element',
			  'start-element','end-element', 'processing-instruction',
			  'comment','variable','param', 'assign','for-each',
			  '_literal','attribute'];

my $s_template = [@$s_content_constr, 'process-children'];

my $sch = {
	   transform => $s_top_level,
	   group => $s_group,
	   template => $s_template,
	   procedure => $s_template,
	   'call-template' => ['with-param'],
	   'with-param' => $s_text_constr,
	   param => $s_text_constr,
	   copy => $s_template,
	   element => $s_template,
	   attribute => $s_text_constr,
	   'processing-instruction' => $s_text_constr,
	   comment => $s_text_constr,
	   'if' => $s_template,
	   'else' => $s_template,
	   choose => ['when','otherwise'],
	   when => $s_template,
	   otherwise => $s_template,
	   'for-each' => $s_template,
	   variable => $s_text_constr,
	   assign => $s_text_constr,
	   text => ['_text'],
	   cdata => ['_text'],
	   _literal => $s_template,
	  };

sub _allowed {
    my ($self, $lname) = @_;

    if ($#{$self->{e_stack}} == -1) {

	$self->doError(202, 3, $lname) 
	  unless $lname eq 'transform';

    } else {
	my $parent = $self->{e_stack}->[$#{$self->{e_stack}}];

	my $s_key = (defined $parent->{NamespaceURI} 
	  and $parent->{NamespaceURI} eq STX_NS_URI)
	  ? $parent->{LocalName} : '_literal';

	$self->doError(215, 3, $lname, $parent->{Name})
	  unless grep($_ eq $lname ,@{$sch->{$s_key}});
    }
    return 1;
}

# utils ----------------------------------------

sub _avt {
    my ($self, $val) = @_;

    if ($val =~ /^\{([^\}\{]*)\}$/) {
	return $self->tokenize($1);

    } elsif ($val =~ /^.*\{([^\}\{]*)\}.*$/) {
	$val =~ s/^(.*)$/concat('$1')/;
	$val =~ s/\{/',/g;
	$val =~ s/\}/,'/g;
	$val =~ s/'',|,''//g;
	return $self->tokenize($val);

    } else {
	return $val;	
    }
}

sub _sort_templates {
    my ($self, $t) = @_;
    my $sorted = 1;

    while ($sorted) {
	$sorted = 0;
	for (my $i=0; $i < $#$t; $i++) {
	    if ($t->[$i+1]->{eff_p} > $t->[$i]->{eff_p}) {
		my $tmp = $t->[$i];
		$t->[$i] = $t->[$i+1];
		$t->[$i+1] = $tmp;
		$sorted = 1;
	    }
	}
    }
}

# debug ----------------------------------------

sub _dump_options {
    my $self = shift;

    print join("\n", 
	       map("$_=$self->{Sheet}->{Options}->{$_}",
		   keys %{$self->{Sheet}->{Options}})), 
		     "\n";
}

sub _dump_g_stack {
    my $self = shift;

    print "G-stack:", 
      join('|',map("$_->{gid}",@{$self->{g_stack}})), "\n";
}

1;
__END__

=head1 NAME

XML::STX::Compiler - XML::STX stylesheet compiler

=head1 SYNOPSIS

no public API, used from XML::STX

=head1 AUTHOR

Petr Cimprich (Ginger Alliance), petr@gingerall.cz

=head1 SEE ALSO

XML::STX, perl(1).

no public API


=cut
