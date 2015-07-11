#!/usr/bin/perl

# Intended as a base class for the store.pl script.
# Derived classes perform specific storeActions to provide a generic store utility capability
# as well as benchmarking each utility against all requested stores.

use strict;
use warnings;

package storeActions::Base;

sub new {
    my $class = shift;
    my ($session, $args) = @_;

    my $this = bless( {}, $class );

    $this->{session} = $session;
    $this->{args} = $args;
    return $this;
}

sub opts {
    my ($this, $init, @opts)  = @_;
    # Parse the options for this storeAction
    use Getopt::Long qw(:config no_auto_abbrev ignore_case require_order);
    
    for my $key (keys %$init) {
        $this->{args}{$key} = $init->{$key} if !defined $this->{args}{$key}; # Initialise new keys only
    }
    GetOptions( $this->{args}, (@opts, @{ $this->{args}{__opts} } ) );

    return [ @$ ];
}

sub preRun {
    my $this = shift;
    $this->{store} = shift;
    $this->{iterations} = 0;
    return 0; # 1=Please benchmark my run(), 0=Don't
}

sub run {
    return @_;
}

# Return actual number of things processed. I.e. if readTopics reads 3258 topics from a web thenn return 3258
# This is used to updated the benchmark iterations. This is important partly for a finer grained feel (topics/s) but also
# when testing a different store you may only read 2378 topics, so this would allow a better reflection of timing.
#
# Of course if the two stores are that different then it does raise issue about the quality of the benchmark, be careful.

sub iterations {
    return $_[0]->{iterations};
}

use Foswiki::Meta;
use Foswiki::Store;

sub selectWebsAndTopics {
    my ($this, $store, $session, $args) = @_;

    my $rmeta = Foswiki::Meta->new($session);

    my %webs;
    if(scalar @{$args->{webs}} == 0) {
        %webs = map { $_ => 1 } $store->eachWeb($rmeta)->all;
    }
    else {
        %webs = map { $_ => 1 } @{$args->{webs}};
    }

    for my $web (sort keys %webs) {
        my $webObject = Foswiki::Meta->new($session, $web);
        my @topics = $store->eachTopic($webObject)->all;
    }   
}

{
    my %instantiatedConfigs;

    sub storeConfig {
        my ($cfgName) = @_;
        
        return $instantiatedConfigs{$cfgName} if $instantiatedConfigs{$cfgName};
        
        my $store = Foswiki::Store::newConfig($cfgName);
        $instantiatedConfigs{$cfgName} = $store;
        return $store;
    }   
    
    sub setConfig {
        my ($store) = @_;
        my $cfgName = $store->{cfg}->{_name};
        $instantiatedConfigs{$cfgName} = $store;
    }
}

1;
