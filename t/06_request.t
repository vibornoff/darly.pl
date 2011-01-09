#!/usr/bin/env perl
use lib::abs qw( lib ../lib );

use strict;
use warnings;

use Test::More;
use TestActor;

my $actor = TestActor->spawn('test');
ok( $actor, "Spawn actor" );

ok( $actor->request( undef, 'foo', [ 'blah' ]), "Request 'foo' event on actor" );
is( ${TestActor::testvar}, 'blah', "\$testvar got right value" );

ok( $actor->request( undef, 'bar', [ ]), "Request 'bar' event on actor" );
is( ${TestActor::testvar}, $actor, "\$testvar got right value" );

my $test = "Request non-existent event hahdler on actor";
eval { $actor->request( undef, 'zap', [] ) };
$test .= $@ ? ": $@" : '';
if ( ref $@ && $@->[0] eq 'DispatchError' ) {
    pass($test);
} else {
    fail($test);
}

my $ref = TestActor->reference('darly:///test');
ok( $ref, 'Create actor reference' );

ok( $ref->request( undef, 'foo', [ 'woof!' ]), "Request 'foo' event on actor reference" );
is( ${TestActor::testvar}, 'woof!', "\$testvar got right value" );

done_testing();
