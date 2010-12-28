package DARLY::error;

use strict;
use warnings;

use constant ERROR  => 0;
use constant MESSAGE => 1;
use constant FILE   => 2;
use constant LINE   => 3;

use overload (
    '""' => \&stringify,
    fallback => 1,
);

sub new {
    my ($class, $error, $message) = @_;
    $class = ref $class || $class;
    $error ||= 'Error';
    $message ||= '';
    bless [ $error, $message, (caller)[1..2] ], $class;
}

sub stringify {
    my $self = shift;
    return $self unless ref $self;
    return sprintf '%s: %s at %s line %d.', @$self;
}

1;
