use ExtUtils::MakeMaker;

require 5.008;

WriteMakefile
  ( NAME        => 'Geo::Point'
  , VERSION     => '0.05'
  , PREREQ_PM   =>
     { Test::More    => 0.47
     , Geo::Distance => 0.06
     , Geo::Proj4    => 0.96
     , Math::Polygon => 0.003
     }
  , AUTHOR      => 'Mark Overmeer'
  , ABSTRACT      => 'Geographical structures'
  );

#### the next lines are added for OODoc, which generates the
#### distribution.
sub MY::postamble { <<'__POSTAMBLE' }

# for DIST
RAWDIR          = ../public_html/geopoint/raw
DISTDIR         = ../public_html/geopoint/source
LICENSE         = artistic

# for POD
FIRST_YEAR      = 2005
EMAIL           = geo@overmeer.net
WEBSITE         = http://perl.overmeer.net/geo/

# for HTML
EXTENDS		= ../MathPolygon:../GeoProj4
HTML_OUTPUT     = ../public_html/geo/html
HTML_DOCROOT    = /geo/html

__POSTAMBLE

