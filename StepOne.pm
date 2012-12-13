package StepOne ;

# PCR_Export tools to create configuration files
# for the StepOne qPCR machine

# 2011/11 DAJ - initial development

use 5.010 ;
use strict ;
use warnings ;
use Carp ;
use Cwd qw{ getcwd abs_path } ;
use Data::Dumper ;
use Exporter qw(import) ;
use File::Copy ;
use File::HomeDir ;
use File::Path qw{ mkpath } ;
use File::stat ;
use File::Temp qw{ tempdir } ;
use IO::Compress::Zip qw(zip $ZipError) ;
use Template ;

our $VERSION = 0.0.1 ;
our %EXPORT_TAGS ;

BEGIN {
    %EXPORT_TAGS = (
        'all' => [ qw(
                make_eds
                )
                ],
            ) ;
    our @EXPORT_OK = ( @{ $EXPORT_TAGS{ 'all' } } ) ;
    }

# ========= ========= ========= ========= ========= ========= =========
# think of this as main()
# --------- --------- --------- --------- --------- --------- ---------
sub make_eds {
    my ( $experiment , $temp ) = @_ ;
    my $homedir        = getcwd ;
    my $tmpdir = tempdir( DIR => $temp, CLEANUP => 1 ) ;
    my $home_dir = File::HomeDir->my_home;
    my $templates = $home_dir . '/.stepone/Templates' ;
    my $source    = $home_dir . '/.stepone/Source' ;
    my $target    = $tmpdir ;

    $experiment->{ templates } =
          $experiment->{ templates }
        ? $experiment->{ templates }
        : $templates ;
    $experiment->{ target } =
          $experiment->{ target }
        ? $experiment->{ target }
        : $target ;

    # create file system in temp directory
    clone_Directory( $source, $target ) ;

    # write experiment.xml
    experiment_template( $experiment )
        or croak 'experiment did not write' ;

    # write plate_setup.xml
    plate_template( $experiment )
        or croak 'plate record did not write' ;

    chdir $target ;
    my @input = read_Directory( '.' ) ;
    @input = sort map { s/^\.\/// ; $_ } @input ;
    my $input = \@input ;

    my $zip ;
    my $output = \$zip ;
    my $status = zip $input => $output
        or croak "zip failed: $ZipError\n" ;
    chdir $homedir ;
    return $zip ;
    }

# ========= ========= ========= ========= ========= ========= =========
# copy a directory structure into another directory
# --------- --------- --------- --------- --------- --------- ---------
sub clone_Directory {
    my ( $source, $target ) = @_ ;
    my $s = abs_path( $source ) ;
    my $t = abs_path( $target ) ;
    if ( opendir my $dh, $s ) {
        while ( defined( my $node = readdir( $dh ) ) ) {
            next if $node eq '.' ;
            next if $node eq '..' ;
            my $spath = join '/', $s, $node ;
            my $tpath = join '/', $t, $node ;
            if ( -d $spath ) {
                mkdir $tpath ;
                clone_Directory( $spath, $tpath ) ;
                }
            elsif ( -f $spath ) {
                copy( "$spath", "$tpath" ) or croak $!;
                }
            }
        }
    }

# ========= ========= ========= ========= ========= ========= =========
# list all the files in a directory structure
# --------- --------- --------- --------- --------- --------- ---------
sub read_Directory {
    my ( $dir ) = @_ ;
    my $directory = abs_path( $dir ) ;
    my @output ;
    if ( opendir my $dh, $directory ) {
        while ( defined( my $node = readdir( $dh ) ) ) {
            next if $node eq '.' ;
            next if $node eq '..' ;
            my $path = join '/', $dir, $node ;
            if ( -d $path ) {
                push @output, read_Directory( $path ) ;
                }
            elsif ( -f $path ) {
                push @output, $path ;
                }
            }
        }
    return @output ;
    }

# ========= ========= ========= ========= ========= ========= =========
# Writes plate data
# --------- --------- --------- --------- --------- --------- ---------
sub plate_template {
    my ( $data ) = @_ ;
    my $config = {
        POST_CHOMP => 1,
        ABSOLUTE   => 1,
        RELATIVE   => 1
        } ;
    my $template = Template->new( $config ) ;
    my $in       = $data->{ templates } . '/plate_setup.tt' ;
    my $out      = $data->{ target } . '/apldbio/sds/plate_setup.xml' ;
    my $vars ;
    my @repeats = @{ $data->{ replicates } } ;

    my @colors = (
        '-2105970', '-524376',  '-4915456',  '-13159',
        '-161192',  '-2755419', '-10420320', '-8076815',
        '-5701666',
        ) ;

    my $array ;
    my $features ;
    my $wells ;
    @$wells = ( 0 .. 47 ) ;
    my $c     = 2 ;
    my $index = 0 ;

    # NTCs
    for ( 0 .. 1 ) {
        my $feature ;
        $feature->{ index }         = $index++ ;
        $feature->{ color }         = -3083422 ;
        $feature->{ concentration } = '1.0' ;
        $feature->{ reporter }      = 'SYBR' ;
        $feature->{ task }          = 'NTC' ;
        push @$features, $feature ;
        }

    # UNKNOWNs, or samples
    for my $l ( 0 .. ( scalar @{ $data->{ sample_names } } ) - 1 ) {
        for ( @repeats ) {
            my $feature ;
            $feature->{ index }         = $index++ ;
            $feature->{ color }         = -3083422 ;
            $feature->{ concentration } = '1.0' ;
            $feature->{ reporter }      = 'SYBR' ;
            $feature->{ task }          = 'UNKNOWN' ;
            push @$features, $feature ;

            push @$array,
                {
                index => $c++,
                name  => $data->{ sample_names }->[ $l ],
                color => $colors[ $l ],
                } ;
            }
        }

   # STANDARDs
   #   This defines the standard curves.
   #       - Three wells with concentration of 20       (1)
   #       - Three wells with concentration of 2        (2)
   #       - Three wells with concentration of 0.2      (3)
   #       - Three wells with concentration of 0.02     (4)
   #       - Three wells with concentration of 0.002    (5) (optional)
   #       - Three wells with concentration of 0.0002   (6) (optional)
   # whether the low ones are in will be set by $top
    my $concentration = 20 ;
    my $top           = $data->{ std_curve } ;
    for my $i ( 1 .. $top ) {
        for ( 1 .. 3 ) {
            my $feature ;
            $feature->{ index }         = $index++ ;
            $feature->{ color }         = -3083422 ;
            $feature->{ concentration } = $concentration ;
            $feature->{ reporter }      = 'SYBR' ;
            $feature->{ task }          = 'STANDARD' ;

            push @$features, $feature ;
            }
        $concentration = $concentration / 10 ;
        }

    $vars->{ array }    = $array ;
    $vars->{ name }     = $data->{ experiment_name } ;
    $vars->{ wells }    = $wells ;
    $vars->{ features } = $features ;
    $template->process( $in, $vars, $out )
        || die "Template process failed: ", $template->error(), "\n" ;
    return 1 ;
    }

# ========= ========= ========= ========= ========= ========= =========
# Writes experiment data
# --------- --------- --------- --------- --------- --------- ---------
sub experiment_template {
    my ( $data ) = @_ ;
    my $config = {
        POST_CHOMP => 1,
        ABSOLUTE   => 1,
        RELATIVE   => 1
        } ;
    my $template = Template->new( $config ) ;
    my $in       = $data->{ templates } . '/experiment.tt' ;
    my $out      = $data->{ target } . '/apldbio/sds/experiment.xml' ;
    my $vars ;
    my @colors = (
        '-2105970', '-524376',  '-4915456',  '-13159',
        '-161192',  '-2755419', '-10420320', '-8076815',
        '-5701666',
        ) ;
    my $array ;

    for my $l ( 0 .. ( scalar @{ $data->{ sample_names } } ) - 1 ) {
        push @$array,
            {
            name          => $data->{ sample_names }->[ $l ],
            color         => $colors[ $l ],
            concentration => '100.0',
            } ;
        }
    $vars->{ array } = $array ;
    $vars->{ name }  = $data->{ experiment_name } ;

    $template->process( $in, $vars, $out )
        || die "Template process failed: ", $template->error(), "\n" ;
    return 1 ;
    }

1 ;
