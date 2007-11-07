#line 1
package Class::Accessor::Complex;

use warnings;
use strict;
use Carp qw(carp croak cluck);
use Data::Miscellany 'flatten';


our $VERSION = '0.11';


use base qw(Class::Accessor Class::Accessor::Installer);


sub mk_new {
    my ($self, @args) = @_;
    my $class = ref $self || $self;
    @args = ('new') unless @args;

    for my $name (@args) {
        $self->install_accessor(name => $name, code => sub {
            local $DB::sub = local *__ANON__ = "${class}::${name}"
                if defined &DB::DB && !$Devel::DProf::VERSION;
            # don't use $class, as that's already defined above
            my $this_class = shift;
            my $self = ref ($this_class) ? $this_class : bless {}, $this_class;
            my %args = (scalar(@_ == 1) && ref($_[0]) eq 'HASH')
                ? %{ $_[0] }
                : @_;

            $self->$_($args{$_}) for keys %args;
            $self->init(%args) if $self->can('init');
            $self;
        });
    }

    $self;  # for chaining
}


sub mk_singleton {
    my ($self, @args) = @_;
    my $class = ref $self || $self;
    @args = ('new') unless @args;

    my $singleton;

    for my $name (@args) {
        $self->install_accessor(name => $name, code => sub {
            local $DB::sub = local *__ANON__ = "${class}::${name}"
                if defined &DB::DB && !$Devel::DProf::VERSION;
            return $singleton if defined $singleton;

            # don't use $class, as that's already defined above
            my $this_class = shift;
            $singleton = ref ($this_class)
                ? $this_class
                : bless {}, $this_class;
            my %args = (scalar(@_ == 1) && ref($_[0]) eq 'HASH')
                ? %{ $_[0] }
                : @_;

            $singleton->$_($args{$_}) for keys %args;
            $singleton->init(%args) if $singleton->can('init');
            $singleton;
        });
    }

    $self;  # for chaining
}


sub mk_scalar_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {
        $self->install_accessor(name => $field, code => sub {
            local $DB::sub = local *__ANON__ = "${class}::${field}"
                if defined &DB::DB && !$Devel::DProf::VERSION;
            return $_[0]->{$field} if @_ == 1;
            $_[0]->{$field} = $_[1];
        });

        $self->install_accessor(
            name => [ "clear_${field}", "${field}_clear" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_clear"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                $_[0]->{$field} = undef;
            }
        );
    }

    $self;  # for chaining
}


sub mk_class_scalar_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {

        my $scalar;

        $self->install_accessor(name => $field, code => sub {
            local $DB::sub = local *__ANON__ = "${class}::${field}"
                if defined &DB::DB && !$Devel::DProf::VERSION;
            return $scalar if @_ == 1;
            $scalar = $_[1];
        });

        $self->install_accessor(
            name => [ "clear_${field}", "${field}_clear" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_clear"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                $scalar = undef;
            }
        );
    }

    $self;  # for chaining
}


sub mk_concat_accessors {
    my ($self, @args) = @_;
    my $class = ref $self || $self;

    for my $arg (@args) {

        # defaults
        my $field = $arg;
        my $join  = '';

        if (ref $arg eq 'ARRAY') {
            ($field, $join) = @$arg;
        }

        $self->install_accessor(name => $field, code => sub {
            local $DB::sub = local *__ANON__ = "${class}::${field}"
                if defined &DB::DB && !$Devel::DProf::VERSION;
            my ($self, $text) = @_;

            if (defined $text) {
                if (defined $self->{$field}) {
                    $self->{$field} = $self->{$field} . $join . $text;
                } else {
                    $self->{$field} = $text;
                }
            }
            return $self->{$field};
        });

        $self->install_accessor(
            name => [ "clear_${field}", "${field}_clear" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_clear"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                $_[0]->{$field} = undef;
            }
        );

    }

    $self;  # for chaining
}


sub mk_array_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {
        $self->install_accessor(name => $field, code => sub {
            local $DB::sub = local *__ANON__ = "${class}::${field}"
                if defined &DB::DB && !$Devel::DProf::VERSION;
            my ($self, @list) = @_;
            defined $self->{$field} or $self->{$field} = [];

            @{$self->{$field}} = map { ref $_ eq 'ARRAY' ? @$_ : ($_) } @list
                if @list;

            wantarray ? @{$self->{$field}} : $self->{$field};
        });


        $self->install_accessor(
            name => [ "push_${field}", "${field}_push" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_push"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my $self = shift;
                push @{$self->{$field}} => @_;
            }
        );


        $self->install_accessor(
            name => [ "pop_${field}", "${field}_pop" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_pop"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                pop @{$_[0]->{$field}};
            }
        );


        $self->install_accessor(
            name => [ "unshift_${field}", "${field}_unshift" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_unshift"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my $self = shift;
                unshift @{$self->{$field}} => @_;
            }
        );


        $self->install_accessor(
            name => [ "shift_${field}", "${field}_shift" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_shift"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                shift @{$_[0]->{$field}};
            }
        );


        $self->install_accessor(
            name => [ "clear_${field}", "${field}_clear" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_clear"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                $_[0]->{$field} = [];
            }
        );


        $self->install_accessor(
            name => [ "count_${field}", "${field}_count" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_count"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                exists $_[0]->{$field} ? scalar @{$_[0]->{$field}} : 0;
            }
        );


        $self->install_accessor(
            name => [ "splice_${field}", "${field}_splice" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_splice"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my ($self, $offset, $len, @list) = @_;
                splice(@{$self->{$field}}, $offset, $len, @list);
            }
        );


        $self->install_accessor(
            name => [ "index_${field}", "${field}_index" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_index"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my ($self, @indices) = @_;
                my @result = map { $self->{$field}[$_] } @indices;
                return $result[0] if @indices == 1;
                wantarray ? @result : \@result;
            }
        );


        $self->install_accessor(
            name => [ "set_${field}", "${field}_set" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_set"
                    if defined &DB::DB && !$Devel::DProf::VERSION;

                my $self = shift;
                my @args = @_;
                croak
                    "${class}::${field}_set expects an even number of fields\n"
                    if @args % 2;
                while (my ($index, $value) = splice @args, 0, 2) {
                    $self->{$field}->[$index] = $value;
                }
                return @_ / 2;
            }
        );
    }

    $self;  # for chaining
}


sub mk_class_array_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {

        my @array;

        $self->install_accessor(name => $field, code => sub {
            local $DB::sub = local *__ANON__ = "${class}::${field}"
                if defined &DB::DB && !$Devel::DProf::VERSION;
            my ($self, @list) = @_;

            @array = map { ref $_ eq 'ARRAY' ? @$_ : ($_) } @list
                if @list;

            wantarray ? @array : \@array
        });


        $self->install_accessor(
            name => [ "push_${field}", "${field}_push" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_push"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my $self = shift;
                push @array => @_;
            }
        );


        $self->install_accessor(
            name => [ "pop_${field}", "${field}_pop" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_pop"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                pop @array;
            }
        );


        $self->install_accessor(
            name => [ "unshift_${field}", "${field}_unshift" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_unshift"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my $self = shift;
                unshift @array => @_;
            }
        );


        $self->install_accessor(
            name => [ "shift_${field}", "${field}_shift" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_shift"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                shift @array;
            }
        );


        $self->install_accessor(
            name => [ "clear_${field}", "${field}_clear" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_clear"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                @array = ();
            }
        );


        $self->install_accessor(
            name => [ "count_${field}", "${field}_count" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_count"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                scalar @array;
            }
        );


        $self->install_accessor(
            name => [ "splice_${field}", "${field}_splice" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_splice"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my ($self, $offset, $len, @list) = @_;
                splice(@array, $offset, $len, @list);
            }
        );


        $self->install_accessor(
            name => [ "index_${field}", "${field}_index" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_index"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my ($self, @indices) = @_;
                my @result = map { $array[$_] } @indices;
                return $result[0] if @indices == 1;
                wantarray ? @result : \@result;
            }
        );


        $self->install_accessor(
            name => [ "set_${field}", "${field}_set" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_set"
                    if defined &DB::DB && !$Devel::DProf::VERSION;

                my $self = shift;
                my @args = @_;
                croak
                    "${class}::${field}_set expects an even number of fields\n"
                    if @args % 2;
                while (my ($index, $value) = splice @args, 0, 2) {
                    $array[$index] = $value;
                }
                return @_ / 2;
            }
        );
    }

    $self;  # for chaining
}


sub mk_hash_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {
        $self->install_accessor(name => $field, code => sub {
            local $DB::sub = local *__ANON__ = "${class}::${field}"
                if defined &DB::DB && !$Devel::DProf::VERSION;
            my ($self, @list) = @_;
            defined $self->{$field} or $self->{$field} = {};
            if (scalar @list == 1) {
                my ($key) = @list;

                if (my $type = ref $key) {
                    if ($type eq 'ARRAY') {
                        return @{$self->{$field}}{@$key};
                    } elsif ($type eq 'HASH') {
                        while (my ($subkey, $value) = each %$key) {
                            $self->{$field}->{$subkey} = $value;
                        }
                        return wantarray ? %{$self->{$field}} : $self->{$field};
                    } else {
                        cluck "Unrecognized ref type for hash method: $type.";
                    }
                } else {
                    return $self->{$field}->{$key};
                }
            } else {
                while (1) {
                    my $key = shift @list;
                    defined $key or last;
                    my $value = shift @list;
                    defined $value or carp "No value for key $key.";
                    $self->{$field}->{$key} = $value;
                }
                return wantarray ? %{$self->{$field}} : $self->{$field};
            }
        });


        $self->install_accessor(
            name => [ "clear_${field}", "${field}_clear" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_clear"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my $self = shift;
                $self->{$field} = {};
            }
        );


        $self->install_accessor(
            name => [ "keys_${field}", "${field}_keys" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_keys"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                keys %{$_[0]->{$field}};
            }
        );


        $self->install_accessor(
            name => [ "values_${field}", "${field}_values" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_values"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                values %{$_[0]->{$field}};
            }
        );


        $self->install_accessor(
            name => [ "exists_${field}", "${field}_exists" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_exists"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my ($self, $key) = @_;
                exists $self->{$field} && exists $self->{$field}{$key};
            }
        );


        $self->install_accessor(
            name => [ "delete_${field}", "${field}_delete" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_delete"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my ($self, @keys) = @_;
                delete @{$self->{$field}}{@keys};
            }
        );

    }
    $self;  # for chaining
}


sub mk_class_hash_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {

        my %hash;

        $self->install_accessor(name => $field, code => sub {
            local $DB::sub = local *__ANON__ = "${class}::${field}"
                if defined &DB::DB && !$Devel::DProf::VERSION;
            my ($self, @list) = @_;
            if (scalar @list == 1) {
                my ($key) = @list;

                return $hash{$key} unless ref $key;

                return @hash{@$key} if ref $key eq 'ARRAY';

                if (ref($key) eq 'HASH') {
                    %hash = (%hash, %$key);
                    return wantarray ? %hash : \%hash;
                }

                # not a scalar, array or hash...
                cluck sprintf 'Not a recognized ref type for static hash [%s]',
                    ref($key);
            } else {
                 while (1) {
                     my $key = shift @list;
                     defined $key or last;
                     my $value = shift @list;
                     defined $value or carp "No value for key $key.";
                     $hash{$key} = $value;
                 }

                return wantarray ? %hash : \%hash;
            }
        });


        $self->install_accessor(
            name => [ "clear_${field}", "${field}_clear" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_clear"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                %hash = ();
            }
        );


        $self->install_accessor(
            name => [ "keys_${field}", "${field}_keys" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_keys"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                keys %hash;
            }
        );


        $self->install_accessor(
            name => [ "values_${field}", "${field}_values" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_values"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                values %hash;
            }
        );


        $self->install_accessor(
            name => [ "exists_${field}", "${field}_exists" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_exists"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                exists $hash{$_[1]};
            }
        );


        $self->install_accessor(
            name => [ "delete_${field}", "${field}_delete" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_delete"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my ($self, @keys) = @_;
                delete @hash{@keys};
            }
        );

    }
    $self;  # for chaining
}


sub mk_abstract_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {
        $self->install_accessor(name => $field, code => sub {
            local $DB::sub = local *__ANON__ = "${class}::${field}"
                if defined &DB::DB && !$Devel::DProf::VERSION;
            my $method = "${class}::${field}";
            eval "require Error::Hierarchy::Internal::AbstractMethod";

            if ($@) {
                # Error::Hierarchy not installed?
                die sprintf "called abstract method [%s]", $method;

            } else {
                # need to pass method because caller() still doesn't see the
                # anonymously named sub's name
                throw Error::Hierarchy::Internal::AbstractMethod(
                    method => $method,
                );
            }
        });
    }

    $self;  # for chaining
}


sub mk_boolean_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {
        $self->install_accessor(name => $field, code => sub {
            local $DB::sub = local *__ANON__ = "${class}::${field}"
                if defined &DB::DB && !$Devel::DProf::VERSION;
            return $_[0]->{$field} if @_ == 1;
            $_[0]->{$field} = $_[1] ? 1 : 0;   # normalize
        });


        $self->install_accessor(
            name => [ "set_${field}", "${field}_set" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_set"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                $_[0]->{$field} = 1;
            }
        );


        $self->install_accessor(
            name => [ "clear_${field}", "${field}_clear" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_clear"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                $_[0]->{$field} = 0;
            }
        );
    }

    $self;  # for chaining
}


sub mk_integer_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {
        $self->install_accessor(name => $field, code => sub {
            local $DB::sub = local *__ANON__ = "${class}::${field}"
                if defined &DB::DB && !$Devel::DProf::VERSION;
            my $self = shift;
            return $self->{$field} || 0 unless @_;
            $self->{$field} = shift;
        });


        $self->install_accessor(
            name => [ "reset_${field}", "${field}_reset" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_reset"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                $_[0]->{$field} = 0;
            }
        );


        $self->install_accessor(
            name => [ "inc_${field}", "${field}_inc" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_inc"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                $_[0]->{$field}++;
            }
        );


        $self->install_accessor(
            name => [ "dec_${field}", "${field}_dec" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_dec"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                $_[0]->{$field}--;
            }
        );
    }

    $self;  # for chaining
}


sub mk_set_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {
        my $insert_method   = "${field}_insert";
        my $elements_method = "${field}_elements";


        $self->install_accessor(name => $field, code => sub {
            local $DB::sub = local *__ANON__ = "${class}::${field}"
                if defined &DB::DB && !$Devel::DProf::VERSION;
            my $self = shift;
            if (@_) {
                $self->$insert_method(@_);
            } else {
                $self->$elements_method;
            }
        });


        $self->install_accessor(
            name => [ "insert_${field}", $insert_method ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${insert_method}"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my $self = shift;
                $self->{$field}{$_}++ for flatten(@_);
            }
        );


        $self->install_accessor(
            name => [ "elements_${field}", $elements_method ],
            code => sub {
                local $DB::sub = local *__ANON__ =
                    "${class}::${elements_method}"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my $self = shift;
                $self->{$field} ||= {};
                keys %{ $self->{$field} }
            }
        );


        $self->install_accessor(
            name => [ "delete_${field}", "${field}_delete" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_delete"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my $self = shift;
                delete $self->{$field}{$_} for @_;
            }
        );


        $self->install_accessor(
            name => [ "clear_${field}", "${field}_clear" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_clear"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                $_[0]->{$field} = {};
            }
        );


        $self->install_accessor(
            name => [ "contains_${field}", "${field}_contains" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_contains"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my ($self, $key) = @_;
                return unless defined $key;
                exists $self->{$field}{$key};
            }
        );


        $self->install_accessor(
            name => [ "is_empty_${field}", "${field}_is_empty" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_is_empty"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my $self = shift;
                keys %{ $self->{$field} || {} } == 0;
            }
        );


        $self->install_accessor(
            name => [ "size_${field}", "${field}_size" ],
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}_size"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my $self = shift;
                scalar keys %{ $self->{$field} || {} };
            }
        );

    }

    $self;  # for chaining
}


sub mk_object_accessors {
    my ($self, @args) = @_;
    my $class = ref $self || $self;

    while (@args) {
        my $type = shift @args;
        my $list = shift @args or die "No slot names for $class";

        # Allow a list of hashrefs.
        my @list = ( ref($list) eq 'ARRAY' ) ? @$list : ($list);

        for my $obj_def (@list) {

            my ($name, @composites);
            if ( ! ref $obj_def ) {
                $name = $obj_def;
            } else {
                $name = $obj_def->{slot};
                my $composites = $obj_def->{comp_mthds};
                @composites = ref($composites) eq 'ARRAY' ? @$composites
                    : defined $composites ? ($composites) : ();
            }

            for my $meth (@composites) {
                $self->install_accessor(name => $meth, code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::{$meth}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my ($self, @args) = @_;
                    $self->$name()->$meth(@args);
                });
            }

            $self->install_accessor(name => $name, code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${name}"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my ($self, @args) = @_;
                if (ref($args[0]) && UNIVERSAL::isa($args[0], $type)) {
                    $self->{$name} = $args[0];
                } else {
                    defined $self->{$name} or
                        $self->{$name} = $type->new(@args);
                }
                $self->{$name};
            });


            $self->install_accessor(
                name => [ "clear_${name}", "${name}_clear" ],
                code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${name}_clear"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                delete $_[0]->{$name};
            });
        }
    }


    $self;  # for chaining
}


sub mk_forward_accessors {
    my ($self, %args) = @_;
    my $class = ref $self || $self;

    while (my ($slot, $methods) = each %args) {
        my @methods = ref $methods eq 'ARRAY' ? @$methods : ($methods);
        for my $field (@methods) {
            $self->install_accessor(name => $field, code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my ($self, @args) = @_;
                $self->$slot()->$field(@args);
            });
        }
    }

    $self;  # for chaining
}


1;

__END__

#line 1437

