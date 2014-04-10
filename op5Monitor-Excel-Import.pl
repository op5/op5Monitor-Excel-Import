#!/usr/bin/perl

## VERSION 0.1.0


use strict;
use warnings;
use LWP;
use JSON::PP;
use URI::Escape;
use Getopt::Long;
use Data::Dumper;
use YAML qw(LoadFile);;
#use List::MoreUtils qw(uniq);
use Spreadsheet::XLSX;
use Text::Iconv;
use File::Basename;

# own modules
use lib dirname (__FILE__) . '/inc';
use op5Monitor_API;


my $o_help;
my $o_pretend;
my $o_nosave;
my $o_debug;
my $o_config_file = '/opt/api-scripts/api-scripts.config.yml';
my $o_excel_file;

check_options();
my $config = LoadFile($o_config_file);


### FUNCTIONS
sub print_usage {
    print "no usage information yet\n";
}

sub print_help {
  print_usage();
  print <<"EOT";
  no help text yet
EOT
  exit 0;
}

sub check_options {
  Getopt::Long::Configure("bundling");
  GetOptions(
    'h'   => \$o_help,    'help'    => \$o_help,
    'p'   => \$o_pretend, 'pretend' => \$o_pretend,
    'n'   => \$o_nosave,  'nosave'  => \$o_nosave,
    'd'   => \$o_debug,   'debug' => \$o_debug,
    'c:s' => \$o_config_file, 'config:s' => \$o_config_file,
    'x:s' => \$o_excel_file,  'excelfile:s' => \$o_excel_file
  );

  if (defined $o_help) { print_help; }
}

sub xls_headers_errors {
	my $headers = shift;
	my @errors;
	my @allowed_headers = (
	  'host_name',
	  'alias',
	  'address',
	  'action_url',
	  'icon_image',
	  'statusmap_image',
	  'template',
	  'check_command',
	  'max_check_attempts',
	  'check_interval',
	  'retry_interval',
	  'check_period',
	  'notification_interval',
	  'notification_period',
	  'display_name',
	  'check_command_args',
	  'freshness_threshold',
	  'event_handler',
	  'event_handler_args',
	  'low_flap_threshold',
	  'high_flap_threshold',
	  'first_notification_delay',
	  'icon_image_alt',
	  'notes',
	  'notes_url',
	  'hostgroups',
	  'flap_detection_options',
	  'parents',
	  'contact_groups',
	  'notification_options',
	  'children',
	  'contacts',
	  'stalking_options',
	  'active_checks_enabled',
	  'passive_checks_enabled',
	  'event_handler_enabled',
	  'flap_detection_enabled',
	  'process_perf_data',
	  'retain_status_information',
	  'retain_nonstatus_information',
	  'notifications_enabled',
	  'obsess',
	  'obsess_over_host',
	  'check_freshness',
	);

	foreach (@$headers) {
		# exception: custom variable
		if (/^_[A-Z_1-9]+$/) {
			next;
		}

		# exception: clonefrom
		if (/^CLONEFROM$/) {
			next;
		}

		my $match;
		my $header = $_;
		foreach (@allowed_headers) {
			if ($_ eq $header) {
				$match = 1;
			}
		}

		if (! $match) {
			push(@errors, $header);
		}
	}

	return @errors;
}



### MAIN WORKFLOW
my $converter = Text::Iconv -> new ("utf-8", "windows-1251");
my $workbook = Spreadsheet::XLSX -> new ($o_excel_file, $converter);

my $worksheet = $workbook->worksheet(0);
my ( $row_min, $row_max ) = $worksheet->row_range();
my ( $col_min, $col_max ) = $worksheet->col_range();

print "DEBUG row_min: $row_min, row_max: $row_max, col_min: $col_min, col_max: $col_max\n";

# build array of headers of this Spreadsheet
my $headers;
for my $col ($col_min .. $col_max) {
	my $cell = $worksheet->get_cell( 0, $col );
	my $cellcontent = $cell->unformatted();
	chomp $cellcontent;
	push(@$headers, $cellcontent);
}

print Dumper($headers);
print $$headers[0], "\n";
print $headers->[0], "\n";

# check if these headers are valid ones (existing entries for host objects)
my @errors = xls_headers_errors($headers);
if (scalar(@errors) > 0) {
	print "The following headers of your xls file are not allowed to be used: \n";
	foreach (@errors) {
		print ' ', $_;
	}
	print "\n";
	exit;
}

# walk through the host entries and do some magic
for my $row ( $row_min+1 .. $row_max ) {

	# this happens for each of the lines in the XLS except the first one (which is the header line)
	my $hostdata;
	my $current_col_index = $col_min;
	for my $col ( $col_min .. $col_max ) {
		my $cell = $worksheet->get_cell( $row, $col );
		my $cellcontent = $cell->unformatted();
		chomp $cellcontent;

		$hostdata->{$headers->[$current_col_index]} = $cellcontent;

		$current_col_index++;
	}
	print encode_json($hostdata);

}





exit;
for my $worksheet ( $workbook->worksheets() ) {

    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    for my $row ( $row_min .. $row_max ) {
        for my $col ( $col_min .. $col_max ) {

            my $cell = $worksheet->get_cell( $row, $col );
            next unless $cell;

            print "Row, Col    = ($row, $col)\n";
            print "Value       = ", $cell->value(),       "\n";
            print "Unformatted = ", $cell->unformatted(), "\n";
            print "\n";
        }
    }
}

