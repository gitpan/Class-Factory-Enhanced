package Person::SimpleName;
our $VERSION = '1.100810';
use warnings;
use strict;
use base 'Person::Base';

sub fullname {
    return $_[0]->{fullname} if @_ == 1;
    $_[0]->{fullname} = $_[1];
}
1;
