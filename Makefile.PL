use ExtUtils::MakeMaker;

require 5.008;

WriteMakefile
  ( NAME		=> 'Geo::Point'
  , VERSION_FROM	=> 'version'
  , PREREQ_PM		=>
     { Test::More    => 0.47
     , Geo::Distance => 0.06
     , Geo::Proj4    => 0.96
     , Math::Polygon => 0.003
#    , Geo::Coordinates::UTM => 0.11
     }
  , AUTHOR              => 'Mark Overmeer'
  , ABSTRACT            => 'Geographical structures'
  );
