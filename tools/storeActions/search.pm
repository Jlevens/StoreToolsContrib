#!/usr/bin/perl

use strict;
use warnings;

package storeActions::search;
use storeActions::Base;
our @ISA = qw(storeActions::Base);

use Foswiki::Meta;
use Foswiki::Store;


sub opts {
    my $this = shift;
    return $this->SUPER::opts( { term => '' }, "term=s", );
}

sub preRun {
    my $this = shift;
    my $timeMe = $this->SUPER::preRun(@_);

    my $iterations = 0;
    my @webs = @{$this->{args}{web}};

    my $web = $webs[0];
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    my @topics = $this->{store}->eachTopic($webObject)->all;

    require Foswiki::ListIterator;
    $this->{web} = $web;
    $this->{topics} = Foswiki::ListIterator::->new( \@topics );
    $this->{pos} = 0;

    return 0;
}

sub run {
    my ($this) = $_[0]->SUPER::run(@_);
    
    my $seen = $this->{store}->_search( $this->{args}{term}, $this->{web}, $this->{topics}, $this->{session}, { type => 'regex' } );
    
    use Data::Dumper;
    $Data::Dumper::Sortkeys = 1;
    print Data::Dumper->Dump( [$seen], ['seen'] );
}

1;
