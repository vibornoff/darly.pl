#!/usr/bin/env perl
use lib::abs qw( lib ../lib );

use strict;
use warnings;

use Test::More;
use TestActor;

ok( DARLY::init( listen => 1 ), "Init DARLY" );

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

my @res = $actor->request( undef, 'echo', [qw( 1 2 3 )], sub { reverse @_ });
ok( @res > 0, "Request 'echo' event on actor with result filtering" );
is( join('',@res), '321', "Got expected filtered result" );

my $ref = TestActor->reference('darly:///test');
ok( $ref, 'Create actor reference' );

ok( $ref->request( undef, 'foo', [ 'woof!' ]), "Request 'foo' event on actor reference" );
is( ${TestActor::testvar}, 'woof!', "\$testvar got right value" );

my $farref = TestActor->reference('darly://localhost/test');
ok( $farref, 'Create actor far reference' );

my $f = $farref->request( undef, 'foo', [ 'poof!' ]);
ok( $f, "Request 'foo' event on far actor reference" );
ok( $f->cv->recv(), "Wait for response" );
is( ${TestActor::testvar}, 'poof!', "\$testvar got right value" );

$test = "Request 'echo' event handler on far actor reference";
$f = $farref->request( undef, 'echo', [ 'qwer' ], sub {
    fail $test unless @_ > 0;
    is( $_[0], 'qwer', $test );
});
ok( $f->cv->recv(), "Wait for response" );

$test = "Request 'proxy_echo' event handler on far actor reference";
$f = $farref->request( undef, 'proxy_echo', [ 'asdf' ], sub {
    fail $test unless @_ > 0;
    is( $_[0], 'asdf', $test );
});
ok( $f->cv->recv(), "Wait for response" );

$test = "Request 'delayed_echo' event handler on far actor reference";
$f = $farref->request( undef, 'delayed_echo', [ 3, 'zxcv' ], sub {
    fail $test unless @_ > 0;
    is( $_[0], 'zxcv', $test );
});
ok( $f->cv->recv(), "Wait for response" );

ok( $actor->request( undef, 'check_context', []), "Request 'check_context' event on actor" );
is( ${TestActor::testvar}, 1, "Context is list" );

ok( $ref->request( undef, 'check_context', []), "Request 'check_context' event on actor reference" );
is( ${TestActor::testvar}, 1, "Context is list" );

$test = "Request 'check_context' event on far actor reference";
$f = $farref->request( undef, 'check_context', [], sub { fail $test if $@ || !@_ });
ok( $f->cv->recv(), "Wait for response" );
is( ${TestActor::testvar}, 1, "Context is list" );

done_testing();
