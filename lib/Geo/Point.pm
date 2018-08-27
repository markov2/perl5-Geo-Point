# This code is part of distribution Geo-Point.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package Geo::Point;
use base 'Geo::Shape';

use strict;
use warnings;

use Geo::Proj;
use Carp        qw/confess croak/;

=chapter NAME

Geo::Point - a point on the globe

=chapter SYNOPSIS

 use Geo::Point;

 my $p = Geo::Point->latlong(1,2);
 my $p = Geo::Point->longlat(2,1);

 my $w = Geo::Proj->new(wgs84 => ...);
 my $p = Geo::Point->latlong(1,2, 'wgs84');

 my ($lat, $long) = $p->latlong;
 my ($x, $y) = $p->xy;
 my ($x, $y) = $p->in('utm31-wgs84');

 my $p = Geo::Point->xy(1,2);

=chapter DESCRIPTION
One location on the globe, in any coordinate system.  This package tries
to hide the maths and the coordinate system in which the point is
represented.

One of the most confusing things when handling geometrical data, is
that sometimes latlong, sometimes xy are used: horizontal and vertical
organization reversed.  This package tries to hide this from your
program by providing abstract accessors M<latlong()>, M<longlat()>,
M<xy()>, and M<yx()>.

=chapter METHODS

=section Constructors

=ci_method new %options

=option  latitude  COORDINATE
=default latitude  undef

=option  lat       COORDINATE
=default lat       undef

=option  longitude COORDINATE
=default longitude undef

=option  long      COORDINATE
=default long      undef

=option  x         COORDINATE
=default x         undef

=option  y         COORDINATE
=default y         undef

=cut

sub init($)
{   my ($self, $args) = @_;

    $self->SUPER::init($args);
    $self->{GP_x} = defined $args->{x}    ? $args->{x}
                  : defined $args->{long} ? $args->{long}
                  :                         $args->{longitude};
    $self->{GP_y} = defined $args->{y}    ? $args->{y}
                  : defined $args->{lat}  ? $args->{lat}
                  :                         $args->{latitude};
    $self;
}

=ci_method latlong [ $lat,$long,[$proj] ] | [$proj]
When called as class method, you create a new point.  Provide a LATitude
and LONGitude. The optional PROJection tells in which coordinate system.

As instance method, the latitude and longitude are reported.  You
can ask it to be translated into the $proj coordinate system first.

When $proj is undefined, none is presumed. The project must be specified
as string, which referse to a projection defined by M<Geo::Proj>.
See also M<longlat()>, M<xy()>, and M<yx()>.

=example latlong as class method
 my $wgs84 = Geo::Proj->new(wgs84 => ...);
 my $gp    = Geo::Point->latlong(52.3213, 5.53, 'wgs84');

=example latlong as instance method
 my ($lat, $long) = $gp->latlong('wgs84');

=cut

sub latlong(@)
{   my $thing = shift;

    if(ref $thing)   # instance method
    {   return ($thing->{GP_y}, $thing->{GP_x}) unless @_ > 2;

        my $proj = pop @_;
        return $thing->in($proj)->latlong;
    }

    # class method
    $thing->new(lat => shift, long => shift, proj => shift);
}

=ci_method longlat [ $long,$lat,[$proj] ] | [$proj]
Like M<latlong()>, but with the coordinates reversed.  Some applications
prefer this.
=cut

sub longlat(@)
{   my $thing = shift;

    if(ref $thing)   # instance method
    {   return ($thing->{GP_x}, $thing->{GP_y}) unless @_ > 2;
        my $proj = pop @_;
        return $thing->in($proj)->longlat;
    }

    # class method
    $thing->new(long => shift, lat => shift, proj => shift);
}

=ci_method xy [$x, $y, [$proj] ] | [$proj]
Like M<longlat()> but now for carthesian projections.  Usually, the coordinate
order is reversed.  See also M<yx()>.
=cut

sub xy(@)
{   my $thing = shift;

    if(ref $thing)   # instance method
    {   return ($thing->{GP_x}, $thing->{GP_y}) unless @_ > 2;

        my $proj = pop @_;
        return $thing->in($proj)->xy;
    }

    # class method
    $thing->new(x => shift, y => shift, proj => shift);
}

=ci_method yx [$y, $x, [$proj] ] | [$proj]
Like M<latlong()> but now for carthesian projections.  Usually, the
coordinate order is reversed.  See also M<xy()>.
=cut

sub yx(@)
{   my $thing = shift;

    if(ref $thing)   # instance method
    {   return ($thing->{GP_y}, $thing->{GP_x}) unless @_ > 2;

        my $proj = pop @_;
        return $thing->in($proj)->yx;
    }

    # class method
    $thing->new(y => shift, x => shift, proj => shift);
}

=c_method fromString $string, [$projection]
Create a new point from a $string.  The coordinates can be separated by
a comma (preferably), or blanks.  When the coordinates end on NSEW, the
order does not matter, otherwise lat-long or xy order is presumed.

This routine is very smart.  It understands:

  PROJLABEL VALUE VALUE
  PROJLABEL: VALUE VALUE
  PROJLABEL, VALUE, VALUE
  PROJLABEL: VALUE, VALUE
  VALUE VALUE
  VALUE, VALUE
  utm: ZONE, VALUE, VALUE   # also without commas and ':'
  utm: VALUE, VALUE, ZONE   # also without commas and ':'
  utm: VALUE, VALUE         # also without commas and ':'
  ZONE, VALUE, VALUE        # also without commas and ':'
  VALUE, VALUE, ZONE        # also without commas and ':'

The VALUE must be suitable for projection.  If only two values are
provided, a C<d>, single or double quote, or trailing/leading C<e>, C<w>,
C<n>, C<s> (either lower or upper-case) will force a latlong projection.
Those coordinates must follow the rules of M<dms2deg()>.

=examples point from string

 my $x = 'utm 31n 12311.123 34242.12'; # utm zone 31N
 my $x = '12311.123 34242.12 31';      # utm zone 31
 my $x = '123.123E 12.34';             # wgs84  latlong
 my $x = 'clrk66 123.123 12.34';       # clrk66 latlong
 my $x = '12d34'123.1W 11.1123';       # wgs84  longlat

 my $p = Geo::Point->fromString($x);

 # When parsing user applications, you probably want:
 my $p = eval { Geo::Point->fromString($x) };
 warn $@ if $@;

=error UTM requires 3 values: easting, northing, and zone

=error illegal UTM zone in $string
A UTM zone can be detected at the beginning or at the end of the
input.  It contains a number (from 1 up to 60) and an optional
latitude indication (C up to X, except I and O).

=error undefined projection $proj for $string
The projection you used (or is set as default) is not defined.  See
M<Geo::Proj::new()> about how to defined them.

=error too few values in $string (got @parts)
Most projection require two parameters, but utm requires three (with zone).

=error too many values in $string (got @parts)
Most projection require two parameters, but utm requires three (with zone).

=error dms latitude coordinate not understood: $string
See M<dms2deg()> for permitted formats.

=error dms longitude coordinate not understood: $string
See M<dms2deg()> for permitted formats.

=error illegal character in x coordinate $x
=error illegal character in y coordinate $y

=cut

sub fromString($;$)
{   my ($class, $string, $nick) = @_;

    defined $string or return;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return () unless length $string;

    # line starts with project label
    $nick   = $1 if $string =~ s/^(\w+)\s*\:\s*//;

    # The line is either split by comma's or by blanks.
    my @parts
      = $string =~ m/\,/
      ? (split /\s*\,\s*/, $string)
      : (split /\s+/, $string);

    # Now, the first word may be a projection.  That is: any non-coordinate,
    # anything which starts with more than one letter.
    if($parts[0] =~ m/^[a-z_]{2}/i)
    {   $nick = shift @parts;          # overrules default
    }

    my $proj;
    if(!defined $nick)
    {   $proj = Geo::Proj->defaultProjection;
        $nick = $proj->nick;
    }
    elsif($nick eq 'utm')
    {   die "ERROR: UTM requires 3 values: easting, northing, and zone\n"
           unless @parts==3;

        my $zone;
        if($parts[0] =~ m/^\d\d?[C-HJ-NP-X]?$/i )
        {   $zone = shift @parts;
        }
        elsif($parts[2] =~ m/^\d\d?[C-HJ-NP-X]?$/i )
        {   $zone = pop @parts;
        }

        if(!defined $zone || $zone==0 || $zone > 60)
        {   die "ERROR: illegal UTM zone in $string";
        }

        $proj = Geo::Proj->UTMprojection(undef, $zone);
        $nick = $proj->nick;
    }
    else
    {   $proj = Geo::Proj->projection($nick)
            or croak "ERROR: undefined projection $nick";
    }

    croak "ERROR: too few values in '$string' (got ".@parts.", expect 2)\n"
       if @parts < 2;

    croak "ERROR: too many values in '$string' (got ".@parts.", expect 2)\n"
       if @parts > 2;

    if($proj->proj4->isLatlong)
    {   my ($lats, $longs)
         = (  $parts[0] =~ m/[ewEW]$/ || $parts[1] =~ m/[nsNS]$/
           || $parts[0] =~ m/^[ewEW]/ || $parts[1] =~ m/^[nsNS]/
           )
         ? reverse(@parts) : @parts;

        my $lat  = $class->dms2deg($lats);
        defined $lat
            or die "ERROR: dms latitude coordinate not understood: $lats\n";

        my $long = $class->dms2deg($longs);
        defined $long
           or die "ERROR: dms longitude coordinate not understood: $longs\n";

        return $class->new(lat => $lat, long => $long, proj => $nick);
    }
    else # type eq xy
    {   my ($x, $y) = @parts;
        die "ERROR: illegal character in x coordinate $x"
            unless $x =~ m/^\d+(?:\.\d+)$/;

        die "ERROR: illegal character in y coordinate $y"
            unless $y =~ m/^\d+(?:\.\d+)$/;

        return $class->new(x => $x, y => $y, proj => $nick);
    }

    ();
}

#----------------
=section Accessors
The accessors only work correctly when you are sure that the point is
in the right coordinate systems.

=method latitude
=method lat
=method longitude
=method long
=method x
=method y
=cut

sub longitude() {shift->{GP_x}}
sub long()      {shift->{GP_x}}
sub latitude()  {shift->{GP_y}}
sub lat()       {shift->{GP_y}}

sub x()         {shift->{GP_x}}
sub y()         {shift->{GP_y}}

#----------------
=section Projections

=cut

sub in($)
{   my ($self, $newproj) = @_;

    # Dirty hacks violate OO, to improve the speed.
    return $self if $newproj eq $self->{G_proj};

    my ($n, $p) = $self->projectOn($newproj, [$self->{GP_x}, $self->{GP_y}]);
    $p ? ref($self)->new(x => $p->[0], y => $p->[1], proj => $n) : $self;
}

=method normalize
Be sure the that coordinates are between -180/180 longitude, -90/90
lattitude.  No changes for non-latlong projections.
=cut

sub normalize()
{   my $self = shift;
    my $p    = Geo::Proj->projection($self->proj);
    $p && $p->proj4->isLatlong or return $self;
    my ($x, $y) = @$self{'GP_x','GP_y'};
    $x += 360 while $x < -180;
    $x -= 360 while $x >  180;
    $y += 180 while $y <  -90;
    $y -= 180 while $y >   90;
    @$self{'GP_x','GP_y'} = ($x, $y);
    $self;
}

#----------------
=section Geometry

=method bbox
The bounding box of a point contains twice itself.
=cut

sub bbox() { @{(shift)}[ qw/GP_x GP_y GP_x GP_y/ ] }

=method area
Always returns zero.
=cut

sub area() { 0 }

=method perimeter
Always returns zero.
=cut

sub perimeter() { 0 }

=method distancePointPoint $geodist, $units, $point
Compute the distance between the current point and some other $point in
$units.  The $geodist object will do the calculations.  See M<distance()>.
=cut

# When two points are within one UTM zone, this could be done much
# easier...

sub distancePointPoint($$$)
{   my ($self, $geodist, $units, $other) = @_;

    my $here  = $self->in('wgs84');
    my $there = $other->in('wgs84');
    $geodist->distance($units, $here->latlong, $there->latlong);
}

=method sameAs $other, $tolerance
=error can only compare a point to another Geo::Point
=cut

sub sameAs($$)
{   my ($self, $other, $e) = (shift, shift);

    croak "ERROR: can only compare a point to another Geo::Point"
        unless $other->isa('Geo::Point');

    # may be latlong or xy, doesn't matter: $e is corrected for that
    my($x1, $y1) = $self->xy;
    my($x2, $y2) = $other->xy;
    abs($x1-$x2) < $e && abs($y1-$y2) < $e;
}

=method inBBox $object
Returns a true value if this point is inside the bounding box of
the specified $object.  The borders of the bbox are included.  This is
relatively fast to check, even for complex objects.  When the projections
differ, the point is translated into the $object's coordinate system,
because that one must stay square.

=cut

sub inBBox($)
{   my ($self, $other) = @_;
    my ($x, $y) = $self->in($other->proj)->xy;
    my ($xmin, $ymin, $xmax, $ymax) = $other->bbox;
    $xmin <= $x && $x <= $xmax && $ymin <= $y && $y <= $ymax
}

#----------------
=section Display

=method coordsUsualOrder
Returns the coordinates in the order which is usual for the projection
used.
=cut

sub coordsUsualOrder()
{   my $self = shift;
    my $p    = Geo::Proj->projection($self->proj);
    $p && $p->proj4->isLatlong ? $self->latlong : $self->xy;
}

=method coords
Returns the coordinates in their usual order, formatted as string
with a joining blank;
=cut

sub coords()
{  my ($a, $b) = shift->coordsUsualOrder;
   defined $a && defined $b or return '(none)';

   sprintf "%.4f %.4f", $a, $b;
}

=method toString [$projection]
Returns a string representation of the point, which is also used for
stringification.  The default projection is the one of the point.
=examples
 print "Point: ",$gp->toString, "\n";
 print "Point: $gp\n";   # same

 print "Point: ",$gp->toString('clrk66'), "\n";
=cut

sub toString(;$)
{   my ($self, $proj) = @_;
    my $point;

    if(defined $proj)
    {   $point = $self->in($proj);
    }
    else
    {   $proj  = $self->proj;
        $point = $self;
    }

    "point[$proj](" .$point->coords.')';
}
*string = \&toString;

=method dms [$projection]
Show the point as DMS value-pair.  You must be sure that the coordinate
is a projection for which is it useful to represent the values in DMS.
In SCALAR context, one string is returned.  In LIST context, the values
are returned separately in latlong order.

Be warned, that the returned string may contain single and double quote
characters, which may confuse HTML (see M<dmsHTML()>).

=cut

sub dms(;$)
{   my ($self, $proj) = @_;
    my ($long, $lat)  = $proj ? $self->in($proj)->longlat : $self->longlat;

    my $dmslat  = $self->deg2dms($lat,  'N', 'S');
    my $dmslong = $self->deg2dms($long, 'E', 'W');
    wantarray ? ($dmslat, $dmslong) : "$dmslat, $dmslong";
}

=method dm [$projection]
Like M<dms()>, but doesn't show seconds.
=cut

sub dm(;$)
{   my ($self, $proj) = @_;
    my ($long, $lat)  = $proj ? $self->in($proj)->longlat : $self->longlat;

    my $dmlat  = $self->deg2dm($lat,  'N', 'S');
    my $dmlong = $self->deg2dm($long, 'E', 'W');
    wantarray ? ($dmlat, $dmlong) : "$dmlat, $dmlong";
}

=method dmsHTML [$projection]
Like M<dms()>, but all character which are troublesome for HTML are
translated into character codes.
=cut

sub dmsHTML(;$)
{   my ($self, $proj) = @_;
    my @both = $self->dms($proj);
    foreach (@both)
    {   s/"/\&quot;/g;
        # The following two translations are nice, but IE does not handle
        # them correctly when uses as values in form fields.
        # s/d/\&deg;/g;
        # s/ /\&nbsp;\&nbsp;/g;
    }
    wantarray ? @both : "$both[0], $both[1]";
}

=method dmHTML [$projection]
Like M<dmsHTML()>, but does not show seconds.
=cut

sub dmHTML(;$)
{   my ($self, $proj) = @_;
    my @both = $self->dm($proj);
    foreach (@both)
    {   s/"/\&quot;/g;
        # See dmsHTML above
        # s/d/\&deg;/g;
        # s/ /\&nbsp;\&nbsp;/g;
    }
    wantarray ? @both : "$both[0], $both[1]";
}

=method moveWest
Move a point from the eastern calculations into the western calculations,
resulting in a value below -180.  This is useful when this point is part
of a larger construct, like the corners of a satellite image, which are
both sides of the -180 meridian.

=example moving West
 my $point = Geo::Point->latlong(24, 179);
 $point->moveWest;
 print $point->long;   # -181;
=cut

sub moveWest()
{   my $self = shift;
    $self->{GP_x} -= 360 if $self->{GP_x} > 0;
}


1;
