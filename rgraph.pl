use strict;
use warnings;
use utf8;
use XML::Parser;
use XML::Twig;
use JSON;
use Data::Dumper;

use Data::Dumper::AutoEncode;

use Tree::DAG_Node::XPath;
use Encode;


#binmode STDOUT, 'utf8';

my $xmlfile = shift @ARGV;              # the file to parse

# initialize parser object and parse the string
my $parser = XML::Parser->new( ErrorContext => 2 );
eval { $parser->parsefile( $xmlfile ); };

# report any error that stopped parsing, or announce success
if( $@ ) {
    $@ =~ s/at \/.*?$//s;               # remove module line number
    print STDERR "\nERROR in '$xmlfile':\n$@\n";
} else {
    print STDERR "'$xmlfile' is well-formed\n";
}
my $names;
my $familys;
my %persons;
my %familys;
my %parentin;
$familys=0;
$names=0;
my $t= XML::Twig->new( twig_handlers => 
                          { person => \&person,
                          	family => \&family,
                          },
                       );
  $t->parsefile( $xmlfile);

  # the handler is called once a person is completely parsed, ie when 
  # the end tag for person is found, it receives the twig itself and
  # the element (including all its sub-elements) as arguments
  sub person 
    { my( $t, $person)= @_;      # arguments for all twig_handlers
      #$person->set_tag( 'div');  # change the tag person
      # let's use the attribute nb as a prefix to the title
      my $first= $person->first_child( 'name')->field('first'); # find first name
      my $nick= $person->first_child( 'name')->field('nick'); # find nick name
      my $childof = $person->first_child('childof');
      my $parentin = $person->first_child('parentin');
      my $gender = $person->field('gender');
      #my $nb= $title->{'att'}->{'nb'}; # get the attribute
      my $handle = $person->{'att'}->{'handle'};  # easy isn't it?
      my $childofhandle = $childof->{'att'}->{'hlink'};
      my $parentinhandle = $parentin->{'att'}->{'hlink'};
      if ($parentinhandle) {
        $parentin{$parentinhandle} = $handle;
      }
      $persons{$handle}{name} = $first;
      $persons{$handle}{nick} = $nick;
      $persons{$handle}{childof} = $childofhandle;
      $persons{$handle}{gender} = ($gender eq 'M') ? 'blue' : 'pink';
      $person->purge;            # outputs the person and frees memory
      $names++;
    }

 # the handler is called once a family is completely parsed, ie when 
  # the end tag for family is found, it receives the twig itself and
  # the element (including all its sub-elements) as arguments
  sub family 
    { my( $t, $family)= @_;      # arguments for all twig_handlers
      #$family->set_tag( 'div');  # change the tag family
      # let's use the attribute nb as a prefix to the title
      my $father= $family->first_child( 'father'); # find the title
      #my $nb= $title->{'att'}->{'nb'}; # get the attribute
      #$father->prefix( "$nb - ");  # easy isn't it?
      $family->purge;            # outputs the family and frees memory
      $familys++;
    }

my %jsonhash;
my %jsonhashwithnickname;
my @jsonarray;
my @jsonarraywithnickname;
my %allitems;

my %descendents;
my $gTree;
my $treename;
my %rparentin = reverse %parentin;

for my $handle (sort keys %persons) {
#	print "The handle: '$handle''s first name: $persons{$handle}{name} and childof: $persons{$handle}{childof}\n";
    if ($persons{$handle}{childof}) {
		  push (@{$descendents{$persons{$handle}{childof}}}, $handle);    	
    } else {
      $treename=$handle;
      $gTree = Tree::DAG_Node::XPath->new({name => $handle, attributes => {name => $persons{$handle}{name}}});
    }
}
# print Dumper \$gTree;
my $found=1;

while ($found) {
  $found=0;
  my @leafs;
  $gTree->walk_down({
      callback => sub {
          my $node = shift;
              
              if (!$node->daughters()) {
                push(@leafs, $node);
              }
              return 1;

          },
      _depth => 0,
      treename => $treename 
  });

  foreach (@leafs) {  #for each leaf node add any children found
    my $curnode = $_;
    my $parentkey = $rparentin{$curnode->name};
    if ($parentkey) {
      for my $nodeTo (@{$descendents{$parentkey}}) { 
        #print $nodeTo . "\n";
        $curnode->add_daughter(Tree::DAG_Node::XPath -> new({name => $nodeTo, attributes => {name => $persons{$nodeTo}{nick}}}));  
        $found = 1;
      }

    }
    #print "found root: ", $curnode->name, " child: ", $nodeTo, "\n"; 
    #$curnode->add_daughter(Tree::DAG_Node::XPath -> new({name => $nodeTo, attributes => {uid => 1, name => $persons{$nodeTo}{name}}}));  
  }

}

 
my $itemcount;
$itemcount=0;
my %allnode;
    my $i;
my $alljsondata;

sub traverse {
    my $node = shift;
    my $depth = scalar $node->ancestors || 0;
    my %entry;

    # a pre-order traversal. First we do something ...
    #print ".." x $depth, $node->name," ", $node->address, "\n";
    $allnode{$node->address} = $node->name;
     # ... and then we recurse the subodes
     #$allnode=$allnode + $node;
    #print " " x $depth, $node->name," ", '<' . $node->name . '>' . $i++ . "\n";
    # print " " x $depth, '{' . "\n" .
    #     " " x 2 x $depth, 'id: "' . $node->name . '",' . "\n" .
    #     " " x 2 x $depth, 'name: "' . $node->attributes->{name} . '",' . "\n";
    $alljsondata .= '{' .
        '"id": "' . $node->name . '",' .
        '"name": "' . $node->attributes->{nick} . '",';

   if ($node->daughters) {
      my @daughters = $node->daughters;
      my @list = map {$_->name => "<li>$_->nick</li>"} @daughters;
      #print @list . "\n";
      my $nodes = $node->daughters; #try to find this node in the tree
      
      #foreach (@list) { print "found root: ", $_, "\n"; }
      # print " " x 2 x $depth, 'data: {' . 
      #               'relation: "<b>Children:</b><ul>';
      $alljsondata .= '"data": {' . 
                    '"relation": "<b>Children:</b><ul>';
      #foreach (@daughters) {  #for each child add a daughter node to this mother node
       # my $curnode = $_;
       # print '<li>' . $curnode->attributes->{name}. "</li>"; 
      #}
      # print map {"<li>" . $_->attributes->{name} . "</li>"} @daughters;
      # print '</ul>"';
      # print " " x $depth, '},' . "\n";
      # print " " x $depth;      
      $alljsondata .= join('',map {"<li>" . $_->attributes->{nick} . "</li>"} @daughters);
      $alljsondata .= '</ul>"';
      $alljsondata .= '},';
    }

    # print    " " x 2 x $depth, 'children: [';
    $alljsondata .= '"children": [';
    traverse($_) for $node->daughters;
    $i--;
    # if ($node->daughters) {
    #   print " " x $depth;
    # }
 
    if ($node->right_sister()) {
      # print ']' . '},' . "\n";
      $alljsondata .= ']' . '},';      
    } else {
      # print ']' . '}' . "\n";
      $alljsondata .= ']' . '}';

    }
    #print " " x $depth, $node->name," ", '</' . $node->name . '>' . "\n";
}
#print $allnode;
&traverse($gTree);
 # print $gTree->tree_to_lol_notation({ multiline => 1 });
#print Dumper \%allnode;
#print $alljsondata;
my $descendents_json = JSON->new->allow_nonref->pretty->decode($alljsondata);

#print JSON->new->allow_nonref->pretty->decode($descendents_json);
our $VAR1;
my $temparray=eDumper($descendents_json);
# print $temparray;
eval $temparray;
# print $VAR1;
print JSON->new->pretty->encode($VAR1);

#print Dumper \@jsonarray;
#print $descendents_json;
#print $descendentswithnickname_json;
#print Dumper \%jsonhash;
#print Dumper \$gTree;
#print map("$_\n", @{$gTree->draw_ascii_tree});