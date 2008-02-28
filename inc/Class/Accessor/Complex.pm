#line 1
package Class::Accessor::Complex;

use warnings;
use strict;
use Carp qw(carp croak cluck);
use Data::Miscellany 'flatten';
use List::MoreUtils 'uniq';


our $VERSION = '0.13';


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
Creates and returns a new object. The constructor will accept as arguments a
list of pairs, from component name to initial value. For each pair, the named
component is initialized by calling the method of the same name with the given
value. If called with a single hash reference, it is dereferenced and its
key/value pairs are set as described before.
EODOC
            example => [
                "my \$obj = $class->$name;",
                "my \$obj = $class->$name(\%args);",
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
        $self->install_accessor(
            name => $name,
            code => sub {
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
            },
            purpose => <<'EODOC',
Creates and returns a new object. The object will be a singleton, so repeated
calls to the constructor will always return the same object. The constructor
will accept as arguments a list of pairs, from component name to initial
value. For each pair, the named component is initialized by calling the
method of the same name with the given value. If called with a single hash
reference, it is dereferenced and its key/value pairs are set as described
before.
EODOC
            example => [
                "my \$obj = $class->$name;",
                "my \$obj = $class->$name(\%args);",
            ],
        );
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

        for my $name (uniq "clear_${field}", "${field}_clear") {
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

        $self->install_accessor(
            name => $field,
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                return $scalar if @_ == 1;
                $scalar = $_[1];
            },
            purpose => <<'EODOC',
A basic getter/setter method. This is a class variable, so it is shared
between all instances of this class. Changing it in one object will change it
for all other objects as well. If called without an argument, it returns the
value. If called with a single argument, it sets the value.
EODOC
            example => [
                "my \$value = \$obj->$field;",
                "\$obj->$field(\$value);",
            ],
        );

        for my $name (uniq "clear_${field}", "${field}_clear") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    $scalar = undef;
                },
                purpose => <<'EODOC',
Clears the value. Since this is a class variable, the value will be undefined
for all instances of this class.
EODOC
                example => "\$obj->$name;",
            );
        }
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

        $self->install_accessor(
            name => $field,
            code => sub {
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
            },
            # FIXME use the current value of $join in the docs
            purpose => <<'EODOC',
A getter/setter method. If called without an argument, it returns the
value. If called with a single argument, it appends to the current value.
EODOC
            example => [
                "my \$value = \$obj->$field;",
                "\$obj->$field(\$value);",
            ],
        );

        for my $name (uniq "clear_${field}", "${field}_clear") {
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


        for my $name (uniq "push_${field}", "${field}_push") {
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


        for my $name (uniq "pop_${field}", "${field}_pop") {
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


        for my $name (uniq "unshift_${field}", "${field}_unshift") {
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


        for my $name (uniq "shift_${field}", "${field}_shift") {
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


        for my $name (uniq "clear_${field}", "${field}_clear") {
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


        for my $name (uniq "count_${field}", "${field}_count") {
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


        for my $name (uniq "splice_${field}", "${field}_splice") {
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


        for my $name (uniq "index_${field}", "${field}_index") {
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


        for my $name (uniq "set_${field}", "${field}_set") {
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

        $self->install_accessor(
            name => $field,
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my ($self, @list) = @_;

                @array = map { ref $_ eq 'ARRAY' ? @$_ : ($_) } @list
                    if @list;

                wantarray ? @array : \@array
            },
            purpose => <<'EODOC',
Get or set the array values. If called without an arguments, it returns the
array in list context, or a reference to the array in scalar context. If
called with arguments, it expands array references found therein and sets the
values.

This is a class variable, so it is shared between all instances of this class.
Changing it in one object will change it for all other objects as well.
EODOC
            example => [
                "my \@values    = \$obj->$field;",
                "my \$array_ref = \$obj->$field;",
                "\$obj->$field(\@values);",
                "\$obj->$field(\$array_ref);",
            ],
        );


        for my $name (uniq "push_${field}", "${field}_push") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my $self = shift;
                    push @array => @_;
                },
                purpose => <<'EODOC',
Pushes elements onto the end of the array. Since this is a class variable, the
value will be changed for all instances of this class.
EODOC
                example => "\$obj->$name(\@values);",
            );
        }


        for my $name (uniq "pop_${field}", "${field}_pop") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    pop @array;
                },
                purpose => <<'EODOC',
Pops the last element off the array, returning it. Since this is a class
variable, the value will be changed for all instances of this class.
EODOC
                example => "my \$value = \$obj->$name;",
            );
        }


        for my $name (uniq "unshift_${field}", "${field}_unshift") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my $self = shift;
                    unshift @array => @_;
                },
                purpose => <<'EODOC',
Unshifts elements onto the beginning of the array. Since this is a class
variable, the value will be changed for all instances of this class.
EODOC
                example => "\$obj->$name(\@values);",
            );
        }


        for my $name (uniq "shift_${field}", "${field}_shift") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    shift @array;
                },
                purpose => <<'EODOC',
Shifts the first element off the array, returning it. Since this is a class
variable, the value will be changed for all instances of this class.
EODOC
                example => "my \$value = \$obj->$name;",
            );
        }


        for my $name (uniq "clear_${field}", "${field}_clear") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    @array = ();
                },
                purpose => <<'EODOC',
Deletes all elements from the array. Since this is a class variable, the value
will be changed for all instances of this class.
EODOC
                example => "\$obj->$name;",
            );
        }


        for my $name (uniq "count_${field}", "${field}_count") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    scalar @array;
                },
                purpose => <<'EODOC',
Returns the number of elements in the array. Since this is a class variable,
the value will be changed for all instances of this class.
EODOC
                example => "my \$count = \$obj->$name;",
            );
        }


        for my $name (uniq "splice_${field}", "${field}_splice") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my ($self, $offset, $len, @list) = @_;
                    splice(@array, $offset, $len, @list);
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

Since this is a class variable, the value will be changed for all instances of
this class.
EODOC
                example => [
                    "\$obj->$name(2, 1, \$x, \$y);",
                    "\$obj->$name(-1);",
                    "\$obj->$name(0, -1);",
                ],
            );
        }


        for my $name (uniq "index_${field}", "${field}_index") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my ($self, @indices) = @_;
                    my @result = map { $array[$_] } @indices;
                    return $result[0] if @indices == 1;
                    wantarray ? @result : \@result;
                },
                purpose => <<'EODOC',
Takes a list of indices and returns the elements indicated by those indices.
If only one index is given, the corresponding array element is returned. If
several indices are given, the result is returned as an array in list context
or as an array reference in scalar context.

Since this is a class variable, the value will be changed for all instances of
this class.
EODOC
                example => [
                    "my \$element   = \$obj->$name(3);",
                    "my \@elements  = \$obj->$name(\@indices);",
                    "my \$array_ref = \$obj->$name(\@indices);",
                ],
            );
        }


        for my $name (uniq "set_${field}", "${field}_set") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
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
                },
                purpose => <<'EODOC',
Takes a list of index/value pairs and for each pair it sets the array element
at the indicated index to the indicated value. Returns the number of elements
that have been set. Since this is a class variable, the value will be changed
for all instances of this class.
EODOC
                example => "\$obj->$name(1 => \$x, 5 => \$y);",
            );
        }
    }

    $self;  # for chaining
}


sub mk_hash_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {
        $self->install_accessor(
            name => $field,
            code => sub {
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
                                $self->{$field}{$subkey} = $value;
                            }
                            return wantarray
                                ? %{$self->{$field}} : $self->{$field};
                        } else {
                            cluck
                                "Unrecognized ref type for hash method: $type.";
                        }
                    } else {
                        return $self->{$field}{$key};
                    }
                } else {
                    while (1) {
                        my $key = shift @list;
                        defined $key or last;
                        my $value = shift @list;
                        defined $value or carp "No value for key $key.";
                        $self->{$field}{$key} = $value;
                    }
                    return wantarray ? %{$self->{$field}} : $self->{$field};
                }
            },
            purpose => <<'EODOC',
Get or set the hash values. If called without arguments, it returns the hash
in list context, or a reference to the hash in scalar context. If called
with a list of key/value pairs, it sets each key to its corresponding value,
then returns the hash as described before.

If called with exactly one key, it returns the corresponding value.

If called with exactly one array reference, it returns an array whose elements
are the values corresponding to the keys in the argument array, in the same
order. The resulting list is returned as an array in list context, or a
reference to the array in scalar context.

If called with exactly one hash reference, it updates the hash with the given
key/value pairs, then returns the hash in list context, or a reference to the
hash in scalar context.
EODOC
            example => [
                "my \%hash     = \$obj->$field;",
                "my \$hash_ref = \$obj->$field;",
                "my \$value    = \$obj->$field(\$key);",
                "my \@values   = \$obj->$field([ qw(foo bar) ]);",
                "\$obj->$field(\%other_hash);",
                "\$obj->$field(foo => 23, bar => 42);",
            ],
        );


        for my $name (uniq "clear_${field}", "${field}_clear") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my $self = shift;
                    $self->{$field} = {};
                },
                purpose => <<'EODOC',
Deletes all keys and values from the hash.
EODOC
                example => "\$obj->$name;",
            );
        }


        for my $name (uniq "keys_${field}", "${field}_keys") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    keys %{$_[0]->{$field}};
                },
                purpose => <<'EODOC',
Returns a list of all hash keys in no particular order.
EODOC
                example => "my \@keys = \$obj->$name;",
            );
        }


        for my $name (uniq "values_${field}", "${field}_values") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    values %{$_[0]->{$field}};
                },
                purpose => <<'EODOC',
Returns a list of all hash values in no particular order.
EODOC
                example => "my \@values = \$obj->$name;",
            );
        }


        for my $name (uniq "exists_${field}", "${field}_exists") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my ($self, $key) = @_;
                    exists $self->{$field} && exists $self->{$field}{$key};
                },
                purpose => <<'EODOC',
Takes a key and returns a true value if the key exists in the hash, and a
false value otherwise.
EODOC
                example => "if (\$obj->$name(\$key)) { ... }",
            );
        }


        for my $name (uniq "delete_${field}", "${field}_delete") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my ($self, @keys) = @_;
                    delete @{$self->{$field}}{@keys};
                },
                purpose => <<'EODOC',
Takes a list of keys and deletes those keys from the hash.
EODOC
                example => "\$obj->$name(\@keys);",
            );
        }

    }
    $self;  # for chaining
}


sub mk_class_hash_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {

        my %hash;

        $self->install_accessor(
            name => $field,
            code => sub {
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
                    cluck sprintf
                        'Not a recognized ref type for static hash [%s]',
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
            },
            purpose => <<'EODOC',
Get or set the hash values. If called without arguments, it returns the hash
in list context, or a reference to the hash in scalar context. If called
with a list of key/value pairs, it sets each key to its corresponding value,
then returns the hash as described before.

If called with exactly one key, it returns the corresponding value.

If called with exactly one array reference, it returns an array whose elements
are the values corresponding to the keys in the argument array, in the same
order. The resulting list is returned as an array in list context, or a
reference to the array in scalar context.

If called with exactly one hash reference, it updates the hash with the given
key/value pairs, then returns the hash in list context, or a reference to the
hash in scalar context.

This is a class variable, so it is shared between all instances of this class.
Changing it in one object will change it for all other objects as well.
EODOC
            example => [
                "my \%hash     = \$obj->$field;",
                "my \$hash_ref = \$obj->$field;",
                "my \$value    = \$obj->$field(\$key);",
                "my \@values   = \$obj->$field([ qw(foo bar) ]);",
                "\$obj->$field(\%other_hash);",
                "\$obj->$field(foo => 23, bar => 42);",
            ],
        );


        for my $name (uniq "clear_${field}", "${field}_clear") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    %hash = ();
                },
                purpose => <<'EODOC',
Deletes all keys and values from the hash. Since this is a class variable, the
value will be changed for all instances of this class.
EODOC
                example => "\$obj->$name;",
            );
        }


        for my $name (uniq "keys_${field}", "${field}_keys") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    keys %hash;
                },
                purpose => <<'EODOC',
Returns a list of all hash keys in no particular order. Since this is a class
variable, the value will be changed for all instances of this class.
EODOC
                example => "my \@keys = \$obj->$name;",
            );
        }


        for my $name (uniq "values_${field}", "${field}_values") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    values %hash;
                },
                purpose => <<'EODOC',
Returns a list of all hash values in no particular order. Since this is a
class variable, the value will be changed for all instances of this class.
EODOC
                example => "my \@values = \$obj->$name;",
            );
        }


        for my $name (uniq "exists_${field}", "${field}_exists") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    exists $hash{$_[1]};
                },
                purpose => <<'EODOC',
Takes a key and returns a true value if the key exists in the hash, and a
false value otherwise. Since this is a class variable, the value will be
changed for all instances of this class.
EODOC
                example => "if (\$obj->$name(\$key)) { ... }",
            );
        }


        for my $name (uniq "delete_${field}", "${field}_delete") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my ($self, @keys) = @_;
                    delete @hash{@keys};
                },
                purpose => <<'EODOC',
Takes a list of keys and deletes those keys from the hash. Since this is a
class variable, the value will be changed for all instances of this class.
EODOC
                example => "\$obj->$name(\@keys);",
            );
        }

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
        $self->install_accessor(
            name => $field,
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                return $_[0]->{$field} if @_ == 1;
                $_[0]->{$field} = $_[1] ? 1 : 0;   # normalize
            },
            purpose => <<'EODOC',
If called without an argument, returns the boolean value (0 or 1). If called
with an argument, it normalizes it to the boolean value. That is, the values
0, undef and the empty string become 0; everything else becomes 1.
EODOC
            example => [
                "\$obj->$field(\$value);",
                "my \$value = \$obj->$field;",
            ],
        );


        for my $name (uniq "set_${field}", "${field}_set") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    $_[0]->{$field} = 1;
                },
                purpose => <<'EODOC',
Sets the boolean value to 1.
EODOC
                example => "\$obj->$name;",
            );
        }


        for my $name (uniq "clear_${field}", "${field}_clear") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    $_[0]->{$field} = 0;
                },
                purpose => <<'EODOC',
Clears the boolean value by setting it to 0.
EODOC
                example => "\$obj->$name;",
            );
        }
    }

    $self;  # for chaining
}


sub mk_integer_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {
        $self->install_accessor(
            name => $field,
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my $self = shift;
                return $self->{$field} || 0 unless @_;
                $self->{$field} = shift;
            },
            purpose => <<'EODOC',
A basic getter/setter method. If called without an argument, it returns the
value, or 0 if there is no previous value. If called with a single argument,
it sets the value.
EODOC
            example => [
                "\$obj->$field(\$value);",
                "my \$value = \$obj->$field;",
            ],
        );


        for my $name (uniq "reset_${field}", "${field}_reset") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    $_[0]->{$field} = 0;
                },
                purpose => <<'EODOC',
Resets the value to 0.
EODOC
                example => "\$obj->$name;",
            );
        }


        for my $name (uniq "inc_${field}", "${field}_inc") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    $_[0]->{$field}++;
                },
                purpose => <<'EODOC',
Increases the value by 1.
EODOC
                example => "\$obj->$name;",
            );
        }


        for my $name (uniq "dec_${field}", "${field}_dec") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    $_[0]->{$field}--;
                },
                purpose => <<'EODOC',
Decreases the value by 1.
EODOC
                example => "\$obj->$name;",
            );
        }
    }

    $self;  # for chaining
}


sub mk_set_accessors {
    my ($self, @fields) = @_;
    my $class = ref $self || $self;

    for my $field (@fields) {
        my $insert_method   = "${field}_insert";
        my $elements_method = "${field}_elements";


        $self->install_accessor(
            name => $field,
            code => sub {
                local $DB::sub = local *__ANON__ = "${class}::${field}"
                    if defined &DB::DB && !$Devel::DProf::VERSION;
                my $self = shift;
                if (@_) {
                    $self->$insert_method(@_);
                } else {
                    $self->$elements_method;
                }
            },
            purpose => <<'EODOC',
A set is like an array except that each element can occur only one. It is,
however, not ordered. If called with a list of arguments, it adds those
elements to the set. If the first argument is an array reference, the values
contained therein are added to the set. If called without arguments, it
returns the elements of the set.
EODOC
            example => [
                "my \@elements = \$obj->$field;",
                "\$obj->$field(\@elements);",
            ],
        );


        for my $name (uniq "insert_${field}", $insert_method) {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my $self = shift;
                    $self->{$field}{$_}++ for flatten(@_);
                },
                purpose => <<'EODOC',
If called with a list of arguments, it adds those elements to the set. If the
first argument is an array reference, the values contained therein are added
to the set.
EODOC
                example => "\$obj->$name(\@elements);",
            );
        }


        for my $name (uniq "elements_${field}", $elements_method) {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my $self = shift;
                    $self->{$field} ||= {};
                    keys %{ $self->{$field} }
                },
                purpose => <<'EODOC',
Returns the elements of the set.
EODOC
                example => "my \@elements = \$obj->$name;",
            );
        }


        for my $name (uniq "delete_${field}", "${field}_delete") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my $self = shift;
                    delete $self->{$field}{$_} for @_;
                },
                purpose => <<'EODOC',
If called with a list of values, it deletes those elements from the set.
EODOC
                example => "\$obj->$name(\@elements);",
            );
        }


        for my $name (uniq "clear_${field}", "${field}_clear") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    $_[0]->{$field} = {};
                },
                purpose => <<'EODOC',
Deletes all elements from the set.
EODOC
                example => "\$obj->$name;",
            );
        }


        for my $name (uniq "contains_${field}", "${field}_contains") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my ($self, $key) = @_;
                    return unless defined $key;
                    exists $self->{$field}{$key};
                },
                purpose => <<'EODOC',
Takes a single key and returns a boolean value indicating whether that key is
an element of the set.
EODOC
                example => "if (\$obj->$name(\$element)) { ... }",
            );
        }


        for my $name (uniq "is_empty_${field}", "${field}_is_empty") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my $self = shift;
                    keys %{ $self->{$field} || {} } == 0;
                },
                purpose => <<'EODOC',
Returns a boolean value indicating whether the set is empty of not.
EODOC
                example => "\$obj->$name;",
            );
        }


        for my $name (uniq "size_${field}", "${field}_size") {
            $self->install_accessor(
                name => $name,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${name}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my $self = shift;
                    scalar keys %{ $self->{$field} || {} };
                },
                purpose => <<'EODOC',
Returns the number of elements in the set.
EODOC
                example => "my \$size = \$obj->$name;",
            );
        }
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
        my @list = ref($list) eq 'ARRAY' ? @$list : ($list);

        for my $obj_def (@list) {

            my ($name, @composites);
            if (!ref $obj_def) {
                $name = $obj_def;
            } else {
                $name = $obj_def->{slot};
                my $composites = $obj_def->{comp_mthds};
                @composites = ref($composites) eq 'ARRAY' ? @$composites
                    : defined $composites ? ($composites) : ();
            }

            for my $meth (@composites) {
                $self->install_accessor(
                    name => $meth,
                    code => sub {
                        local $DB::sub = local *__ANON__ = "${class}::{$meth}"
                            if defined &DB::DB && !$Devel::DProf::VERSION;
                        my ($self, @args) = @_;
                        $self->$name()->$meth(@args);
                    },
                    purpose => <<EODOC,
Calls $meth() with the given arguments on the object stored in the $name slot.
If there is no such object, a new $type object is constructed - no arguments
are passed to the constructor - and stored in the $name slot before forwarding
$meth() onto it.
EODOC
                    example => [
                        "\$obj->$meth(\@args);",
                        "\$obj->$meth;",
                    ],
                );
            }

            $self->install_accessor(
                name => $name,
                code => sub {
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
                },
                purpose => <<EODOC,
If called with an argument object of type $type it sets the object; further
arguments are discarded. If called with arguments but the first argument is
not an object of type $type, a new object of type $type is constructed and the
arguments are passed to the constructor.

If called without arguments, it returns the $type object stored in this slot;
if there is no such object, a new $type object is constructed - no arguments
are passed to the constructor in this case - and stored in the $name slot
before returning it.
EODOC
                example => [
                    "my \$object = \$obj->$name;",
                    "\$obj->$name(\$object);",
                    "\$obj->$name(\@args);",
                ],
            );


            for my $meth ("clear_${name}", "${name}_clear") {
                $self->install_accessor(
                    name => $meth,
                    code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${meth}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    delete $_[0]->{$name};
                    },
                    purpose => <<'EODOC',
Deletes the object.
EODOC
                    example => "\$obj->$meth;",
                );
            }
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
            $self->install_accessor(
                name => $field,
                code => sub {
                    local $DB::sub = local *__ANON__ = "${class}::${field}"
                        if defined &DB::DB && !$Devel::DProf::VERSION;
                    my ($self, @args) = @_;
                    $self->$slot()->$field(@args);
                },
                purpose => <<EODOC,
Calls $field() with the given arguments on the object stored in the $slot
slot. 
EODOC
                example => [
                    "\$obj->$field(\@args);",
                    "\$obj->$field;",
                ],
            );
        }
    }

    $self;  # for chaining
}


1;

__END__

{% USE p = PodGenerated %}

#line 1990

