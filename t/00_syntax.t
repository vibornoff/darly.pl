#!/usr/bin/env perl
use lib::abs qw( ../lib 00_syntax );

use strict;
use warnings;

use Test::More;

use_ok('DARLY');
use_ok('DARLY::kernel');
use_ok('DARLY::actor');
use_ok('DARLY::future');

my $testvar;
{
    package Syntax;
    use DARLY;

#    topic 'foo';
    event 'bar' => sub {
        return $testvar = $_[-1];
    };
}

my $anonymous = Syntax->spawn();
ok( $anonymous, "Spawn anonymous actor" );
ok( $anonymous->alias('anonymous'), "Alias anonymous actor" );
ok( $anonymous->alias(undef), "Unalias anonymous actor" );
ok( $anonymous = 1, "Dereference anonymous actor" );

my $aliased = Syntax->spawn('aliased');
ok( $aliased, "Spawn aliased actor" );

ok( $aliased->send( 'bar', [ 'blah' ]), "Send event to actor" );
ok( $testvar eq 'blah', "\$testvar got right value" );

ok( $aliased->request( 'bar', [ 'blah' ] => sub { $testvar = 'damn'  }), "Request actor's event" );
ok( $testvar eq 'damn', "\$testvar got right value" );

ok( $aliased->shutdown() || 1, "Shutdown actor" );


my ($t,$f);
{
    use AnyEvent;
    use DARLY;
    $t = AE::timer 3, 0, $f = future { 3 };
}
ok ( $f, "Create future object" );
ok ( join('',$f->cv->recv) eq 'result3', "Wait future for 3 sec" );

DARLY::run();

done_testing();
