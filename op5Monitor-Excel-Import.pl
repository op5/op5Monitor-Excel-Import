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


our $o_help;
our $o_save;
our $o_debug;
our $o_config_file = '/opt/api-scripts/api-scripts.config.yml';
our $o_excel_file;
our $o_periodically_save;

check_options();
our $config = LoadFile($o_config_file);


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
    's'   => \$o_save,  'save'  => \$o_save,
    'd'   => \$o_debug,   'debug' => \$o_debug,
    'c:s' => \$o_config_file, 'config:s' => \$o_config_file,
    'x:s' => \$o_excel_file,  'excelfile:s' => \$o_excel_file,
    'p:i' => \$o_periodically_save
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

sub check_column_content_is_scalar {
	my $column = shift;

	my @scalar_column_headers = (
		"host_name",
		"alias",
		"address",
		"action_url",
		"icon_image",
		"statusmap_image",
		"template",
		"check_command",
		"max_check_attempts",
		"check_interval",
		"retry_interval",
		"check_period",
		"notification_interval",
		"notification_period",
		"display_name",
		"check_command_args",
		"freshness_threshold",
		"event_handler",
		"event_handler_args",
		"low_flap_threshold",
		"high_flap_threshold",
		"first_notification_delay",
		"icon_image_alt",
		"notes",
		"notes_url"
	);

	my $match;
	foreach (@scalar_column_headers) {
		if ($_ eq $column) {
			$match = 1;
		}

		# host custom variables are also scalars
		if ($column =~ /^_[A-Z_1-9]+$/) {
			$match = 1;
		}
	}
	return $match;
}

sub check_column_content_is_array {
	my $column = shift;

	my @array_column_headers = (
		"hostgroups",
		"flap_detection_options",
		"parents",
		"contact_groups",
		"notification_options",
		"children",
		"contacts",
		"stalking_options"
	);

	my $match;
	foreach (@array_column_headers) {
		if ($_ eq $column) {
			$match = 1;
		}
	}
	return $match;
}

sub check_column_content_is_bool {
	my $column = shift;

	my @bool_column_headers = (
		"active_checks_enabled",
		"passive_checks_enabled",
		"event_handler_enabled",
		"flap_detection_enabled",
		"process_perf_data",
		"retain_status_information",
		"retain_nonstatus_information",
		"notifications_enabled",
		"obsess",
		"obsess_over_host",
		"check_freshness"
	);

	my $match;
	foreach (@bool_column_headers) {
		if ($_ eq $column) {
			$match = 1;
		}
	}
	return $match;
}

sub do_msg {
  # can be "info", "warning", "error"
  my $level = shift; 
  my $msg = shift;

  if ($level eq "info") {
    if (defined($o_debug)) {
      print "$msg\n";
    }
  } else {
    print "$msg\n";
  }
}

sub op5api_get_all_hostnames {
  my $url = 'https://' . $config->{op5api}->{server} . '/api/config/host';
  my $res = get_op5_api_url($url);

  if ($res->{code} != 200) {
  	print "ERROR: could not get all hosts from op5 API!\n";
  	my $msg = decode_json($res->{content});
  	print $msg->{full_error}, "\n";
  	exit;
  }

  my $content = decode_json($res->{content});

  my @return;
  foreach (@$content) {
    push (@return, $_->{name});
  }
  return @return
}

sub create_host_object {
	my $hostdata = shift;

	# check if the very basic data for this host is existing
	if (! $hostdata->{host_name}) { 
		return (0, "ERROR: not adding a host without a host name"); 
	}
	if (! $hostdata->{address}) { $hostdata->{address} = $hostdata->{host_name}; }
	if (! $hostdata->{alias}) { $hostdata->{alias} = $hostdata->{host_name}; }

	# debugging
	if ($o_debug) {
		print "DEBUG: ", encode_json( $hostdata ), "\n\n";
	}

	# check if a host with this name is already existing in running configuration
	my @all_hosts = op5api_get_all_hostnames();
	my $match;
	foreach (@all_hosts) {
		if ($_ eq $hostdata->{host_name}) {
			$match = 1;
		}
	}
	if ($match) {
		return (0, "not adding host \"" . $hostdata->{host_name} . "\" because another host with the same name does already exist");
	}

	# how that we know $hostdata is consistent, push it through the API of op5 Monitor
	my $res = post_op5_api_url( 'https://'.$config->{op5api}->{server}.'/api/config/host', (encode_json( $hostdata )) );

	if ($res->{code} == 201) {
		return (1, "success - " . $hostdata->{host_name});
	} else {
		my $msg = decode_json($res->{content});
		return (0, "host not created, API return code " . $res->{code} . " - " . $msg->{full_error});
	}

}

sub op5api_clone_one_service {
	my $from_host = shift;
	my $to_host = shift;
	my $svcdescription = shift;

	# fetch service data structure from from_host
	my $svcdata = op5api_get_svcdescription_from_host($from_host, $svcdescription);
	$svcdata->{host_name} = $to_host;

	my $res = post_op5_api_url( 'https://'.$config->{op5api}->{server}.'/api/config/service', (encode_json( $svcdata )) );

	if ($res->{code} == 201) {
		return "    success - \"" . $svcdescription . "\" cloned from host \"" . $from_host . "\" to \"" . $to_host . "\"";
	} else {
		my $msg = decode_json($res->{content});
		return "    could not clone \"" . $svcdescription . "\" from \"" . $from_host . "\" to \"" . $to_host . "\", error code: " . $res->{code} . " - " . $msg->{full_error};
	}
}

sub op5api_host_exists {
	my $host = shift;
	my @all_hosts = op5api_get_all_hostnames();
	my $match;
	foreach (@all_hosts) {
		if ($_ eq $host) {
			$match = 1;
		}
	}
	return $match;
}

sub op5api_get_svcdescription_from_host {
	my $host = shift;
	my $svcdescription = shift;

	my $url = op5api_get_url_for_service($host, $svcdescription);
	my $res = get_op5_api_url($url);

	if ($res->{code} != 200) {
		print "ERROR: could not get service details from op5 API! $url\n";
		my $msg = decode_json($res->{content});
	  	print $msg->{full_error}, "\n";
	  	exit;
	}

	return decode_json($res->{content});
}

sub op5api_get_all_servicedescriptions_from_host {
	my $host = shift;
	my $url = op5api_get_url_for_host($host);

	my $res = get_op5_api_url($url);

	if ($res->{code} != 200) {
		print "ERROR: could not get host details from op5 API!\n";
		my $msg = decode_json($res->{content});
	  	print $msg->{full_error}, "\n";
	  	exit;
	}

	my $content = decode_json($res->{content});
	my @return;

	if ($content->{services}) {
		foreach my $service (@{$content->{services}}) {
			push(@return, $service->{service_description});
		}
	}

	return @return;
}

sub op5api_host_has_service {
	my $host = shift;
	my $svcdescription = shift;

	#TODO host group services handling could be a good idea

	my @services = op5api_get_all_servicedescriptions_from_host($host);
	my $match;
	foreach (@services) {
		if ($_ eq $svcdescription) {
			$match = 1;
		}
	}

	return $match;
}

sub clone_services {
	my $from_hosts_ref = shift;
	my @from_hosts = @$from_hosts_ref;
	my $to_host = shift;

	# check if destination host exists
	if (! op5api_host_exists($to_host)) {
		return "ERROR: destination host \"" . $to_host . "\" does not exist in Monitor";
	}

	# now start walking through the source hosts
	foreach my $from_host (@from_hosts) {

		# check source host for existence
		if (! op5api_host_exists($from_host)) {
			print "  source host \"" . $from_host . "\" does not exist, skipping\n";
			next; 
		}

		my @from_host_svcdescriptions = op5api_get_all_servicedescriptions_from_host($from_host);

		# check if the source host actually has any services to clone
		if (scalar(@from_host_svcdescriptions) == 0) {
			print "  source host \"" . $from_host . "\" does not have any services, skipping\n";
			next; 
		}

		foreach my $svcdescription (@from_host_svcdescriptions) {

			# now check if the to_host already has a service with this service_description
			if (op5api_host_has_service($to_host, $svcdescription)) {
				print "    destination host \"" . $to_host . "\" already has service: \"" . $svcdescription . "\", skipping\n";
				next;
			} 

			# now it's clear we can do this, so let's do it :)
			my $output = op5api_clone_one_service($from_host, $to_host, $svcdescription);
			print $output , "\n";
		}
	}
}

sub execute_nrpe_command {
	my $hostaddress = shift;
	my $nrpe_command = shift;
	my $arguments = shift;

	my $nrpe_bin = $config->{excel_import}->{check_nrpe_path};
	my $result;

	if (! (-e $nrpe_bin and -x $nrpe_bin)) {
		$result->{error} = $!;
		return $result;
	}


	my $ssl_opt = "";
	if ($config->{excel_import}->{check_nrpe_use_ssl} eq "true") {
		$ssl_opt = " -s";
	}

	my $full_command = $nrpe_bin . $ssl_opt . " -H " . $hostaddress . " -c " . $nrpe_command;

	if ($arguments) {
		$full_command .= " -a " . $arguments;
	}

	if ($o_debug) {
		print "DEBUG: about to execute \"" . $full_command . "\"\n";
	}

	# execute the command
	my $output = `$full_command`;
	my $exitcode = $?;
	chomp $output;

	$result->{exitcode} = $exitcode;
	$result->{output} = $output;
	return $result;
}

sub get_existing_windows_disks_via_nrpe {
	my $hostaddress = shift;
	my $return;

	my $nrpe_arguments = "CheckAll ShowAll=short FilterType=FIXED ignore-perf-data";
	my $nrpe_return = execute_nrpe_command($hostaddress, "CheckDriveSize", $nrpe_arguments);

	if ($nrpe_return->{error}) {
		my $return->{error} = $nrpe_return->{error};
		return $return;
	}

	my $nrpe_output = $nrpe_return->{output};
	$nrpe_output =~ s/^[A-Z]+: //;
	$nrpe_output =~ s/\\:.*, /#/;
	$nrpe_output =~ s/\\:.*$//;

	my @return_drives = split(/#/, $nrpe_output);

	$return->{drives} = \@return_drives;
	return $return;
} 


### MAIN WORKFLOW
my $converter = Text::Iconv -> new ("utf-8", "windows-1251");
my $workbook = Spreadsheet::XLSX -> new ($o_excel_file, $converter);

my $worksheet = $workbook->worksheet(0);
my ( $row_min, $row_max ) = $worksheet->row_range();
my ( $col_min, $col_max ) = $worksheet->col_range();

# build array of headers of this Spreadsheet
my $headers;
for my $col ($col_min .. $col_max) {
	my $cell = $worksheet->get_cell( 0, $col );
	my $cellcontent = $cell->unformatted();
	chomp $cellcontent;
	push(@$headers, $cellcontent);
}

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
my $written_hosts_counter = 0;
for my $row ( $row_min+1 .. $row_max ) {

	# this happens for each of the lines in the XLS except the first one (which is the header line)
	my $hostdata;
	my $current_col_index = $col_min;
	my @clone_services_from_hosts = ();
	my $this_host_written;

	for my $col ( $col_min .. $col_max ) {
		my $cell = $worksheet->get_cell( $row, $col );
		my $cellcontent;

		if ($cell) {
			$cellcontent = $cell->unformatted();
			chomp $cellcontent;

			my $current_column = $headers->[$current_col_index];

			if (check_column_content_is_scalar($current_column)) {
				$hostdata->{$current_column} = $cellcontent;
			}

			if (check_column_content_is_array($current_column)) {
				my @content_array = split(/,/, $cellcontent);

				$hostdata->{$current_column} = \@content_array;
			}

			if (check_column_content_is_bool($current_column)) {
				my $boolean = JSON::PP::false;
				if ($cellcontent eq "1") { $boolean = JSON::PP::true; }
				if ($cellcontent eq "yes") { $boolean = JSON::PP::true; }
				if ($cellcontent eq "true") { $boolean = JSON::PP::true; }

				$hostdata->{$current_column} = $boolean;
			}

			# check if service cloning should be done
			if ($current_column eq "CLONEFROM") {
				@clone_services_from_hosts = split(/,/, $cellcontent);
			}
		}

		$current_col_index++;
	}

	# execute host creation
	my ($written, $res) = create_host_object($hostdata);
	print "Host #", $row, ": ", $res, "\n";
	if ($written) {
		$this_host_written = 1;
	}

	# execute the service cloning
	$written = clone_services(\@clone_services_from_hosts, $hostdata->{host_name});
	if ($written) {
		$this_host_written = 1;
	}

	# increase counter of written hosts
	if ($this_host_written) {
		$written_hosts_counter++;
	}

	# periodically save to not slow down too much
	if ($o_periodically_save) {
		if ($written_hosts_counter % $o_periodically_save == 0) {
			op5_api_check_and_save();
		}
	}
}

# check if save is necessary and save the configuration
op5_api_check_and_save();
