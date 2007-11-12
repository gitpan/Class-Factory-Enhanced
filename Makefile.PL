use inc::Module::Install;
name 'Class-Factory-Enhanced';
all_from 'lib/Class/Factory/Enhanced.pm';
perl_version '5.006';

requires 'Class::Factory' => '1.06';
requires 'Class::Accessor::Installer';

build_requires 'Test::More' => '0.70';
build_requires 'Class::Accessor::Complex';

use_standard_tests(without => 'pod_coverage');
auto_include;
WriteAll;
