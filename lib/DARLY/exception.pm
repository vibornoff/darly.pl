package DARLY::exception;
use base 'Exception::Base';

our $VERSION = '0.01';

use strict;
use warnings;

use constant ATTRS => {
    %{Exception::Base->ATTRS},
    id  => { is => 'ro', default => 'Unexpected' },
};

sub id {
    shift->{defaults}{id};
}

1;
