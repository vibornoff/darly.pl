use inc::Module::Install;

name            'DARLY';
all_from        'lib/DARLY.pm';

requires        'Carp';
requires        'Readonly';
requires        'lib::abs';
requires        'Getopt::Long';
requires        'Pod::Usage';
requires        'URI';
requires        'AnyEvent';

test_requires   'Test::More';

recommends      'EV';
recommends      'Readonly::XS';

install_script  'bin/darly';

auto_install;

WriteAll;
