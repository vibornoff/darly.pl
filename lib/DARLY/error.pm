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
    my ($class, $error, $message, $file, $line) = @_;
    $class = ref $class || $class;
    $error ||= 'Error';
    $message ||= '';
    ($file, $line) = (caller)[1..2] if !$file || !$line;
    bless [ $error, $message, $file, $line ], $class;
}

sub throw {
    my ($class, $error, $message, $file, $line) = splice @_, 0, 5;
    ($file, $line) = (caller)[1..2] if !$file || !$line;
    die $class->new($error, $message, $file, $line, @_);
}

sub stringify {
    my $self = shift;
    return $self unless ref $self;
    return sprintf '%s: %s at %s line %d.', @$self;
}

1;
