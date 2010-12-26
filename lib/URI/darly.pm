package URI::darly;
use base 'URI::_server';

require DARLY::kernel;

use strict;
use warnings;

sub default_port { ${DARLY::kernel::DEFAULT_PORT} }

sub host {
    my $self = shift;
    my $authority = $self->authority;
    return undef if !defined $authority || $authority eq '';
    return $self->SUPER::host(@_);
}

sub port {
    my $self = shift;
    my $authority = $self->authority;
    return undef if !defined $authority || $authority eq '';
    return $self->SUPER::port(@_);
}

sub host_port {
    my $self = shift;
    my $authority = $self->authority;
    return undef if !defined $authority || $authority eq '';
    return $self->SUPER::host_port(@_);
}

1;
