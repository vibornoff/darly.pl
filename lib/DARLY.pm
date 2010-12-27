package DARLY;

our $VERSION = '0.00';

use DARLY::kernel;
use DARLY::actor;
use DARLY::future;
use DARLY::exception;

use strict;
use warnings;

use Exception::Base
(
    'DARLY::IOException' => {
        isa => 'DARLY::exception',
        id => 'IO',
    },

    'DARLY::DispatchException' => {
        isa => 'DARLY::exception',
        id => 'Dispatch',
    },
);

sub import {
    my $caller = (caller)[0];
    return if $caller =~ /^DARLY/;

    no strict 'refs';
    #*{"$caller\::topic"} = *topic;
    *{"$caller\::event"} = *event;
    *{"$caller\::future"} = *future;

    push @{"$caller\::ISA"}, 'DARLY::actor'
        if !$caller->isa('DARLY::actor');

    DARLY::kernel::meta_extend($caller);
}

#sub topic($)    { }
sub event($;&)  { goto \&DARLY::kernel::meta_event }
sub future(&)   { DARLY::future->new(@_) }

*run = *DARLY::kernel::run;

1;

__END__

=head1 NAME

DARLY - Distributed Actor Runtime Library

=head1 SYNOPSIS

 package MyChatServer;
 use DARLY;
 
 topic 'history';
 
 event 'say' => sub {
    my ($chat,$who,$phrase) = @_;
    my $entry = [ time, $who, $phrase ];
    push @{$chat->{entries}}, $entry;
    $chat->notify( 'history', $entry );
 };
 
 event 'get_history' => sub {
    my ($chat,$lines) = @_;
    return [ @{$chat->{entries}}[ -$lines .. -1 ] ];
 };
 
 INIT {
    MyChatServer->spawn('Server#1');
 };

 package main;
 use MyChatServer;
 use AnyEvent;
 
 my $client = MyChatServer->reference('Server#1');
 $client->request( 'get_history', [ 10 ] => sub {
    my ($client,$entries) = @_;
    printf( "%s, %s: %s\n", @$_ ) for @$entries;
    $client->subscribe( 'history' => sub {
        my ($client,$entry) = @_;
        printf "%s, %s: %s\n", @$entry;
    });
 });
 
 my $io = AE::io *STDIN, 0 => sub {
    my $phrase = <STDIN>;
    $client->send( 'say', 'MyNickName', $phrase );
 };
 
 DARLY::loop(); # or AE::cv->recv();

=head1 DESCRIPTION

=head2 event

=head2 topic

=head2 future

 event 'delayed_echo' => sub {
    my ($actor, $delay, $message) = @_;
    my ($t,$f); $t = AE::timer $delay, 0, $f = future { $t = undef; return $message };
    return $f;
 }

 $actor->request(
    'delayed_echo', [ 3, 'hello!' ]
        => sub { say "Got $_[-1]" }
 );

=head1 AUTHOR

Artem S Vybornov <vybornov@gmail.com>

=head1 LICENSE

This library is free software.
You can redistribute it and/or modify it under the same terms as Perl itself.

=cut
