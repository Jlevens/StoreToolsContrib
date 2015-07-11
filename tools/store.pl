#!/usr/bin/perl
# Generic tool for performing actions against any and many stores.

# The original goal was to provide benchmarking to compare different
# stores. However it was soon clear that a generic design was possible
# that would allow any sort of 'action' to be processed against
# multiple stores.
#
# Each action is defined by creating a small storeAction class in the
# tools/storeActions sub-directory.
#
# Another idea is that a hash is shared from action to action this allows
# something akin to unix pipes, e.g.

# store.pl --store RcsLite,PlainFile -Count 100 -Webs Main/*,System -Count 1 -Topics !Web* -ReadTopics -Query "'Field.StartDate >= '2012-01-01'" -cUID JulianLevens
# store.pl --store RcsLite,PlainFile -Count 100 -MyWebsTopics -Count 1 -ReadTopics -Query "'Field.StartDate >= '2012-01-01'" -cUID JulianLevens

use strict;
use warnings;

use Benchmark;
use File::Spec;
use Cwd;

BEGIN {
    my ( $volume, $toolsDir, $action ) = File::Spec->splitpath(__FILE__);
    $toolsDir = '.' if $toolsDir eq '';
    ($toolsDir) = Cwd::abs_path( $toolsDir ) =~ /(.*)/;
    @INC = ($toolsDir, grep { $_ ne $toolsDir } @INC );
    my $binDir = Cwd::abs_path( File::Spec->catdir( $toolsDir, "..", "bin" ) );
    my ($setlib) = File::Spec->catpath( $volume, $binDir, 'setlib.cfg' ) =~ /(.*)/;
    require $setlib;
}

use Foswiki                         ();
use Foswiki::Store;
use storeActions::Base              ();

my $session = new Foswiki();
storeActions::Base::setConfig($session->{store});

# Parse command line
use Getopt::Long qw(:config no_auto_abbrev ignore_case require_order);

my %args = ( verbose => 0, help => 0, validate => 0, web => [] );

$args{__opts} = [ 
    'verbose', 'quiet' => sub { $args{verbose} = 0 },
    'web|w=s@', 
    'validate',
    'help!',
    ];

GetOptions ( \%args, @{ $args{__opts} } );

my @storeConfigs;
my @errors;
my @acts;

while( @ARGV ) {
    my $action = shift @ARGV;
    next if $action eq '--';
    
    if( $Foswiki::cfg{StoreConfig}{$action} ) {
        push @storeConfigs, $action;
        next;
    }
    
    use Class::Load qw/try_load_class/;
    my ($module) = "storeActions::$action" =~ /(.*)/;
    my ( $ok, $error ) = try_load_class($module);

    if(!$ok) {
        print "Action '$action' not recognised (Failed to load $module)\n$error\n";
        last;
    }

    my $act = $module->new( $session, \%args );
    my @actErrors = @{$act->opts()};
    push @errors, "$action parameter errors:\n@actErrors\n" if @actErrors;
    push @acts, { act => $act, name => $action };
}

my %seen;
my @stores;
for my $storeConfig (@storeConfigs) {
    next if $seen{$storeConfig};
    $seen{$storeConfig} = 1;
    my $store = storeActions::Base::storeConfig($storeConfig);
    if ( !$store ) {
        push @errors, "Failed to initialise Store $storeConfig\n";
    }       
    push @stores, $store;
}

print @errors if @errors;

exit 12 if @errors;

use Benchmark qw( :hireswallclock cmpthese timethese ) ;

for my $a (@acts) {
    my ($act, $action) = ($a->{act}, $a->{name});
    my $results = {};
    print "\n\nRunning/benchmarking '$action'\n";
    for my $store (@stores) {
        my $iterations = $act->preRun($store);
        print "\n";
        if($iterations) {
            my $sc = $store->{cfg}{_name};
            my $res = timethese($iterations, { $sc => sub { $act->run(); } } );
            $results->{$sc} = $res->{$sc};
        }
        else {
            $act->run();
        }
    }
    my @tests = keys %$results;
    print "\n";
    cmpthese($results) if @tests;
}

exit 0;


=head1 NAME
 
sample - Using Getopt::Long and Pod::Usage
 
=head1 SYNOPSIS
 
sample [options] [file ...]
 
 Options:
   -help            brief help message
   -verbose         Produce detailed output
   -quiet           Basic running details
   -nobenchmark     Not sure, I think I always want to benchmark
   -topic|t         Topics to be processed, allows a subset of topics for testing purposes
                    Note the list is applied across all webs
   -web|w           Adds to the list of web names to process
                    (can be a single web or comma separated,
                    e.g. -w Main -w System,Sandbox would process all 3 of these webs)
                    If not provided then all webs are processed
   -store|s         Adds to the list of store-config names to process
                    (can be a single store-config or comma separated,
                    e.g. -s RcsLite -s PlainFile,VersaPlain would process all 3 of these store-configs)
   -action|a        Adds to the list of actions to initiate against each store
                    If no actions are provided then the stores config values are dumped
   -utf8            During 'change' will convert text to utf8 - this is the default
   -no-utf8

   -create          With 'change' action will ask a store to initialise itself, e.g. create base directories or database tables.
                    Therefore, this is a destructive option. 'change' is not destructive by design as when
                    developing you may convert only one web to start with, and then convert the rest later.
 
=head1 OPTIONS
 
=over 8
 
=item B<-help>
 
Print a brief help message and exits.
 
=back
 
=head1 DESCRIPTION
 
B<This program> is passed a list of webs (amongst other options) and will perform the requested action against all stores requested.

The primary intent is to provide a general structure to test store performance or convert a store from one to another.

However, an action could conceivably perform any useful utility or utilities against one or more stores.

=cut
