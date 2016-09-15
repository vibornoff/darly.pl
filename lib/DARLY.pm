package DARLY;

our $VERSION = '1.02';

use Carp;
use AnyEvent::Socket;

use DARLY::kernel;
use DARLY::actor;
use DARLY::future;
use DARLY::error;

use strict;
use warnings;

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
sub future(;&)  { unshift @_, 'DARLY::future'; goto \&DARLY::future::new }

sub init(%) {
    my %opt = @_;

    # Process 'listen' option
    if ( exists $opt{'listen'} ) {
        my %addr;
        if ( ref $opt{'listen'} eq 'ARRAY' ) {
            for my $addr ( @{$opt{'listen'}} ) {
                my ($host,$port) = parse_hostport $addr;
                croak "Can't listen '$addr': bad address" if !defined $host;
                $addr{$host,$port} = [ $host, $port ];
            }
        } else {
            $addr{':'} = [ undef, ${DARLY::kernel::DEFAULT_PORT} ];
        }
        $opt{'listen'} = [ values %addr ];
    }

    DARLY::kernel::init(%opt);
}

sub loop() {
    DARLY::kernel::loop();
}

sub run(%) {
    init(@_);
    loop();
}

sub shutdown(_) {
    DARLY::kernel::shutdown();
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
 
 DARLY::run(); # or AE::cv->recv();

=head1 DESCRIPTION

TODO Write about Actor Model.

=head1 METHODS

=head2 event $name [, \&handler ]

Declare new event with a name C<$name> and an optional handler callback C<\&handler>
in the caller's package. Events are can be either notified by C<send> method
or requested by C<request> method of an L<actor|DARLY::actor> object.

C<event> is exported when DARLY is C<use>'ed.

=head2 future [ \&callback ]

Spawn new L<future|DARLY::future>-object with an optional filtering callback C<\&callback>.
Future object can be returned from event handler saying that there is no immediately
available result, but that result would be available later.

C<future> is exported when DARLY is C<use>'ed.

=head2 init( %options )

Initialize or reinitialize DARLY. Allowed options are:

=over 4

=item listen => 1 | \( "host:port", ... )

Allow listening for inter-node connections. Expect reference to array of I<host:port>
addresses to bind to. Other true value means to listen on default port I<12345>.

=back

=head2 loop()

Enter into event loop.

=head2 run( %options )

Shorthand for C<init> and C<loop> calls.

=head2 shutdown

Exit from event loop.

=head1 SEE ALSO

L<POE>

=head1 AUTHOR

Artem S Vybornov <vybornov@gmail.com>

=head1 LICENSE

This library is free software.
You can redistribute it and/or modify it under the same terms as Perl itself.

=cut
