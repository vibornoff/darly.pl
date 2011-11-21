package DARLY::error;

use strict;
use warnings;

use constant ERROR  => 0;
use constant MESSAGE => 1;
use constant FILE   => 2;
use constant LINE   => 3;
use constant CAUSE  => 4;

use overload (
    '""' => \&stringify,
    fallback => 1,
);

sub new {
    my ($class, $error, $message, $cause) = @_;
    $class = ref $class || $class;
    $error ||= 'Error';
    $message ||= '';
    bless [ $error, $message, (caller)[1..2], $cause ], $class;
}

sub throw {
    die shift->new(@_);
}

sub err {
    my $self = shift;

    $self->[ERROR] = shift
        if @_ > 0;

    return $self->[ERROR];
}

sub message {
    my $self = shift;

    $self->[MESSAGE] = shift
        if @_ > 0;

    return $self->[MESSAGE];
}

sub cause {
    my $self = shift;

    $self->[CAUSE] = shift
        if @_ > 0;

    return $self->[CAUSE];
}

sub stringify {
    my $self = shift;
    return $self unless ref $self;
    return sprintf "%s: %s at %s line %d.\nCaused by %s", @$self if defined $self->[CAUSE];
    return sprintf "%s: %s at %s line %d.", @$self;
}

1;
