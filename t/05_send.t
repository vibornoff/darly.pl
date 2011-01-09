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

my $test = "Send to non-existent event hahdler";
eval { $actor->send( undef, 'zap', [] ) };
$test .= $@ ? ": $@" : '';
if ( ref $@ && $@->[0] eq 'DispatchError' ) {
    pass($test);
} else {
    fail($test);
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

done_testing();
