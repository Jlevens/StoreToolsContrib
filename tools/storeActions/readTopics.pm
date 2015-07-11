#!/usr/bin/perl
# Principally intended for converting between RCS and PlainFileStore, this
# script should also work with any other pair of filestore inmplementations.

use strict;
use warnings;

package storeActions::readTopics;
use storeActions::Base;
our @ISA = qw(storeActions::Base);

use Foswiki::Meta;
use Foswiki::Store;

sub preRun {
    my $this = shift;
    my $timeMe = $this->SUPER::preRun(@_);

    my $iterations = 0;
    my @webs = @{$this->{args}{web}};

    my @metaTopics;
    for my $web (@webs) {
        my $webObject = Foswiki::Meta->new( $this->{session}, $web );
        my @topics = $this->{store}->eachTopic($webObject)->all;

        for my $topic ( @topics ) {
            my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );
            push @metaTopics, $meta;
            $iterations++;
        }
    }
    $this->{metaTopics} = \@metaTopics;
    $this->{pos} = 0;

    return $iterations;
}

sub run {
    my ($this) = $_[0]->SUPER::run(@_);

    my $meta = $this->{metaTopics}->[ $this->{pos}++ ];
    $this->{store}->readTopic($meta, 0);

    use Data::Dumper;
    $Data::Dumper::Sortkeys = 1;
    print Data::Dumper->Dump( [$meta->{_PREF_SET} ], ['PREF_SET'] );
    print Data::Dumper->Dump( [$meta->{_PREF_LOCAL} ], ['PREF_LOCAL'] );
    print Data::Dumper->Dump( [$meta->{PREFERENCES} ], ['PREFERENCES'] );
    print Data::Dumper->Dump( [$meta->{TOPICINFO} ], ['TOPICINFO'] );

}

1;
