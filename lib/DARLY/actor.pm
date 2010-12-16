package DARLY::actor;

use strict;
use warnings;

require DARLY::kernel;

sub DESTROY {
    my $self = shift;
    $self->shutdown();
}

sub meta {
    my $self = shift;
    warn "TODO implement DARLY::actor::meta() method";
}

sub spawn {
    my ($self,$alias) = @_;
    warn "TODO implement DARLY::actor::spawn() method";
    DARLY::kernel::spawn_actor($self);
    return $self;
}

sub shutdown {
    my $self = shift;
    warn "TODO implement DARLY::actor::shutdown() method";
    DARLY::kernel::shutdown_actor($self);
    return;
}

sub alias {
    my ($self,$alias) = @_;
    warn "TODO implement DARLY::actor::alias() method";
    return $self;
}

sub reference {
    my ($self,$alias) = @_;
}

sub send {
    my ($self,$event,$args) = @_;
    warn "TODO implement DARLY::actor::send() method";
    return $self;
}

sub request {
    my ($self,$event,$args,$responder) = @_;
    warn "TODO implement DARLY::actor::request() method";
    return $self;
}

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

1;
