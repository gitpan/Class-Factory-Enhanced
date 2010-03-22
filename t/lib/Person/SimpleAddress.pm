package Person::SimpleAddress;
our $VERSION = '1.100810';
use warnings;
use strict;
use base 'Person::Base';

sub fulladdr {
    return $_[0]->{fulladdr} if @_ == 1;
    $_[0]->{fulladdr} = $_[1];
}
1;
