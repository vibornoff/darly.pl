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
    splice @_, 0, 2;
    return @_;
};

event 'delayed_echo' => sub {
    my ($self, $sender, $delay, $arg) = @_;
    my ($t,$f); $t = AE::timer $delay, 0, $f = future { undef $t; return $arg };
    return $f;
};

event 'proxy_echo' => sub {
    my ($self, $sender, $arg) = @_;
    return $self->request( undef, 'echo', [ $arg ]);
};

event 'check_context' => sub {
    $testvar = wantarray;
};

# TODO dying event handler

event 'bye' => sub {
    DARLY::shutdown();
};

1;
