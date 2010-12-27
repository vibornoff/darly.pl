use inc::Module::Install;

name            'DARLY';
all_from        'lib/DARLY.pm';

requires        'Carp';
requires        'Readonly';
requires        'lib::abs';
requires        'Getopt::Std';
requires        'URI';
requires        'AnyEvent';
requires        'Try::Tiny';
requires        'Exception::Base';

test_requires   'Test::More';

recommends      'EV';
recommends      'Readonly::XS';

install_script  'bin/darlyd';

auto_install;

WriteAll;
