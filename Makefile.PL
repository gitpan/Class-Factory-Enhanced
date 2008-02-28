use inc::Module::Install;
include 'Module::AutoInstall';

name 'Class-Factory-Enhanced';
all_from 'lib/Class/Factory/Enhanced.pm';
perl_version '5.006';

requires 'Class::Factory' => '1.06';
requires 'Class::Accessor::Installer';

build_requires 'Test::More' => '0.70';
build_requires 'Class::Accessor::Complex';

process_templates(
    first_year => 2007,
    rest_from  => "$ENV{HOME}/.mitlib/standard_pod",
    start_tag  => '{%',
    end_tag    => '%}',
);

use_standard_tests(without => 'pod_coverage');
auto_install;
auto_include;
WriteAll;
