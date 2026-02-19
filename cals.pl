#!/usr/bin/perl

use strict;
use warnings;

=head1 Cals

Merge two or more iCal calendars from their URLs and create a unified iCal file.

=cut

use lib qw(
    local/lib/perl5
    local/lib/perl5/x86_64-linux-thread-multi
);

# use LWP::Simple;
use LWP::UserAgent;
use Data::ICal;
use Data::ICal::Entry::Event;
use Text::vFile;
use Text::vFile::asData;
use Data::Dumper;
use Dotenv -load;

my $ua = LWP::UserAgent->new();
# $ua->agent("Calify/1.0");
$ua->timeout(10);

my $airbnb_url   = $ENV{AIRBNB_CAL};
my $vrbo_url     = $ENV{VRBO_CAL};
my $bookings_url = $ENV{BOOKINGS_CAL};

# file fetch
my %downloads = (
    'airbnb.ics'   => $airbnb_url,
    'vrbo.ics'     => $vrbo_url,
    'bookings.ics' => $bookings_url,
);

for my $file ( keys %downloads ) {
    my $url = $downloads{$file};
    my $response = $ua->get($url, ':content_file' => $file);

    if ( $response->is_success ) {
        print "Downloaded $url to $file\n";
    } 
    else {
        die "Failed to download $url: " . $response->status_line . "\n";
    }
}

open my $fh, 'airbnb.ics' or die "couldn't open ics: $!";
my $airbnb_data = Text::vFile::asData->new->parse( $fh );

open $fh, 'vrbo.ics' or die "couldn't open ics: $!";
my $vrbo_data = Text::vFile::asData->new->parse( $fh );

open $fh, 'bookings.ics' or die "couldn't open ics: $!";
my $bookings_data = Text::vFile::asData->new->parse( $fh );

my $calendar = Data::ICal->new();

# merge events
my $count = 0; my $name = '';
for my $cal ($airbnb_data, $vrbo_data, $bookings_data) {
    $count++;
    if ( $count == 1 ) {
        $name = 'AirBnB';
    }
    elsif ( $count == 2 ) {
        $name = 'VRBO';
    }
    else {
        $name = 'Bookings.com';
    }
    for my $event (@{$cal->{objects}[0]{objects}}) {
        next unless $event->{type} eq 'VEVENT';
        my $entry = Data::ICal::Entry::Event->new();
        $entry->add_properties(
            summary     => "$name: " . $event->{properties}->{SUMMARY}[0]{value},
            dtstart     => $event->{properties}->{DTSTART}[0]{value},
            dtend       => $event->{properties}->{DTEND}[0]{value},
            description => $event->{properties}->{DESCRIPTION}[0]{value},
            uid         => $event->{properties}->{UID}[0]{value} || uuid(),
        );
        $calendar->add_entry($entry);
    }
}

open my $out, '>', './merged_calendar.ics' or die $!;
print $out $calendar->as_string;
close $out;




