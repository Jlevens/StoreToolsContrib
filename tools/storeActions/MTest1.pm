#!/usr/bin/perl
# Principally intended for converting between RCS and PlainFileStore, this
# script should also work with any other pair of filestore inmplementations.

use strict;
use warnings;

package storeActions::MTest1;
use storeActions::Base;
our @ISA = qw(storeActions::Base);

sub opts {
    my $this = shift;
    my $optErrors = $this->SUPER::opts();
    
    push @ARGV, 'RcsLite', '--', 'showConfig', '--', 'readTopics';
    return $optErrors;
}

1;
