package DARLY::actor;

use strict;
use warnings;

sub meta {
    my $self = shift;
    warn "TODO implement DARLY::actor::meta() method";
}

sub spawn {
    my ($self,$alias) = @_;

    warn "TODO implement DARLY::actor::spawn() method";

    return $self;
}

sub shutdown {
    my $self = shift;
    warn "TODO implement DARLY::actor::shutdown() method";
    return;
}

sub alias {
    my ($self,$alias) = @_;
    warn "TODO implement DARLY::actor::alias() method";
    return $self;
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

sub subscribe() :method {
    my $self = shift;
    warn "TODO implement DARLY::actor::subscribe() method";
    return $self;
}

sub unsubscribe() :method {
    my $self = shift;
    warn "TODO implement DARLY::actor::unsubscribe() method";
    return $self;
}

1;
