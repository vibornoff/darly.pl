package DARLY::future;

use AnyEvent;

use strict;
use warnings;

require DARLY::kernel;

sub new {
    my $code = $_[-1];
    return bless sub { };
}

sub DESTROY {
}

1;
