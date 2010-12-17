package DARLY::kernel;

use Carp;
use AnyEvent;
use Scalar::Util qw( blessed refaddr weaken );
use List::Util qw( first );

use strict;
use warnings;

# Actor class meta
my %META;
# Meta members
use constant CLASS      => 0;
use constant EVENT      => 1;
#use constant TOPIC      => 2;

# Actors and aliases
my (%ACTOR,%ALIAS);
# Actor members
use constant META       => 0;
use constant OBJECT     => 1;
use constant URL        => 2;
use constant ALIAS      => 3;
#use constant SUBS       => 4;

# Connected nodes
my %NODE;

# Open handles
my %HANDLE;

my $loop;
INIT {
    $loop = AE::cv();
    $loop->begin();
}

sub loop {
    $loop->end();
    $loop->recv();
}

sub meta_extend {
    my ($class, $super) = @_;

    no strict 'refs';
    $super //= first { $_->isa('DARLY::actor') } @{"$class\::ISA"};
    croak "Superclass required to extend from"
        if !defined $super;

    $META{$class} = [ $class, { %{$META{$super}[EVENT]} }];
}

sub meta_event {
    my ($class, $event, $code) = (
        ( $_[0]->isa('DARLY::actor')
            ? () : (caller)[0] ),
        @_,
    );

    croak "Class to define event in is required to be actor"
        if !defined $class || !$class->isa('DARLY::actor');

    $META{$class}[EVENT]{$event} = $code;
}

=pod
sub meta_topic {
}
=cut

sub actor_spawn {
    my ($class, $obj, $url) = @_;

    my $actor = [ $META{$class}, $obj, $url, undef ];
    $ACTOR{refaddr $obj} = $actor;
    weaken $actor->[OBJECT] if ref $obj;

    $loop->begin();
}

sub actor_alias {
    my ($obj, $alias) = @_;
    my $actor = $ACTOR{refaddr $obj};
    return if !defined $actor;

    if ( @_ > 1 ) {
        if ( defined $alias ) {
            $ALIAS{$alias}{refaddr $obj} = $obj;
        } else {
            delete $ALIAS{$alias}{refaddr $obj};
            delete $ALIAS{$alias} if !keys %{$ALIAS{$alias}};
        }
        # TODO Update upstream;
    }

    return $actor->[ALIAS];
}

sub actor_shutdown {
    $loop->end();
}

1;

__END__

Meta ::= { Package -> ( Package, EVENTS{ event -> code }, TOPICS{ topic -> 1 } ) }

Actor ::= { refaddr<Obj> -> ( Meta, Obj, Addr, SUBS{ topic -> { refaddr<code> -> code } } ) }

Alias ::= { alias -> { refaddr<Obj> -> Obj } }

Node ::= { Addr -> refaddr<Handle> }

Handle ::= { refaddr<Handle> -> ? }

OutQueue ::= { Addr -> ( N, ? ) }
