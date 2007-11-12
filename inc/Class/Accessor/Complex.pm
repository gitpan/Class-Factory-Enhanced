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
        $self->install_accessor(
            name => $name,
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${name}"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                # don't use $class, as that's already defined above
                my $this_class = shift;
                my $self = ref ($this_class)
                    ? $this_class : bless {}, $this_class;
                my %args = (scalar(@_ == 1) && ref($_[0]) eq 'HASH')
                    ? %{ $_[0] }
                    : @_;

                $self->$_($args{$_}) for keys %args;
                $self->init(%args) if $self->can('init');
                $self;
            },
            purpose => <<'EODOC',
A constructor. It can take named arguments which are used to set the object's
accessors.
EODOC
            example => [
                "$class->$name;",
                "$class->$name(\%args);",
            ],
        );
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
        $self->install_accessor(
            name => $field,
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                return $_[0]->{$field} if @_ == 1;
                $_[0]->{$field} = $_[1];
            },
            purpose => <<'EODOC',
A basic getter/setter method. If called without an argument, it returns the
value. If called with a single argument, it sets the value.
EODOC
            example => [
                "my \$value = \$obj->$field;",
                "\$obj->$field(\$value);",
            ],
        );

        for my $name ("clear_${field}", "${field}_clear") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    $_[0]->{$field} = undef;
                },
                purpose => <<'EODOC',
Clears the value.
EODOC
                example => "\$obj->$name;",
            );
        }
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
        $self->install_accessor(
            name => $field,
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my ($self, @list) = @_;
                defined $self->{$field} or $self->{$field} = [];

                @{$self->{$field}} =
                    map { ref $_ eq 'ARRAY' ? @$_ : ($_) }
                    @list
                    if @list;

                wantarray ? @{$self->{$field}} : $self->{$field};
            },
            purpose => <<'EODOC',
Get or set the array values. If called without an arguments, it returns the
array in list context, or a reference to the array in scalar context. If
called with arguments, it expands array references found therein and sets the
values.
EODOC
            example => [
                "my \@values    = \$obj->$field;",
                "my \$array_ref = \$obj->$field;",
                "\$obj->$field(\@values);",
                "\$obj->$field(\$array_ref);",
            ],
        );


        for my $name ("push_${field}", "${field}_push") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my $self = shift;
                    push @{$self->{$field}} => @_;
                },
                purpose => <<'EODOC',
Pushes elements onto the end of the array.
EODOC
                example => "\$obj->$name(\@values);",
            );
        }


        for my $name ("pop_${field}", "${field}_pop") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    pop @{$_[0]->{$field}};
                },
                purpose => <<'EODOC',
Pops the last element off the array, returning it.
EODOC
                example => "my \$value = \$obj->$name;",
            );
        }


        for my $name ("unshift_${field}", "${field}_unshift") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my $self = shift;
                    unshift @{$self->{$field}} => @_;
                },
                purpose => <<'EODOC',
Unshifts elements onto the beginning of the array.
EODOC
                example => "\$obj->$name(\@values);",
            );
        }


        for my $name ("shift_${field}", "${field}_shift") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    shift @{$_[0]->{$field}};
                },
                purpose => <<'EODOC',
Shifts the first element off the array, returning it.
EODOC
                example => "my \$value = \$obj->$name;",
            );
        }


        for my $name ("clear_${field}", "${field}_clear") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    $_[0]->{$field} = [];
                },
                purpose => <<'EODOC',
Deletes all elements from the array.
EODOC
                example => "\$obj->$name;",
            );
        }


        for my $name ("count_${field}", "${field}_count") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    exists $_[0]->{$field} ? scalar @{$_[0]->{$field}} : 0;
                },
                purpose => <<'EODOC',
Returns the number of elements in the array.
EODOC
                example => "my \$count = \$obj->$name;",
            );
        }


        for my $name ("splice_${field}", "${field}_splice") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my ($self, $offset, $len, @list) = @_;
                    splice(@{$self->{$field}}, $offset, $len, @list);
                },
                purpose => <<'EODOC',
Takes three arguments: An offset, a length and a list.

Removes the elements designated by the offset and the length from the array,
and replaces them with the elements of the list, if any. In list context,
returns the elements removed from the array. In scalar context, returns the
last element removed, or C<undef> if no elements are removed. The array grows
or shrinks as necessary. If the offset is negative then it starts that far
from the end of the array. If the length is omitted, removes everything from
the offset onward. If the length is negative, removes the elements from the
offset onward except for -length elements at the end of the array. If both the
offset and the length are omitted, removes everything. If the offset is past
the end of the array, it issues a warning, and splices at the end of the
array.
EODOC
                example => [
                    "\$obj->$name(2, 1, \$x, \$y);",
                    "\$obj->$name(-1);",
                    "\$obj->$name(0, -1);",
                ],
            );
        }


        for my $name ("index_${field}", "${field}_index") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my ($self, @indices) = @_;
                    my @result = map { $self->{$field}[$_] } @indices;
                    return $result[0] if @indices == 1;
                    wantarray ? @result : \@result;
                },
                purpose => <<'EODOC',
Takes a list of indices and returns the elements indicated by those indices.
If only one index is given, the corresponding array element is returned. If
several indices are given, the result is returned as an array in list context
or as an array reference in scalar context.
EODOC
                example => [
                    "my \$element   = \$obj->$name(3);",
                    "my \@elements  = \$obj->$name(\@indices);",
                    "my \$array_ref = \$obj->$name(\@indices);",
                ],
            );
        }


        for my $name ("set_${field}", "${field}_set") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${$name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;

                    my $self = shift;
                    my @args = @_;
                    croak "${class}::${field}_set expects an even number of fields\n"
                        if @args % 2;
                    while (my ($index, $value) = splice @args, 0, 2) {
                        $self->{$field}->[$index] = $value;
                    }
                    return @_ / 2;
                },
                purpose => <<'EODOC',
Takes a list of index/value pairs and for each pair it sets the array element
at the indicated index to the indicated value. Returns the number of elements
that have been set.
EODOC
                example => "\$obj->$name(1 => \$x, 5 => \$y);",
            );
        }
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

#line 1561

