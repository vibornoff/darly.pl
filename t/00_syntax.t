#!/usr/bin/env perl
use lib::abs qw( lib ../lib );

use strict;
use warnings;

use Test::More;
use Scalar::Util qw( refaddr );

use_ok('DARLY');
use_ok('URI::darly');
use_ok('TestActor');

my $anonymous = TestActor->spawn();
ok( $anonymous, "Spawn anonymous actor" );
ok( $anonymous->alias('anonymous'), "Alias anonymous actor" );
ok( $anonymous->alias(undef), "Unalias anonymous actor" );
ok( $anonymous = 1, "Dereference anonymous actor" );

my $aliased = TestActor->spawn('aliased');
ok( $aliased, "Spawn aliased actor" );
is( "$aliased", 'darly:///aliased', "Actor object stringifies into its URI" );

my $ref = TestActor->reference('darly:///aliased');
ok( $ref, "Create aliased actor reference" );
isnt( refaddr $ref, refaddr $aliased, "Actor and its reference aren't the same object" );

is( $aliased->url, undef, "Actor's URI is undefined" );
is( $ref->url, 'darly:///aliased', "Reference's URI is correct" );

ok( $aliased->shutdown(), "Shutdown actor" );

done_testing();
