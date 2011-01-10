package DARLY::future;
use base 'DARLY::actor';

use Carp;
use AnyEvent;
use Scalar::Util qw( refaddr reftype );

use strict;
use warnings;

use constant CV => 0;
use constant CB => 1;

my %INNER;

sub _fire {
    my ($inner,$event) = splice @_, 0, 2;
    $inner->[CV]->send( $event, [
        $inner->[CB] ? ( $inner->[CB]->(@_) )
                     : ( ),
    ]);
}

sub new {
    my $class = shift; $class = ref $class || $class;
    my $cb = shift;

    croak "Argument is not a CODE reference"
        if ref $cb && reftype $cb ne 'CODE';

    my $inner = [ AE::cv(), $cb ];
    my $self = bless sub { _fire( $inner, 'result', @_ ) }, $class;
    $INNER{refaddr $self} = $inner;

    return $self;
}

sub DESTROY {
    my $self = shift;
    my $inner = delete $INNER{refaddr $self};

    $self->shutdown();

    unless ( $inner->[CV]->ready ) {
        $inner->[CB]->() if $inner->[CB];
        $inner->[CV]->send();
    }
}

sub result {
    my $self = shift; shift; # sender
    my $inner = $INNER{refaddr $self};
    _fire( $inner, 'result', @_ );
}

sub error {
    my $self = shift;  shift; # sender
    my $inner = $INNER{refaddr $self};
    local $@ = $_[-1];
    _fire( $inner, 'error', @_ );
}

sub cv {
    my $self = shift;
    my $inner = $INNER{refaddr $self};
    return $inner->[CV];
}

1;
