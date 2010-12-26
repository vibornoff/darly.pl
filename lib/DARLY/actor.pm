package DARLY::actor;

use Carp;
use Scalar::Util qw( reftype blessed );
use URI;

require DARLY::kernel;

use strict;
use warnings;

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
    croak "Alias '$alias' is empty" if defined $alias && !length $alias;
    $self = $self->new( @_[2..$#_] ) unless ref $self;
    my $actor = DARLY::kernel::actor_spawn(ref $self, $self, undef);
    DARLY::kernel::actor_alias($actor, $alias) if $alias;
    return $self;
}

sub reference {
    my ($self,$url) = @_;
    croak "Url '$url' is empty" if defined $url && !length $url;
    $self = $self->new( @_[2..$#_] ) unless ref $self;
    DARLY::kernel::actor_spawn(ref $self, $self, URI->new($url));
    return $self;
}

sub shutdown {
    my $self = shift;
    my $actor = DARLY::kernel::actor_get($self) or return;
    return DARLY::kernel::actor_shutdown($actor);
}

sub alias {
    my $self = shift;
    croak "Alias '$_[0]' is empty" if defined $_[0] && !length $_[0];
    my $actor = DARLY::kernel::actor_get($self) or return;
    return DARLY::kernel::actor_alias($actor,@_);
}

sub url {
    my $self = shift;
    croak "Url '$_[0]' is empty" if defined $_[0] && !length $_[0];
    my $actor = DARLY::kernel::actor_get($self) or return;
    return DARLY::kernel::actor_url($actor,@_);
}

sub send {
    my ($self,$event,$args) = @_;
    croak "Event required" if !defined $event || !length $event;
    my $actor = DARLY::kernel::actor_get($self) or return;
    $args = [ $args ] if defined $args && ( !ref $args || reftype $args ne 'ARRAY' );
    return DARLY::kernel::actor_send($actor,$event,$args);
}

sub request {
    my ($self,$event,$args,$cb) = @_;
    croak "Event required" if !defined $event || !length $event;
    croak "Callback must be code ref" if defined $cb && ref $cb ne 'CODE' && !( blessed $cb && $cb->isa('DARLY::actor') );
    my $actor = DARLY::kernel::actor_get($self) or return;
    $args = [ $args ] if defined $args && ( !ref $args || reftype $args ne 'ARRAY' );
    return DARLY::kernel::actor_request($actor,$event,$args,$cb);
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
