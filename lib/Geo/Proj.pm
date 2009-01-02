
use strict;
use warnings;

package Geo::Proj;

use Geo::Proj4   ();
use Carp         qw/croak/;

=chapter NAME

Geo::Proj - Handling projections

=chapter SYNOPSIS

 use Geo::Proj;

 my $wgs84 = Geo::Proj->new   # predefined if import()
  ( nick  => 'wgs84'
  , proj4 => '+proj=latlong +datum=WGS84 +ellps=WGS84'
  );

 my $clrk = Geo::Proj->new
  ( nick  => 'clark66'
  , proj4 => [proj => "merc", ellps => "clrk66", lon_0 => -96]
  );

 my $point_wgs84= Geo::Point->latlong(56.12, 4.40, 'wgs84');
 my $point_wgs84= Geo::Point->latlong(56.12, 4.40, $wgs84);

 my $point_clrk = $point_wgs84->to($clrk);
 my $point_clrk = Geo::Proj->to($clrk, $point_wgs84);
 my $point_clrk = Geo::Proj->to('clark66', $point_wgs84);

=chapter DESCRIPTION
A point on Earth's surface can be represented in many different coordinate
systems.  The M<Geo::Proj4> module wraps the popular Open Source C<libproj>
library to convert between those coordinate systems; a very complex job.

Within a program, however, you like some extra abstraction from that
library: to be able to simply label a point to its system, and then
forget about all transformations which may be necessary.  The label (or
C<nick>) hides all complicated parameters for the actual projection .

WARNING 1: this class will collect all nicks, which means that calling
M<new()> with the same label twice will have the second ignored.

WARNING 2: the wgs84 nickname is predefined, but only if this module is
'used' with import.  So if you decide to use 'require' to dynamically load
this module, then don't forget to call 'import()' yourself, or define the
wgs84 projection yourself.

=chapter OVERLOADING

=overload '""' (stringification)
Returns the nick-name for this projection.
=cut

use overload '""'     => sub { shift->nick }
           , fallback => 1;

=chapter METHODS

=cut

sub import()
{
  Geo::Proj->new
   ( nick  => 'wgs84'
   , proj4 => '+proj=latlong +datum=WGS84 +ellps=WGS84'
   );
}

=section Constructors

=c_method new [NICK], OPTIONS
Create a new object.

=requires nick       LABEL
The abbrevated name for this projection.

=requires proj4      OBJECT|ARRAY|STRING
The ARRAY or STRING will by used to create a M<Geo::Proj4> object
by calling M<Geo::Proj4::new()>.  You may also specify such an
prepared OBJECT.

=option   srid       INTEGER
=default  srid       C<undef>
SRID stands for "Spatial Reference System ID", which is just an index
in a table of spatial descriptions as used by SQL. Only INTEGER values
larger than 0 are permitted.

=option   name       STRING
=default  name       <from proj4>

=cut

my %projections;
my $defproj;

sub new(@)
{   my ($class, %args) = @_;
    my $proj   = $projections{$args{nick} || 'dead'};
    return $proj if defined $proj;

    my $self   = (bless {}, $class)->init(\%args);
    $projections{$self->nick} = $self;
    $defproj ||= $self;
    $self;
}

sub init($)
{   my ($self, $args) = @_;

    my $nick = $self->{GP_nick} = $args->{nick}
        or croak "ERROR: nick required";

    $self->{GP_srid} = $args->{srid};

    my $proj4 = $args->{proj4}
        or croak "ERROR: proj4 parameter required";

    if(ref $proj4 eq 'ARRAY')
    {   $proj4   = Geo::Proj4->new(@$proj4);
        croak "ERROR: cannot create proj4: ".Geo::Proj4->error
            unless $proj4;
    }
    elsif(!ref $proj4)
    {   $proj4   = Geo::Proj4->new($proj4);
        croak "ERROR: cannot create proj4: ".Geo::Proj4->error
            unless $proj4;
    }
    $self->{GP_proj4} = $proj4;
    $self->{GP_name}  = $args->{name};
    $self;
}

=section Attributes

=method nick
Simple abbreviating of the projection.
=cut

sub nick() {shift->{GP_nick}}

=method name
The full, official name of the projection
=cut

sub name()
{   my $self = shift;
    my $name = $self->{GP_name};
    return $name if defined $name;

    my $proj = $self->proj4;
    my $abbrev = $proj->projection
       or return $self->{nick};

    my $def    = $proj->type($abbrev);
    $def->{description};
}

=ci_method proj4 [NICK|PROJ4]
Returns the projection library handle (a M<Geo::Proj4>) to be used by this
component.  As class method, the NICK is specified for a lookup.  In case
a PROJ4 is specified, that is returned.

=examples
 my $wgs84 = Geo::Proj->new(nick => 'wgs84', ...);
 my $wgs84_proj4 = Geo::Proj->proj4('wgs84');
 my $wgs84_proj4 = Geo::Proj->proj4($wgs84);
 my $wgs84_proj4 = $wgs84->proj4;
=cut

sub proj4(;$)
{   my $thing = shift;
    return $thing->{GP_proj4} unless @_;

    my $proj  = $thing->projection(shift) or return undef;
    $proj->proj4;
}

=method srid
The "Spatial Reference System ID" if known.
=cut

sub srid() {shift->{GP_srid}}

=section Projecting

=c_method projection NICK|PROJ
Returns the M<Geo::Proj> object, defined with NICK.  In case such an
object is passed in as PROJ, it is returned unaffected.  This method is
used where in other methods NICKS or PROJ can be used as arguments.

=examples
 my $wgs84 = Geo::Proj->projection('wgs84');
 my $again = Geo::Proj->projection($wgs84);
=cut

sub projection($)
{   my $which = $_[1];
    UNIVERSAL::isa($which, __PACKAGE__) ? $which : $projections{$which};
}

=c_method defaultProjection [NICK|PROJ]
The NICK must be defined with M<new()>.  Returned is the nickname for
a projection.  The default is the first name created, which probably
is 'wgs84' (when import() had a chance)

=cut

sub defaultProjection(;$)
{   my $thing = shift;
    if(@_)
    {   my $proj = shift;
        $defproj = ref $proj ? $proj->nick : $proj;
    }
    $defproj;
}

=c_method listProjections
Returns a sorted lost of projection nicks.
=cut

sub listProjections() { sort keys %projections }

=c_method dumpProjections [FILEHANDLE]
Print details about the defined projections to the FILEHANDLE, which
defaults to the selected.  Especially useful for debugging.
=cut

sub dumpProjections(;$)
{   my $class = shift;
    my $fh    = shift || select;

    my $default = $class->defaultProjection;
    my $defnick = defined $default ? $default->nick : '';

    foreach my $nick ($class->listProjections)
    {   my $proj = $class->projection($nick);
        my $name = $proj->name;
        my $norm = $proj->proj4->normalized;
        $fh->print("$nick: $name".($defnick eq $nick ? ' (default)':'')."\n");
        $fh->print("    $norm\n") if $norm ne $name;
    }
}

=ci_method to [PROJ|NICK], PROJ|NICK, POINT|ARRAY_OF_POINTS
Expects an Geo::Proj to project the POINT or POINTS to.  The work
is done by M<Geo::Proj4::transform()>.  As class method, you have to
specify two nicks or projections.

=examples
 my $p2 = $wgs84->to('utm-wgs84-31', $p1);
 my $p2 = $wgs84->to($utm, $p1);
 my $p2 = Geo::Proj->to('wgs84', 'utm-wgs84-31', $p1);
=cut

sub to($@)
{   my $thing   = shift;
    my $myproj4 = ref $thing ? $thing->proj4 : __PACKAGE__->proj4(shift);
    my $toproj4 = __PACKAGE__->proj4(shift);
    $myproj4->transform($toproj4, @_);
}

=section UTM
=cut

# These methods may have been implemented in Geo::Point, however may get
# supported by any external library later.  Knowledge about projections
# is as much as possible concentrated here.

=ci_method zoneForUTM POINT
Provided some point, figure-out which zone is most optimal for representing
the point.  In LIST context, zone number, zone letter, and meridian are
returned as separate scalars.  In LIST context, the zone number and letter
are returned as one..

This code is stolen from L<Geo::Coordinates::UTM>, because that module
immediately starts to do computations with this knowledge, which is not
wanted here.  Probably a lot of zones are missing.

=cut

sub zoneForUTM($)
{   my ($thing, $point) = @_;
    my ($long, $lat) = $point->longlat;

    my $zone
     = ($lat >= 56 && $lat < 64)
     ? ( $long <  3   ? undef
       : $long < 12   ? 32
       :                undef
       )
     : ($lat >= 72 && $lat < 84)
     ? ( $long <  0   ? undef
       : $long <  9   ? 31
       : $long < 21   ? 33
       : $long < 33   ? 35
       : $long < 42   ? 37
       :                undef
       )
     : undef;

    my $meridian = int($long/6)*6 + ($long < 0 ? -3 : +3);
    $zone      ||= int($meridian/6) + 180/6 +1;
 
    my $letter
     = ($lat < -80 || $lat > 84) ? ''
     : ('C'..'H', 'J'..'N', 'P'..'X', 'X')[ ($lat+80)/8 ];

      wantarray     ? ($zone, $letter, $meridian)
    : defined $zone ? "$zone$letter"
    : undef;
}

=ci_method bestUTMprojection POINT, [PROJ|NICK]
Returns the best UTM projection for some POINT.  As class method, you
specify the nickname or the object for the point.

=example
 my $point = Geo::Point->longlat(2.234, 52.12);
 my $proj  = Geo::Proj->bestUTMprojection($point);
 print $proj->nick;    # for instance utm-wgs84-31

=cut

sub bestUTMprojection($;$)
{   my ($thing, $point) = (shift, shift);
    my $proj  = @_ ? shift : $point->proj;

    my ($zone, $letter, $meridian) = $thing->zoneForUTM($point);
    $thing->UTMprojection($proj, $zone);
}

=c_method UTMprojection DATUM|PROJ|undef, ZONE
The PROJ is a M<Geo::Proj> which is used to collect the datum
information from if no DATUM was specified explicitly.  It may also be
a string which is the name of a datum, as known by proj4.  Undef will
be replaced by the default projection.

=example
 my $proj = Geo::Proj->UTMprojection('WGS84', 31) or die;
 print $proj->nick;    # for instance utm-wgs84-31
=cut

sub UTMprojection($$)
{   my ($class, $base, $zone) = @_;

    $base   ||= $class->defaultProjection;
    my $datum = UNIVERSAL::isa($base, __PACKAGE__) ? $base->proj4->datum:$base;
    $datum  ||= 'wgs84';

    my $label = "utm-\L${datum}\E-$zone";

    Geo::Proj->new
     ( nick  => $label
     , proj4 => "+proj=utm +datum=\U$datum\E zone=$zone"
     );
}

1;
