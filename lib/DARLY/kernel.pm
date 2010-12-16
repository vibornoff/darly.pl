package DARLY::kernel;

use AnyEvent;

use strict;
use warnings;

my $loop;
INIT {
    $loop = AE::cv();
    $loop->begin();
}

sub loop {
    $loop->end();
    $loop->recv();
}

sub spawn_actor {
    $loop->begin();
}

sub shutdown_actor {
    $loop->end();
}

1;

__END__

Meta ::= { Package -> ( Package, EVENTS{ event -> code }, TOPICS{ topic -> 1 } ) }

Actor ::= { refaddr<Obj> -> ( Meta, Obj, Addr, SUBS{ topic -> { refaddr<code> -> code } } ) }

Node ::= { Addr -> refaddr<Handle> }

Handle ::= { refaddr<Handle> -> ? }
