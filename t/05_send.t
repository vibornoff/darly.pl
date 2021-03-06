#!/usr/bin/env perl
use lib::abs qw( lib ../lib );

use strict;
use warnings;

use Test::More;
use TestActor;

ok( DARLY::init( listen => 1 ), "Init DARLY" );

my $actor = TestActor->spawn('test');
ok( $actor, "Spawn actor" );

ok( $actor->send( undef, 'foo', [ 'blah' ]), "Send 'foo' event to actor" );
is( ${TestActor::testvar}, 'blah', "\$testvar got right value" );

ok( $actor->send( undef, 'bar', [ ]), "Send 'bar' event to actor" );
is( ${TestActor::testvar}, $actor, "\$testvar got right value" );

{
    my $test = "Send to non-existent event hahdler";
    my $warn = '';
    local $SIG{__WARN__} = sub { $warn .= "$_[0]\n" };
    $actor->send( undef, 'zap', [] );
    if ( $warn =~ /DispatchError/ ) {
        pass($test);
    } else {
        fail($test);
    }
}

my $ref = TestActor->reference('darly:///test');
ok( $ref, 'Create actor reference' );

ok( $ref->send( undef, 'foo', [ 'woof!' ]), "Send 'foo' event to actor reference" );
is( ${TestActor::testvar}, 'woof!', "\$testvar got right value" );

my $farref = TestActor->reference('darly://localhost/test');
ok( $farref, 'Create actor far reference' );

ok( $farref->send( undef, 'foo', [ 'poof!' ]), "Send 'foo' event to far actor reference" );
ok( $farref->send( undef, 'bye', []), "Send 'bye' event to far actor reference" );
DARLY::loop();
is( ${TestActor::testvar}, 'poof!', "\$testvar got right value" );

ok( $actor->send( undef, 'check_context', []), "Send 'check_context' event to actor" );
ok( $farref->send( undef, 'bye', []), "Send 'bye' event to far actor reference" );
DARLY::loop();
is( ${TestActor::testvar}, undef, "Context is void" );

ok( $ref->send( undef, 'check_context', []), "Send 'check_context' event to actor reference" );
ok( $farref->send( undef, 'bye', []), "Send 'bye' event to far actor reference" );
DARLY::loop();
is( ${TestActor::testvar}, undef, "Context is void" );

ok( $farref->send( undef, 'check_context', []), "Send 'check_context' event to far actor reference" );
ok( $farref->send( undef, 'bye', []), "Send 'bye' event to far actor reference" );
DARLY::loop();
is( ${TestActor::testvar}, undef, "Context is void" );

ok( $farref->send( undef, 'echo', []), "Send []" );
ok( $farref->send( undef, 'bye', []), "Send 'bye' event to far actor reference" );
DARLY::loop();
is_deeply( ${TestActor::testvar}, [], "Empty array received after send []" );

ok( $farref->send( undef, 'echo'), "Send without parameters" );
ok( $farref->send( undef, 'bye', []), "Send 'bye'" );
DARLY::loop();
is_deeply( ${TestActor::testvar}, [], "Empty array received after send without parameters" );

ok( $farref->send( undef, 'echo', undef), "Send with undef" );
ok( $farref->send( undef, 'bye', []), "Send 'bye'" );
DARLY::loop();
is_deeply( ${TestActor::testvar}, [undef], "Received [undef]" );

ok( $farref->send( undef, 'echo', [undef]), "Send [undef]" );
ok( $farref->send( undef, 'bye', []), "Send 'bye'" );
DARLY::loop();
is_deeply( ${TestActor::testvar}, [undef], "Received [undef]" );

ok( $farref->send( undef, 'echo', '0E0'), "Send with 0E0" );
ok( $farref->send( undef, 'bye', []), "Send 'bye'" );
DARLY::loop();
is_deeply( ${TestActor::testvar}, ['0E0'], "Received [0E0]" );

ok( $farref->send( undef, 'echo', '0'), "Send with 0" );
ok( $farref->send( undef, 'bye', []), "Send 'bye'" );
DARLY::loop();
is_deeply( ${TestActor::testvar}, [0], "Received [0]" );

done_testing();
