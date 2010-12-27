package DARLY::error;

use strict;
use warnings;

use constant ERROR  => 0;
use constant MESSAGE => 1;
use constant FILE   => 2;
use constant LINE   => 3;

use overload '""' => \&stringify;

sub new {
    my ($class, $error, $message) = @_;
    $class = ref $class || $class;
    $error ||= 'Error';
    $message ||= '';
    bless [ $error, $message, (caller)[1..2] ], $class;
}

sub stringify {
    my $self = shift;
    sprintf '%s: %s at %s line %d.', @$self;
}

1;
