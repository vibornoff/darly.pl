package DARLY::actor;

use Carp;
use Scalar::Util qw( reftype );

use strict;
use warnings;

require DARLY::kernel;

BEGIN {
    DARLY::kernel::meta_event( __PACKAGE__, 'default' );
    DARLY::kernel::meta_event( __PACKAGE__, 'error' );
    DARLY::kernel::meta_extend( __PACKAGE__, __PACKAGE__ );
}

sub new {
    my $class = shift; $class = ref $class || $class;
    return bless { @_ }, $class;
}

sub DESTROY {
    my $self = shift;
    $self->shutdown();
}

sub spawn {
    my ($self,$alias) = @_;
    $self = $self->new( @_[2..$#_] ) unless ref $self;
    croak "Object '$self' is not an actor" if !$self->isa('DARLY::actor');
    croak "Alias '$alias' is empty" if defined $alias && !length $alias;
    DARLY::kernel::actor_spawn(ref $self, $self, undef);
    DARLY::kernel::actor_alias($self, $alias) if $alias;
    return $self;
}

sub shutdown {
    my $self = shift;
    croak "Object '$self' is not an actor" if !$self->isa('DARLY::actor');
    DARLY::kernel::actor_shutdown($self);
    return;
}

sub alias {
    my ($self,$alias) = @_;
    croak "Object '$self' is not an actor" if !$self->isa('DARLY::actor');
    croak "Alias '$alias' is empty" if defined $alias && !length $alias;
    return DARLY::kernel::actor_alias(@_);
}

sub reference {
    my ($self,$alias) = @_;
}

sub send {
    my ($self,$event,$args) = @_;
    croak "Object '$self' is not an actor" if !$self->isa('DARLY::actor');
    croak "Event required" if !defined $event || !length $event;
    my $actor = DARLY::kernel::actor_get($self) or return;
    $args = [ $args ] if defined $args && reftype $args ne 'ARRAY';
    return DARLY::kernel::send($actor,$event,$args);
}

sub request {
    my ($self,$event,$args,$cb) = @_;
    croak "Object '$self' is not an actor" if !$self->isa('DARLY::actor');
    croak "Event required" if !defined $event || !length $event;
    croak "Callback required" if !defined $cb || ( ref $cb ne 'CODE' && !$cb->isa('DARLY::actor') );
    my $actor = DARLY::kernel::actor_get($self) or return;
    $args = [ $args ] if defined $args && reftype $args ne 'ARRAY';
    return DARLY::kernel::request($actor,$event,$args,$cb);
}

=pod
sub subscribe {
    my $self = shift;
    warn "TODO implement DARLY::actor::subscribe() method";
    return $self;
}

sub unsubscribe {
    my $self = shift;
    warn "TODO implement DARLY::actor::unsubscribe() method";
    return $self;
}
=cut

1;
