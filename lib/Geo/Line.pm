
use strict;
use warnings;

package Geo::Line;
use base qw/Geo::Shape Math::Polygon/;

use Carp;
use List::Util    qw/min max/;
use Scalar::Util  qw/refaddr/;

use Math::Polygon ();

=chapter NAME

Geo::Line - a sequence of connected points

=chapter SYNOPSIS

 !!!! BETA code, see README !!!!
 my $line  = Geo::Line->new(points => [$p1, $p2]);
 my $line  = Geo::Line->line($p1, $p2);

 my $ring  = Geo::Line->ring($p1, $p2, $p3, $p1);
 my $ring  = Geo::Line->ring($p1, $p2, $p3);

 my $plane = Geo::Line->filled($p1, $p2, $p3, $p1);
 my $plane = Geo::Line->filled($p1, $p2, $p3);

=chapter DESCRIPTION
A 2-dimensional sequence of connected points.  The points will be forced
to use the same projection.

=chapter OVERLOAD

=chapter METHODS

=section Constructors

=ci_method new [OPTIONS], [POINTS], [OPTIONS]
When called as instance method, the projection, ring, and filled attributes
are taken from the initiator.

=option  points ARRAY-OF-POINTS|ARRAY-OF-COORDINATES
=default points <data>
With this option, you can specify either M<Geo::Point> objects, or
coordinate pairs which will get transformed into such objects.  WARNING:
in that case, the coordinates must be in xy order.

=option  ring   BOOLEAN
=default ring   <false>
The first point is the last point.  When specified, you have to make
sure that this is the case.  If M<ring()> is used to create this object,
that routine will check/repair it for you.

=option  filled BOOLEAN
=default filled <false>
Implies ring.  The filled of the ring is included in the geometrical
shape.

=examples
 my $point = Geo::Point->xy(1, 2);
 my $line  = Geo::Line->new
   ( points => [$point, [3,4], [5,6], $point]
   , ring   => 1
   )'

=cut

sub new(@)
{   return shift->Math::Polygon::new(@_)
        unless ref $_[0];

    # instance method
    my $parent = shift;
    $parent->Math::Polygon::new
      ( ring   => $parent->{GL_ring}
      , filled => $parent->{GL_fill}
      , proj   => $parent->proj
      , @_
      );
}

sub init($)
{   my ($self, $args) = @_;
    $self->Geo::Shape::init($args);
    $self->Math::Polygon::init($args);

    $self->{GL_ring} = $args->{ring} || $args->{filled};
    $self->{GL_fill} = $args->{filled};
    $self->{GL_bbox} = $args->{bbox};
    $self;
}

=ci_method line POINTS, OPTIONS
construct a line, which will probably not have the same begin and end
point.  The POINTS are passed as M<new(points)>, and the other OPTIONS
are passed to M<new()> as well.
=cut

sub line(@)
{   my $thing = shift;
    my @points;
    push @points, shift while @_ && ref $_[0];
    $thing->new(points => \@points, @_);
}

=ci_method ring POINTS, OPTIONS
The first and last point will be made the same: if not yet, than a reference
to the first point is appended to the list.  A "ring" does not cover the
internal.
=cut

sub ring(@)
{   my $thing = shift;
    my @points;
    push @points, shift while @_ && ref $_[0];

    # close ring
    my ($first, $last) = @points[0, -1];
    my ($x0, $y0) = ref $first eq 'ARRAY' ? @$first : ($first->x, $first->y);
    my ($x1, $y1) = ref $last  eq 'ARRAY' ? @$last  : ($last->x,  $last->y);
    push @points, $first unless $x0==$x1 && $y0==$y1;

    $thing->new(points => \@points, @_, ring => 1);
}

=ci_method filled POINTS, OPTIONS
The POINTS form a M<ring()> and the filled is part of the geometrical
shape.
=cut

sub filled(@)
{   my $thing = shift;
    $thing->ring(@_, filled => 1);
}

=c_method bboxFromString STRING, {PROJECTION]
Create a square from the STRING.  The coordinates can be separated by
a comma (preferrably), or blanks.  When the coordinates end on NSEW, the
order does not matter, otherwise lat-long or xy order is presumed.

This routine is very smart.  It understands 
 PROJLABEL: <4 coordinates in any order, but with NSEW>
 ...

=examples bbox from string
 
 my $x = '5n 2n 3e e12';       # coordinates in any order
 my $x = '5e , 2n, 3n, e12';    # coordinates in any order
 my $x = '2.12-23.1E, N1-4';   # stretches
 my $x = 'wgs84: 2-5e, 1-8n';  # starts with projection
 my $x = 'wgs84: e2d12' -3d, n1, n7d12'34"';

 my ($xmin, $ymin, $xmax, $ymax, $proj)
    = Geo::Line->bboxFromString($x);

 my $p = Geo::Line->ringFromString($x);

 # When parsing user applications, you probably want:
 my $p = eval { Geo::Line->bboxFromString($x) };
 warn $@ if $@;

=cut

sub bboxFromString($;$)
{   my ($class, $string, $nick) = @_;

    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return () unless length $string;

    # line starts with project label
    $nick = $1 if $string =~ s/^(\w+)\s*\:\s*//;

    # Split the line
    my @parts = $string =~ m/\,/ ? split(/\s*\,\s*/, $string) : ($string);

    # expand dashes
    @parts = map { m/^([nesw])(\d.*?)\s*\-\s*(\d.*?)\s*$/i ?    ($1.$2, $1.$3)
                 : m/^(\d.*?)([nesw])\s*\-\s*(\d.*?)\s*$/i ?    ($2.$1, $2.$3)
                 : m/^(\d.*?)\s*\-\s*(\d.*?)\s*([nesw])\s*$/i ? ($1.$3, $2.$3)
                 : $_
                 } @parts;

    # split on blanks
    @parts = map { split /\s+/, $_ } @parts;

    # Now, the first word may be a projection.  That is: any non-coordinate,
    # anything which starts with more than one letter.
    if($parts[0] =~ m/^[a-z_]{2}/i)
    {   $nick = lc(shift @parts);   # overrules default
    }

    $nick  ||= Geo::Proj->defaultProjection;
    my $proj = Geo::Proj->projection($nick);

    die "ERROR: Too few values in $string (got @parts, expect 4)\n"
       if @parts < 4;

    die "ERROR: Too many values in $string (got @parts, expect 4)"
       if @parts > 4;

    unless($proj)
    {   die "ERROR: No projection defined for $string\n";
        return undef;
    }

    if(! $proj->proj4->isLatlong)
    {   die "ERROR: can only handle latlong coordinates, on the moment\n";
    }

    my(@lats, @longs);
    foreach my $part (@parts)
    {   if($part =~ m/[ewEW]$/ || $part =~ m/^[ewEW]/)
        {   my $lat = $class->dms2deg($part);
            defined $lat
               or die "ERROR: dms latitude coordinate not understood: $part\n";
            push @lats, $lat;
        }
        else
        {   my $long = $class->dms2deg($part);
            defined $long
               or die "ERROR: dms longitude coordinate not understood: $part\n";
            push @longs, $long;
        }
    }

    die "ERROR: expect to two lats and two longs, but got "
      . @lats."/".@longs."\n"  if @lats!=2;

    (min(@lats), min(@longs), max(@lats), max(@longs), $nick);
}


=c_method ringFromString STRING, [PROJECTION]
Calls M<bboxFromString()> and then produces a ring object from than.
Don't forget the C<eval> when you call this method.
=cut

sub ringFromString($;$)
{   my $class = shift;
    my ($xmin, $ymin, $xmax, $ymax, $nick) = $class->bboxFromString(@_)
        or return ();

    $class->bboxRing($xmin, $ymin, $xmax, $ymax, $nick);
}

=section Attributes

=method geopoints
In LIST context, this returns all points as separate scalars: each is a
M<Geo::Point> with projection information.  In SCALAR context, a
reference to the coordinates is returned.

With M<points()>, you get arrays with XY coordinates returned, but
without the projection information.  That will be much faster, but
not sufficient for some uses.
=cut

sub geopoints()
{   my $self = shift;
    my $proj = $self->proj;

    map { Geo::Point->new(x => $_->[0], y => $_->[1], proj => $proj) }
        $self->points;
}

=method geopoint INDEX, [INDEX, ..]
Returns the M<Geo::Point> for the point with the specified INDEX or
indices.
=cut

sub geopoint(@)
{   my $self = shift;
    my $proj = $self->proj;

    unless(wantarray)
    {   my $p = $self->point(shift) or return ();
        return Geo::Point->(x => $p->[0], y => $p->[1], proj => $proj);
    }

    map { Geo::Point->(x => $_->[0], y => $_->[1], proj => $proj) }
       $self->point(@_);

}

=method isRing
Returns a true value if the sequence of points are a ring or filled: the
first point is the last.
=cut

sub isRing()
{   my $self = shift;
    return $self->{GL_ring} if defined $self->{GL_ring};

    my ($first, $last) = $self->points(0, -1);
    $self->{GL_ring}  = ($first->[0]==$last->[0] && $first->[1]==$last->[1]);
}

=method isFilled
Returns a true value is the internals of the ring of points are declared
to belong to the shape.
=cut

sub isFilled() {shift->{GL_fill}}

=section Projections
=cut

sub in($)
{   my ($self, $projnew) = @_;
    return $self if ! defined $projnew || $projnew eq $self->proj;

    my @points = $self->projectOn($projnew, $self->points);
    @points ? $self->new(points => \@points, proj => $projnew) : $self;
}

=section Geometry
=cut

sub equal($;$)
{   my $self  = shift;
    my $other = shift;

    return 0 if $self->nrPoints != $other->nrPoints;

    $self->Math::Polygon::equal($other->in($self->proj), @_);
}

=method bbox
The bounding box coordinates.  These are more useful for rings than for
open line pieces.
=cut

sub bbox() { shift->Math::Polygon::bbox }

=method area
Returns the area enclosed by the polygon.  Only useful when the points
are in some orthogonal projection.

=error area requires a ring of points
If you think you have a ring of points (a polygon), than do specify
that when that object is instantiated (M<ring()> or M<new(ring)>).
=cut

sub area()
{   my $self = shift;

    croak "ERROR: area requires a ring of points"
       unless $self->isRing;

    $self->Math::Polygon::area;
}

=method perimeter
The length of the line on the ring.  A check is performed that the ring
is closed, but further this returns the result of M<length()>

=error perimeter requires a ring of points
=cut

sub perimeter()
{   my $self = shift;

    croak "ERROR: perimeter requires a ring of points."
       unless $self->isRing;

    $self->Math::Polygon::perimeter;
}

=method length
The length of the line, only useful in a orthogonal coordinate system
(projection).  See also M<perimeter()>.

=cut

sub length() { shift->Math::Polygon::perimeter }

=method clip (XMIN,XMAX,YMIN,YMAX)|OBJECT
Clip the shape to the bounding box of OBJECT, or the boxing parameters
specified.  A list of M<Geo::Line> objects is returned if anything is
inside the object.

On the moment M<Math::Polygon::lineClip()> and
M<Math::Polygon::fillClip1()> are used to do the job.  In the future,
that may change.

=cut

sub clip(@)
{   my $self  = shift;
    my $proj  = $self->proj;
    my @bbox  = @_==1 ? $_[0]->bbox : @_;
    $self->isFilled ? $self->fillClip1(@bbox) : $self->lineClip(@bbox);
}

=section Display

=method string [PROJECTION]
Returns a string representation of the line, which is also used for
stringification.

=examples
=cut

sub string(;$)
{   my ($self, $proj) = @_;
    my $line;
    if(defined $proj)
    {   $line = $self->in($proj);
    }
    else
    {   $proj = $self->proj;
        $line = $self;
    }

    my $type  = $line->isFilled ? 'filled'
              : $line->isRing   ? 'ring'
              :                   'line';

    "$type\[$proj](".$line->Math::Polygon::string.')';
}

1;
