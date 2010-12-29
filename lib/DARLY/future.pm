package DARLY::future;
use base 'DARLY::actor';

use AnyEvent;
use Scalar::Util qw( refaddr );

use strict;
use warnings;

use constant CV     => 0;
use constant CODE   => 1;

my %INNER;

sub new {
    my $class = shift; $class = ref $class || $class;
    my $inner = [ AE::cv(), @_ ];
    my $self = bless sub { $inner->[CV]->send( 'result', [ $inner->[CODE]->(@_) ] ) }, $class;
    $INNER{refaddr $self} = $inner;
    return $self;
}

sub DESTROY {
    my $self = shift;
    my $inner = delete $INNER{refaddr $self};
    $self->shutdown();
    $inner->[CV]->send( $inner->[CODE]->() );
}

sub result {
    my $self = shift; shift; # sender
    my $inner = $INNER{refaddr $self};
    $inner->[CV]->send( 'result', [ $inner->[CODE]->(@_) ] );
}

sub error {
    my $self = shift;  shift; # sender
    my $inner = $INNER{refaddr $self};
    local $@ = $_[-1];
    $inner->[CV]->send( 'error', [ $inner->[CODE]->(@_) ] );
}

sub cv {
    my $self = shift;
    my $inner = $INNER{refaddr $self};
    return $inner->[CV];
}

1;
