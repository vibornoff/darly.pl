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
