
use strict;
use warnings;

package Geo::Surface;
use base 'Geo::Shape';

use Math::Polygon::Surface ();
use Math::Polygon::Calc    qw/polygon_bbox/;
use List::Util             qw/sum first/;

use Carp;

=chapter NAME

Geo::Surface - A surface description.

=chapter SYNOPSIS

 my $island = Geo::Surface->new($outer, $lake1, $lake2);

=chapter DESCRIPTION
In this context, a "surface" is defined as a single filled area with
possible enclosures in one projection system.

=chapter OVERLOAD

=chapter METHODS

=section Constructors

=c_method new <$surface | <$outer,$inner,...> >, %options
When called as instance method, some defaults are copied from the
object where the call is made upon.

You may either provide a M<Math::Polygon::Surface> $surface, or a LIST
of lines.  In the latter case, the first line is the $outer polygon of
the surface, and the other are all $inner enclosures: lakes.  Lines
are and M<Geo::Line>, M<Math::Polygon> objects, or ARRAY of points.

If no projection is specified, then the projection of the first
Geo-encoded line will be used.

=warning Geo::Line is should be filled
When M<Geo::Line> objects are used to compose a surface, each of them
must be filled.  Representation of rivers and such do not belong in a
surface description.

=error not known what to do with $component

=cut

sub new(@)
{   my $thing = shift;
    my @lines;
    push @lines, shift while ref $_[0];
    @lines or return ();

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
    unless($proj)
    {   my $s = first { UNIVERSAL::isa($_, 'Geo::Shape') } @lines;
        $args{proj} = $proj = $s->proj if $s;
    }

    my $mps;
    if(@lines==1 && UNIVERSAL::isa($_, 'Math::Polygon::Surface'))
    {   $mps = shift @lines;
    }
    else
    {   my @polys;
        foreach (@lines)
        {   push @polys
              , UNIVERSAL::isa($_, 'Geo::Line'    ) ? [$_->in($proj)->points]
              : UNIVERSAL::isa($_, 'Math::Polygon') ? $_
              : UNIVERSAL::isa($_, 'ARRAY'        ) ? Math::Polygon->new(@$_)
              : croak "ERROR: Do not known what to do with $_";
        }
        $mps = Math::Polygon::Surface->new(@polys);
    }

    $args{_mps} = $mps;
    $thing->SUPER::new(%args);
}

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{GS_mps} = $args->{_mps};
    $self;
}

=section Attributes

=method outer
Returns the outer M<Math::Polygon>.
=method geoOuter
Returns the outer polygon as M<Geo::Line> object.

=method inner
Returns a LIST of enclosed M<Math::Polygon> objects.
=method geoInner
Returns a LIST of enclosed polygons, converted to M<Geo::Line> objects.

=cut

sub outer() { shift->{GS_mps}->outer }
sub inner() { shift->{GS_mps}->inner }

sub geoOuter()
{   my $self = shift;
    Geo::Line->new(points => [$self->outer->points], proj => $self->proj);
}


sub geoInner()
{   my $self = shift;
    my $proj = $self->proj;
    map { Geo::Line->new(points => [$_->points], proj => $proj) } $self->inner;
}

*geo_outer = \&geoOuter;
*geo_inner = \&geoInner;

#--------------
=section Projections
=cut

sub in($)
{   my ($self, $projnew) = @_;
    return $self if ! defined $projnew || $projnew eq $self->proj;

    my @newrings;
    foreach my $ring ($self->outer, $self->inner)
    {   (undef, my @points) = $self->projectOn($projnew, $ring->points);
        push @newrings, \@points;
    }
    my $mp = Math::Polygon::Surface->new(@newrings);
    (ref $self)->new($mp, proj => $projnew);
}

=section Geometry

=method bbox
The bounding box of outer surface polygon.
=cut

sub bbox() { polygon_bbox shift->outer->points }

=method area
Returns the area enclosed by the outer polygon, minus the erea of
the enclosures.  Only useful when the points are in some orthogonal
projection.
=cut

sub area()
{   my $self = shift;
    my $area = $self->outer->area;
    $area   -= $_->area for $self->inner;
    $area;
}

=method perimeter
The length of the outer polygon. Only useful in a orthogonal
coordinate systems.
=cut

sub perimeter() { shift->outer->perimeter }

=section Display

=method toString [$projection]
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

    my $mps = $self->{GS_mps}->string;
    $mps    =~ s/\n-/)\n -(/;
    "surface[$proj]\n  ($mps)\n";
}
*string = \&toString;

1;
