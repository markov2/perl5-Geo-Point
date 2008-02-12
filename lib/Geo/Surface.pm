
use strict;
use warnings;

package Geo::Surface;
use base 'Geo::Shape';

use Math::Polygon::Surface ();
use Math::Polygon::Calc    qw/polygon_bbox/;
use List::Util             qw/sum/;

use Carp;

=chapter NAME

Geo::Surface - A surface description.

=chapter SYNOPSIS

 my $island1 = Geo::Line->filled(...);
 my $island2 = Geo::Surface->new(...);
 my $islands = Geo::Surface->new($island1, $island2)

=chapter DESCRIPTION
In this context, a "surface" is defined as a set of filled areas with
possible enclosures in one projection system.  One set of islands
can be kept as one surface, or the shapefile data of a country.

=chapter OVERLOAD

=chapter METHODS

=section Constructors

=c_method new [COMPONENTS], [OPTIONS]
When called as instance method, some defaults are copied from the
object where the call is made upon.

COMPONENTS are M<Math::Polygon>, M<Math::Polygon::Surface>,
M<Geo::Line>, M<Geo::Surface> objects.  When an ARRAY is specfied as
COMPONENT, it will be used to instantiate a M<Math::Polygon::Surface>
object.  In case of a M<Geo::Surface>, the included polygons are
translated to the specified projection.

=warning Geo::Line is should be filled
When M<Geo::Line> objects are used to compose a surface, each of them
must be filled.  Representation of rivers and such do not belong in a
surface description.

=error not known what to do with $component

=cut

sub new(@)
{   my $thing = shift;
    my @components;
    push @components, shift while ref $_[0];
    my %args  = @_;

    my $class;
    if(ref $thing)    # instance method
    {   $args{proj} ||= $thing->proj;
        $class = ref $thing;
    }
    else
    {   $class = $thing;
    }

    my $proj = $args{proj};

    return () unless @components;

    my @surfaces;
    foreach my $component (@components)
    {
        if(ref $component eq 'ARRAY')
        {   $component = $class->new(@$component);
        }
        elsif(ref $component eq 'Math::Polygon')
        {   $component = Geo::Line->filled($component->points);
        }
        elsif(ref $component eq 'Math::Polygon::Surface')
        {   bless $component, $class;
        }

        if($component->isa('Geo::Point'))
        {   push @surfaces, $component;
        }   
        elsif($component->isa('Geo::Line'))
        {   carp "Warning: Geo::Line is should be filled."
                unless $component->isFilled;
            push @surfaces, defined $proj ? $component->in($proj) : $component;
        }
        elsif($component->isa('Geo::Surface'))
        {   if(defined $proj)
            {   push @surfaces,
                    map {$component->in($proj)} $component->components;
            }
            else
            {   push @surfaces, $component->components;
            }
        }
        else
        {   confess "ERROR: Do not known what to do with $component";
        }
    }

    $args{components} = \@surfaces;
    $thing->SUPER::new(%args);
}

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{GS_comp} = $args->{components};
    $self;
}

=section Attributes

=method components
Returns a list of M<Math::Polygon::Surface> objects, together forming
the surface.
=cut

sub components() { @{shift->{GS_comp}} }

=method component INDEX, [INDEX, ...]
Returns the component (or components) with the specified INDEX(es). One
M<Math::Polygon::Surface> in scalar context, and multiple in list context.
=cut

sub component(@)
{   my $self = shift;
    wantarray ? $self->{GS_comp}[shift] : @{$self->{GS_comp}}[@_];
}

=method nrComponents
Returns the number of components.
=cut

sub nrComponents() { scalar @{shift->{GS_comp}} }

=section Projections
=cut

sub in($)
{   my ($self, $projnew) = @_;
    return $self if ! defined $projnew || $projnew eq $self->proj;

    my @surfaces;
    foreach my $old ($self->components)
    {   my @newrings;
        foreach my $ring ($old->outer, $old->inner)
        {   ($projnew, my @points) = $self->projectOn($projnew, $ring->points);
            push @newrings, @points
             ? (ref $ring)->new(proj => $projnew, points => \@points) : $ring;
        }
        push @surfaces, (ref $old)->new(@newrings, proj => $projnew);
    }
  
    $self->new(@surfaces, proj => $projnew);
}

=section Geometry

=method equal OTHER, [TOLERANCE]
Detailed calculation whether two surfaces are equal is a lot of
work.  Therefore, only exactly equal surface descriptions are
considered equivalent.
=cut

sub equal($;$)
{   my ($self, $other, $tolerance) = @_;

    my $nr   = $self->nrComponents;
    return 0 if $nr != $other->nrComponents;

    my $proj = $other->proj;
    for(my $compnr = 0; $compnr < $nr; $compnr++)
    {   my $own = $self->component($compnr);
        my @own = $self->projectOn($proj, $own->points);

        $other->component($compnr)->equal(\@own, $tolerance)
            or return 0;
    }

    1;
}

=method bbox
The bounding box of the combined polygons.
=cut

sub bbox() {  polygon_bbox map { $_->outer->points } shift->components }

=method area
Returns the area enclosed by the combined components.  Only useful when
the points are in some orthogonal projection.
=cut

sub area() { sum map { $_->area } shift->components }

=method perimeter
The length of the outer polygons of all components. Only useful in a
orthogonal coordinate systems.
=cut

sub perimeter() { sum map { $_->perimeter } shift->components }

=section Display

=method toString [PROJECTION]
Returns a string representation of the line, which is also used for
stringification.

=cut

sub toString(;$)
{   my ($self, $proj) = @_;
    my $surface;
    if(defined $proj)
    {   $surface = $self->in($proj);
    }
    else
    {   $proj    = $self->proj;
        $surface = $self;
    }

      "surface[$proj]\n  ("
    . join(")\n  (", map {$_->toString} $surface->components)
    . ")\n";
}
*string = \&toString;

1;
