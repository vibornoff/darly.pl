package DARLY;

our $VERSION = '0.00';

use strict;
use warnings;

sub import {
    my $caller = (caller)[0];
    return if $caller =~ /^DARLY/;
    return if $caller->isa('DARLY::actor');

    no strict 'refs';
    
    push @{"$caller\::ISA"}, 'DARLY::actor';
    *{"${caller}::topic"} = *topic;
    *{"${caller}::event"} = *event;
}

sub topic($) {
}

sub event($&) {
}

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
    my $chat = shift;
    return $chat->{entries} || [];
 };
 
 INIT {
    MyChatServer->new->alias('Server#1');
 };

 package main;
 use MyChatServer;
 use AnyEvent;
 
 my $client = MyChatServer->reference('Server#1');
 $client->request( 'get_history' => sub {
    my ($client,$entries) = @_;
    printf( "%s, %s: %s\n", @{$_} ) for @$entries;
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

=head1 AUTHOR

Artem S Vybornov <vybornov@gmail.com>

=head1 LICENSE

This library is free software.
You can redistribute it and/or modify it under the same terms as Perl itself.

=cut
