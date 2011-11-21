package TestActor;

use AnyEvent;
use DARLY;

use strict;
use warnings;

our $testvar;

on 'foo' => sub {
    $testvar = $_[-1];
};

on 'bar' => sub {
    $testvar = $_[0];
};

on 'echo' => sub {
    shift;
    return @_;
};

on 'delayed_echo' => sub {
    my ($self, $delay, $arg) = @_;
    my ($t,$f); $t = AE::timer $delay, 0, $f = future { undef $t; return $arg };
    return $f;
};

on 'proxy_echo' => sub {
    my ($self, $arg) = @_;
    return $self->request( undef, 'echo', [ $arg ]);
};

on 'check_context' => sub {
    $testvar = wantarray;
};

# TODO dying event handler

on 'bye' => sub {
    DARLY::shutdown();
};

1;
