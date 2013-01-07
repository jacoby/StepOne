#!/usr/bin/perl

use 5.010 ;
use strict ;
use warnings ;
use Carp ;
use Data::Dumper ;
use lib '.' ;
use StepOne ':all' ;

my $sample_names = [ 'sample 1', 'sample 2', 'sample 4', ] ;
my $temp = '/tmp/eds' ;

my $plate ;
$plate->{ experiment_name } = 'Plate #34' ;      # name of experiment
$plate->{ sample_names }    = $sample_names ;    # list of samples
$plate->{ replicates } = 3 ;    # list of replicates per sample
$plate->{ std_curve }  = 4 ;    # highest num in standard curve
my $eds = make_eds( $plate, $temp ) ;

#from here, write $eds to a file or to STDOUT

if ( open my $fh, '>', '/home/jacoby/foo.eds' ) {
    print $fh $eds ;
    }
else {
    say STDERR $! ;
    }
