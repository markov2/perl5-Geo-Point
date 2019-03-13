# This code is part of distribution Geo-Point.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package Geo::Shape;

use strict;
use warnings;

use Geo::Proj;      # defines wgs84
use Geo::Point      ();
use Geo::Line       ();
use Geo::Surface    ();
use Geo::Space      ();

use GIS::Distance   ();
use Carp            qw/croak confess/;

=chapter NAME

Geo::Shape - base class for 2-dimensional points on the earth surface

=chapter SYNOPSIS

 use Geo::Shape;

 my $p1 = Geo::Point->new(lat => 2.17, ...);
 my $p2 = Geo::Point->latlong(2.17, 3.14);   # wgs84 is default

 my $p3 = $p1->in('wgs84');                  # conversion
 my $p4 = $p1->in('utm');                    # conversion

=chapter DESCRIPTION
Base class for the many geo-spatial objects defined by the GeoPoint
distribution.

=chapter OVERLOAD

=overload '""' (stringification)
Returns a string "$proj($lat,$long)" or "$proj($x,$y)".  The C<$proj>
is the nickname you have assigned to the projection.

=overload 'bool' (truth value)
A point is always true: defined.

=cut

use overload '""'     => 'string'
           , bool     => sub {1}
           , fallback => 1;

=chapter METHODS

=section Constructors

=ci_method new %options
Create a new object.

=option  proj       LABEL
=default proj       see M<Geo::Proj::defaultProjection()>

=cut

sub new(@) {
    my ($thing, %args) = @_;
    $args{proj} ||= $thing->proj if ref $thing;
	(bless {}, ref $thing || $thing)->init(\%args);
}

sub init($)
{   my ($self, $args) = @_;
    my $proj = $self->{G_proj}
      = $args->{proj} || Geo::Proj->defaultProjection->nick;

    croak "proj parameter must be a label, not a Geo::Proj object"
        if UNIVERSAL::isa($proj, 'Geo::Proj');

    $self;
}

#---------------------------
=section Attributes

=method proj
Returns the nickname of the projection used by the component.
B<Be warned:> this is not a M<Geo::Point> object, but just a label.

=method proj4
Returns the proj4 object which handles the projection.
=cut

sub proj()  { shift->{G_proj} }
sub proj4() { Geo::Proj->proj4(shift->{G_proj}) }

#---------------------------
=section Projections

=method in <$label|'utm'>
The coordinates of this point in a certain projection, referred to with
the $label.  The projection is defined with M<new()>.  When simply
'utm' is provided, the best UTM zone is selected.

In LIST context, the coordinates are returned.  In SCALAR context,
a new object is returned.

=examples
  my $gp       = Geo::Point->latlong(1,2);

  # implicit conversion to wgs84, if not already in latlong
  my ($lat, $long) = $pr->latlong;

  # will select an utm zone for you
  my $p_utm    = $gp->in('utm');
  my ($x, $y)  = $p_utm->xy;
  my $label    = $p_utm->proj;
  my ($datum, $zone) = $label =~ m/^utm-(\w+)-(\d+)$/;

=error in() not implemented for a $class
=cut

sub in($) { croak "ERROR: in() not implemented for a ".ref(shift) }

=method projectOn $nick, @points
The @points are ARRAYs with each an X and Y coordinate of a single
point in space.  A list of transformed points is returned, which is empty
if no change is needed.  The returned list is preceded by the projection
nick of the result; usually the same as the provided $nick, but in
some cases (for instance UTM) it may differ.
=cut

sub projectOn($@)
{   # fast check: nothing to be done
    return () if @_<2 || $_[0]->{G_proj} eq $_[1];

    my ($self, $projnew) = (shift, shift);
    my $projold = $self->{G_proj};

    return ($projnew, @_)
        if $projold eq $projnew;

    if($projnew eq 'utm')
    {   my $point = $_[0];
        $point   = Geo::Point->xy(@$point, $projold)
            if ref $point eq 'ARRAY';
        $projnew = Geo::Proj->bestUTMprojection($point, $projold)->nick;
        return ($projnew, @_)
            if $projnew eq $projold;
    }

    my $points = Geo::Proj->to($projold, $projnew, \@_);
    ($projnew, @$points);
}

#---------------------------
=section Geometry

=method distance $object, [$unit]
Calculate the distance between this object and some other object.
For many combinations of objects this is not supported or only
partially supported.

This calculation is performed with L<GIS::Distance> in accurate mode.
The default $unit is kilometers.  Other units are provided in the manual
page of L<GIS::Distance>.  As extra unit, C<degrees> and C<radians> are
added as well as the C<km> alias for kilometer.

=error distance calculation not implemented between a $kind and a $kind
Only a subset of all objects can be used in the distance calculation.
The limitation is purely caused by lack of time to implement this.
=cut

my $gisdist;
sub distance($;$)
{   my ($self, $other, $unit) = (shift, shift, shift);
    $unit ||= 'kilometer';

    $gisdist ||= GIS::Distance->new('Haversine');

    my $proj = $self->proj;
    $other = $other->in($proj)
        if $other->proj ne $proj;

    if($self->isa('Geo::Point') && $other->isa('Geo::Point'))
    {   return $self->distancePointPoint($gisdist, $unit, $other);
    }

    die "ERROR: distance calculation not implemented between a "
      . ref($self) . " and a " . ref($other);
}

=ci_method bboxRing [$xmin, $ymin, $xmax, $ymax, [$proj]]
Returns a M<Geo::Line> which describes the outer bounds of the
object called upon, counter-clockwise and left-bottom first.  As class
method, you need to specify the limits and the PROJection.
=cut

sub bboxRing(@)
{   my ($thing, $xmin, $ymin, $xmax, $ymax, $proj) = @_;

    if(@_==1 && ref $_[0])   # instance method without options
    {   $proj  = $thing->proj;
        ($xmin, $ymin, $xmax, $ymax) = $thing->bbox;
    }

    Geo::Line->new   # just a little faster than calling ring()
     ( points    => [ [$xmin,$ymin], [$xmax,$ymin], [$xmax,$ymax]
                    , [$xmin,$ymax], [$xmin,$ymin] ]
     , proj      => $proj
     , ring      => 1
     , bbox      => [$xmin, $ymin, $xmax, $ymax]
     , clockwise => 0
     );
}

=method bbox
Returns the bounding box of the object as four coordinates, respectively
xmin, ymin, xmax, ymax.  The values are expressed in the coordinate
system of the object.
=cut

sub bbox() { confess "INTERNAL: bbox() not implemented for ".ref(shift) }

=method bboxCenter
Returns a M<Geo::Point> which represent the middle of the object.  It is
the center of the bounding box.  The values is cached, once computed.

Be warned that the central point in one projection system may be quite
different from the central point in some other projectionsystem .
=cut

sub bboxCenter()
{   my $self = shift;
    my ($xmin, $ymin, $xmax, $ymax) = $self->bbox;
    Geo::Point->xy(($xmin+$xmax)/2, ($ymin+$ymax)/2, $self->proj);
}

=method area
Returns the area covered by the geo structure. Points will return zero.
=cut

sub area() { confess "INTERNAL: area() not implemented for ".ref(shift) }

=method perimeter
Returns the length of the outer border of the object's components.  For
points, this returns zero.
=cut

sub perimeter() { confess "INTERNAL: perimeter() not implemented for ".ref(shift) }

=section Display

=ci_method deg2dms $degrees, $pos, $neg
Translate floating point $degrees into a "degrees minutes seconds"
notation.  An attempt is made to handle rounding errors.
=example
 print $point->deg2dms(-12.34, 'E', 'W');'     # --> 12d20'24"W
 print Geo::Shape->deg2dms(52.1234, 'E', 'W'); # --> 52d07'24"E
=cut

sub deg2dms($$$)
{   my ($thing, $degrees, $pos, $neg) = @_;
    $degrees   -= 360 while $degrees >   180;
    $degrees   += 360 while $degrees <= -180;

    my $sign    = $pos;
    if($degrees < 0)
    {   $sign   = $neg;
        $degrees= -$degrees;
    }

    my $d       = int $degrees;
    my $frac    = ($degrees - $d) * 60;
    my $m       = int($frac + 0.00001);
    my $s       = ($frac - $m) * 60;
    $s = 0 if $s < 0.001;

    my $g       = int($s + 0.00001);
    my $h       = int(($s - $g) * 1000 + 0.0001);
      $h ? sprintf("%dd%02d'%02d.%03d\"$sign", $d, $m, $g, $h)
    : $s ? sprintf("%dd%02d'%02d\"$sign", $d, $m, $g)
    : $m ? sprintf("%dd%02d'$sign", $d, $m)
    :      sprintf("%d$sign", $d);
}

=ci_method deg2dm $degrees, $pos, $neg
Like M<deg2dms()> but without showing seconds.
=example
 print $point->deg2dm(0.12, 'e', 'w');
 print Geo::Shape->deg2dm(0.12, 'e', 'w');
=cut

sub deg2dm($$$)
{   my ($thing, $degrees, $pos, $neg) = @_;
    defined $degrees or return '(null)';

    $degrees   -= 360 while $degrees >   180;
    $degrees   += 360 while $degrees <= -180;

    my $sign    = $pos;
    if($degrees < 0)
    {   $sign   = $neg;
        $degrees= -$degrees;
    }

    my $d       = int $degrees;
    my $frac    = ($degrees - $d) * 60;
    my $m       = int($frac + 0.00001);

    $m ? sprintf("%dd%02d'$sign", $d, $m)
       : sprintf("%d$sign", $d);
}

=ci_method dms2deg $dms
Accepts for instance 3d12'24.123, 3d12"E, 3.12314w, n2.14, s3d12",
-12d34, and returns floating point degrees.
=cut

sub dms2deg($)
{  my ($thing, $dms) = @_;

   my $o = 'E';
   $dms =~ s/^\s+//;

      if($dms =~ s/([ewsn])\s*$//i) { $o = uc $1 }
   elsif($dms =~ s/^([ewsn])\s*//i) { $o = uc $1 }

   if($dms =~ m/^( [+-]? \d+ (?: \.\d+)? )   [\x{B0}dD]?
               \s* (?: ( \d+ (?: \.\d+)? )   [\'mM\x{92}]? )?
               \s* (?: ( \d+ (?: \.\d+)? )   [\"sS]? )?
               /xi
     )
   {   my ($d, $m, $s) = ($1, $2||0, $3||0);

       my $deg = ($o eq 'W' || $o eq 'S' ? -1 : 1)
               * ($d + $m/60 + $s/3600);

       return $deg;
   }

   ();
}

1;
