package DARLY::future;

use AnyEvent;

use strict;
use warnings;

require DARLY::kernel;
require DARLY::actor;
BEGIN {
    no strict 'refs';
    push @{'DARLY::future::ISA'}, 'DARLY::actor';
    DARLY::kernel::meta_event( __PACKAGE__, 'default', \&default );
    DARLY::kernel::meta_event( __PACKAGE__, 'error', \&error );
    DARLY::kernel::meta_extend( __PACKAGE__, 'DARLY::actor' );
}

sub new {
    my $self = bless [ AE::cv(), @_ ];
    return $self;
}

sub DESTROY {
    my $self = shift;
    $self->[0]->send( $self->[1]->() );
}

sub default {
}

sub error {
}

1;
