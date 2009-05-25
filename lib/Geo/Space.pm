
use strict;
use warnings;

package Geo::Space;
use base 'Geo::Shape';

use Math::Polygon::Calc    qw/polygon_bbox/;
use List::Util             qw/sum first/;

=chapter NAME

Geo::Space - A collection of various  items

=chapter SYNOPSIS

 my $island1 = Geo::Line->filled(...);
 my $island2 = Geo::Space->new(...);
 my $islands = Geo::Space->new($island1, $island2)

=chapter DESCRIPTION
Where a M<Geo::Surface> can only contains sets of nested polygons, the
Space can contain anything you like: lines, points, and unrelated polygons.

=chapter OVERLOAD

=chapter METHODS

=section Constructors

=ci_method new [COMPONENTS], [OPTIONS]
When called as instance method, some defaults are copied from the
object where the call is made upon.  Usually called as class method.

COMPONENTS are M<Math::Polygon>, M<Math::Polygon::Surface>,
M<Geo::Point>, M<Geo::Line>, M<Geo::Surface>, M<Geo::Space> objects.

=cut

sub new(@)
{   my $thing = shift;
    my @components;
    push @components, shift while ref $_[0];
    my %args  = @_;

    if(ref $thing)    # instance method
    {   $args{proj} ||= $thing->proj;
    }

    my $proj = $args{proj};
    return () unless @components;

    $thing->SUPER::new(components => \@components);
}

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);

    $self->{GS_comp} = $args->{components} || [];
    $self;
}

=section Attributes

=method components
Returns a list of M<Geo::Shape> objects, all located in this space.
=cut

sub components() { @{shift->{GS_comp}} }

=method component INDEX, [INDEX, ...]
Returns the component (or components) with the specified INDEX(es). One
M<Geo::Shape> object in scalar context, and multiple in list context.
=cut

sub component(@)
{   my $self = shift;
    wantarray ? $self->{GS_comp}[shift] : @{$self->{GS_comp}}[@_];
}

=method nrComponents
Returns the number of components.
=cut

sub nrComponents() { scalar @{shift->{GS_comp}} }

=method points
Returns a list of M<Geo::Point> objects, which are defined as separate
components.
=cut

sub points()     { grep {$_->isa('Geo::Points')} shift->components }

=method onlyPoints
Returns true when all components are points; M<Geo::Point> objects.
=cut

sub onlyPoints() { not first {! $_->isa('Geo::Points')} shift->components }

=method lines
Returns a list of M<Geo::Line> objects, which are defined as separate
components.
=cut

sub lines()      { grep {$_->isa('Geo::Line')} shift->components }

=method onlyLines
Returns true when all components are lines; M<Geo::Line> objects.
=cut

sub onlyLines()  { not first {! $_->isa('Geo::Line')} shift->components }

=method onlyRings
Returns true when all components are closed lines; M<Geo::Line> objects
each defined as ring.
=cut

sub onlyRings()  { not first {! $_->isa('Geo::Line') || ! $_->isRing}
                         shift->components }

=section Projections
=cut

sub in($)
{   my ($self, $projnew) = @_;
    return $self if ! defined $projnew || $projnew eq $self->proj;

    my @t;

    foreach my $component ($self->components)
    {   ($projnew, my $t) = $component->in($projnew);
        push @t, $t;
    }

    (ref $self)->new(@t, proj => $projnew);
}

=section Geometry
=cut

sub bbox()
{   my $self = shift;
    my @bboxes = map { [$_->bbox] } $self->components;
    polygon_bbox(map { ([$_->[0], $_->[1]], [$_->[2], $_->[3]]) } @bboxes);
}

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

=examples
=cut

sub toString(;$)
{   my ($self, $proj) = @_;
    my $space;
    if(defined $proj)
    {   $space = $self->in($proj);
    }
    else
    {   $proj  = $self->proj;
        $space = $self;
    }

      "space[$proj]\n  ("
    . join(")\n  (", map {$_->string} $space->components)
    . ")\n";
}
*string = \&toString;

1;
