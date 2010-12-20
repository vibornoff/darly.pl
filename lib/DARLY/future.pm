package DARLY::future;

use AnyEvent;

use strict;
use warnings;

sub new {
    my $self = bless [ AE::cv(), @_ ];
    return $self;
}

sub DESTROY {
    my $self = shift;
    $self->[0]->send( $self->[1]->() );
}

sub result {
    my $self = shift;
    $self->[1]->(@_);
}

sub error {
    my $self = shift;
    local $@ = $_[1];
    $self->[1]->(@_);
}

1;
