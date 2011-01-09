#!/usr/bin/env perl
use lib::abs qw( lib ../lib );

use strict;
use warnings;

use Test::More;
use TestActor;

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

done_testing();
