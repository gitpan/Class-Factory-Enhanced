package Class::Factory::Patched;

# $Id: Factory.pm 40 2006-08-02 05:51:40Z cwinters $

use strict;

$Class::Factory::Patched::VERSION = '1.05';

my %CLASS_BY_FACTORY_AND_TYPE  = ();
my %FACTORY_INFO_BY_CLASS      = ();
my %REGISTER                   = ();

# Simple constructor -- override as needed

sub new {
    my ( $pkg, $type, @params ) = @_;
    my $class = $pkg->get_factory_class( $type );
    return undef unless ( $class );
    my $self = bless( {}, $class );
    return $self->init( @params );
}


# Subclasses should override, but if they don't they shouldn't be
# penalized...

sub init { return $_[0] }

# Find the class associated with $object_type

sub get_factory_class {
    my ( $item, $object_type ) = @_;
    my $class = ref $item || $item;
    my $factory_class =
        $CLASS_BY_FACTORY_AND_TYPE{ $class }->{ $object_type };
    return $factory_class if ( $factory_class );

    $factory_class = $REGISTER{ $class }->{ $object_type };
    if ( $factory_class ) {
        my $added_class =
            $class->add_factory_type( $object_type, $factory_class );
        return $added_class;
    }
    $item->factory_error( "Factory type '$object_type' is not defined ",
                          "in '$class'" );
    return undef;
}


# Associate $object_type with $object_class

sub add_factory_type {
    my ( $item, $object_type, $object_class ) = @_;
    my $class = ref $item || $item;
    unless ( $object_type )  {
        $item->factory_error( "Cannot add factory type to '$class': no ",
                              "type defined");
    }
    unless ( $object_class ) {
        $item->factory_error( "Cannot add factory type '$object_type' to ",
                              "'$class': no class defined" );
    }

    my $set_object_class =
        $CLASS_BY_FACTORY_AND_TYPE{ $class }->{ $object_type };
    if ( $set_object_class ) {
        $item->factory_log( "Attempt to add type '$object_type' to '$class' ",
                            "redundant; type already exists with class ",
                            "'$set_object_class'" );
        return;
    }

    # Make sure the object class looks like a perl module/script
    # Acceptable formats:
    #   Module.pm  Module.ph  Module.pl  Module
    $object_class =~ m/^([\w:-]+(?:\.(?:pm|ph|pl))?)$/;
    $object_class = $1;

    if ( $INC{ $object_class } ) {
        $item->factory_log( "Looks like class '$object_class' was already ",
                            "included; no further work necessary" );
    }
    else {
        eval "require $object_class";
        if ( $@ ) {
            $item->factory_error( "Cannot add factory type '$object_type' to ",
                                  "class '$class': factory class '$object_class' ",
                                  "cannot be required: $@" );
            return undef;
        }
    }

    # keep track of what classes have been included so far...
    $CLASS_BY_FACTORY_AND_TYPE{ $class }->{ $object_type } = $object_class;

    # keep track of what factory and type are associated with a loaded
    # class...
    $FACTORY_INFO_BY_CLASS{ $object_class } = [ $class, $object_type ];

    return $object_class;
}

sub register_factory_type {
    my ( $item, $object_type, $object_class ) = @_;
    my $class = ref $item || $item;
    unless ( $object_type )  {
        $item->factory_error( "Cannot add factory type to '$class': no type ",
                              "defined" );
    }
    unless ( $object_class ) {
        $item->factory_error( "Cannot add factory type '$object_type' to ",
                              "'$class': no class defined" );
    }

    my $set_object_class = $REGISTER{ $class }->{ $object_type };
    if ( $set_object_class ) {
        $item->factory_log( "Attempt to register type '$object_type' with ",
                            "'$class' is redundant; type registered with ",
                            "class '$set_object_class'" );
        return;
    }
    return $REGISTER{ $class }->{ $object_type } = $object_class;
}


sub get_loaded_classes {
    my ( $item ) = @_;
    my $class = ref $item || $item;
    return () unless ( ref $CLASS_BY_FACTORY_AND_TYPE{ $class } eq 'HASH' );
    return sort values %{ $CLASS_BY_FACTORY_AND_TYPE{ $class } };
}

sub get_loaded_types {
    my ( $item ) = @_;
    my $class = ref $item || $item;
    return () unless ( ref $CLASS_BY_FACTORY_AND_TYPE{ $class } eq 'HASH' );
    return sort keys %{ $CLASS_BY_FACTORY_AND_TYPE{ $class } };
}

sub get_registered_classes {
    my ( $item ) = @_;
    my $class = ref $item || $item;
    return () unless ( ref $REGISTER{ $class } eq 'HASH' );
    return sort values %{ $REGISTER{ $class } };
}

sub get_registered_class {
	my ( $item, $type ) = @_;
	unless ( $type ) {
	    warn("No factory type passed");
		return undef;
	}
    my $class = ref $item || $item;
    return undef unless ( ref $REGISTER{ $class } eq 'HASH' );
	return $REGISTER{ $class }{ $type };
}

sub get_registered_types {
    my ( $item ) = @_;
    my $class = ref $item || $item;
    return () unless ( ref $REGISTER{ $class } eq 'HASH' );
    return sort keys %{ $REGISTER{ $class } };
}

# Return the factory class that created $item (which can be an object
# or class)

sub get_my_factory {
    my ( $item ) = @_;
    my $impl_class = ref( $item ) || $item;
    my $impl_info = $FACTORY_INFO_BY_CLASS{ $impl_class };
    if ( ref( $impl_info ) eq 'ARRAY' ) {
        return $impl_info->[0];
    }
    return undef;
}

# Return the type that the factory used to create $item (which can be
# an object or class)

sub get_my_factory_type {
    my ( $item ) = @_;
    my $impl_class = ref( $item ) || $item;
    my $impl_info = $FACTORY_INFO_BY_CLASS{ $impl_class };
    if ( ref( $impl_info ) eq 'ARRAY' ) {
        return $impl_info->[1];
    }
    return undef;
}

########################################
# Overridable Log / Error

sub factory_log   { shift; warn @_, "\n" }
sub factory_error { shift; die @_, "\n" }


# BEGIN PATCH

sub remove_factory_type {
    my ( $item, @object_types ) = @_;
    my $class = ref $item || $item;

    for my $object_type (@object_types) {
        unless ( $object_type )  {
            $item->factory_error(
                "Cannot remove factory type from '$class': no type defined"
            );
        }

        delete $CLASS_BY_FACTORY_AND_TYPE{ $class }->{ $object_type };
    }
}

sub unregister_factory_type {
    my ( $item, @object_types ) = @_;
    my $class = ref $item || $item;

    for my $object_type (@object_types) {
        unless ( $object_type )  {
            $item->factory_error(
                "Cannot remove factory type from '$class': no type defined"
            );
        }

        delete $REGISTER{ $class }->{ $object_type };

        # Also delete from $CLASS_BY_FACTORY_AND_TYPE because if the object
        # type has already been instantiated, then it will have been processed
        # by add_factory_type(), thus creating an entry in
        # $CLASS_BY_FACTORY_AND_TYPE. We can call register_factory_type()
        # again, but when we try to instantiate an object via
        # get_factory_class(), it will find the old entry in
        # $CLASS_BY_FACTORY_AND_TYPE and use that.

        delete $CLASS_BY_FACTORY_AND_TYPE{ $class }->{ $object_type };
    }
}


sub get_factory_type_for {
    my ( $self, $item ) = @_;
    my $impl_class = ref( $item ) || $item;
    my $impl_info = $FACTORY_INFO_BY_CLASS{ $impl_class };
    if ( ref( $impl_info ) eq 'ARRAY' ) {
        return $impl_info->[1];
    }
    return undef;
}


# END PATCH


1;

__END__

=head1 NAME

Class::Factory::Patched - Patched version of Class::Factory

=head1 SYNOPSIS

See L<Class::Factory>

=head1 DESCRIPTION

This is a patched version of L<Class::Factory>. It is included because
Class::Factory has closures over lexical variables, and those variables cannot
be accessed from the outside. It also doesn't allow to add or register
mappings that have already been defined.

However, I need to override mappings. You can see an example in the tests of
L<Class::Accessor::FactoryTyped>, but basically the idea is this:

A person object has a name object and an address object. This person object is
used in two different applications. One application wants the person to just
have a single fullname string and a single address string. The other
application wants the name to be split into first name and last name, and the
address to be split into street address, postal code, city and country.

The second application needs to inherit from the first application because it
shares a lot of common characteristics with it.

We would still like to use the same person object, though, because it
interacts with other parts of the application in some standard way.

So the first application would tell the factory to map the C<person_name> to a
class that just has a simple fullname string and the C<person_address> to a
class that just has a simple address string.

The second application, because it inherits from the first application, also
inherits the factory, but redefines the C<person_name> and C<person_address>
object types to point to the more complex implementations.

This isn't possible with Class::Factory alone, because when the second
application tries to redefine the mappings, Class::Factory doesn't allow it.

Therefore I propose the following additions to Class::Factory. If and when the
author of Class::Factory includes them in Class::Factory, this patch module
will go away.

=head1 PATCHES

=over 4

=item remove_factory_type

Takes a list of object types and removes them from the factory. This is the
opposite of C<add_factory_type()>.

=item unregister_factory_type

Takes a list of object types and unregisters them from the factory. This is
the opposite of C<register_factory_type()>.

=back

=head1 TAGS

If you talk about this module in blogs, on del.icio.us or anywhere else,
please use the C<classfactoryenhanced> tag.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-class-factory-enhanced@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 INSTALLATION

See perlmodinstall for information and options on installing Perl modules.

=head1 AVAILABILITY

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit <http://www.perl.com/CPAN/> to find a CPAN site
near you. Or see <http://www.perl.com/CPAN/authors/id/M/MA/MARCEL/>.

=head1 AUTHOR

Marcel GrE<uuml>nauer, C<< <marcel@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Marcel GrE<uuml>nauer

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

