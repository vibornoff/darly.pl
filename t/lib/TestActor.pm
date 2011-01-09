package TestActor;

use AnyEvent;
use DARLY;

use strict;
use warnings;

our $testvar;

event 'foo' => sub {
    $testvar = $_[-1];
};

event 'bar' => sub {
    shift;
    $testvar = $_[0];
};

event 'echo' => sub {
    my (undef, $arg) = @_;
    return $arg;
};

event 'delayed_echo' => sub {
    my (undef, $delay, $arg) = @_;
    my ($t,$f); $t = AE::timer $delay, 0, $f = 'DARLY::future'->new(sub{ undef $t; return $arg });
    return $f;
};

# TODO dying event handler

event 'bye' => sub {
    DARLY::shutdown();
};

1;
