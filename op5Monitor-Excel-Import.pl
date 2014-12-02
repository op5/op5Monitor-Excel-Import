#!/usr/bin/perl

use constant VERSION => '0.4.0';

# This program is a bulk-import script that reads an Excel file as an input
# and each host from this Excel list into op5 Monitor through the HTTP APIs
# of the op5 Monitor product.
# You can find more information on this program in the README file delivered
# with this distribution

##### Changelog
# 2014-04-11 v0.1.0 Christian Anton initial version
# 2014-04-14 v0.2.0 Christian Anton added Windows disks monitoring support
# 2014-04-14 v0.3.0 Christian Anton added README and help functions
# 2014-04-15 v0.3.1 Christian Anton HOTFIX: chomps for Drive letters to prevent the
#                                   auto-created service checks to contain newlines
# 2014-04-16 v0.3.2 Christian Anton now supporting rpm installation
# 2014-04-16 v0.3.3 Christian Anton adding DEPENDENCIES file to the distribution tarball
# 2014-04-17 v0.3.4 Christian Anton FIX: faulty regex caused disk detection only to detect the
#                                   first and the last disk drives
# 2014-09-19 v0.3.5 Christian Anton added overwrite mode
# 2014-12-02 v0.4.0 Christian Anton Proper handling of service dependencies added: now servicedependencies on 
#                                   services that are to be cloned are rewritten in case that they were
#                                   referring to another service on the same host


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
our $o_periodically_save = 20;
our $o_overwrite;
our $o_saveonly;
our $o_version;

check_options();
our $config = LoadFile($o_config_file);


### FUNCTIONS
sub print_usage {
    print "Usage: $0 [-V|--version] [-h|--help] [-d|--debug] [-s|--save] [-S|--saveonly]\n";
    print "  [-o|--overwrite-if-exists]\n";
    print "  [-c|--config <api-scripts.conf.yml>]\n";
    print "  [-x|--excelfile <Excel-File.xml>]\n\n";
}

sub print_help {
  print_usage();
  print <<"EOT";
-h, --help   
	print this help messages
-d, --debug
	print very detailed debugging information on the screen while executing program
-s, --save
	Save all changes to op5 Monitor API after executing the program
-S, --saveonly
	ONLY save changes. Intented to be used to save changes issued by the script
	when executing it without the "--save" parameter
-c <config_file>, --config <config_file>
	specify the configuration file to use. Default is to search for one in the path
	/opt/api-scripts/api-scripts.config.yml
-x <Excel-File>, --excelfile <Excel-File>
	specify the Excel-File needed to feed this program with informations about the hosts
	to add to op5 Monitor.
-o, --overwrite-existing
	overwrite host and service definitions in case it already exists. The normal behavior
	of this script is to skip the object in such a case.
-V, --version
	print the version of this tool
EOT
  exit 0;
}

sub check_options {
  Getopt::Long::Configure("bundling");
  GetOptions(
    'h'   => \$o_help,					'help'			=> \$o_help,
    's'   => \$o_save,					'save'  		=> \$o_save,
    'S'   => \$o_saveonly,				'saveonly' 		=> \$o_saveonly,
    'd'   => \$o_debug,					'debug' 		=> \$o_debug,
    'c:s' => \$o_config_file,			'config:s' 		=> \$o_config_file,
    'x:s' => \$o_excel_file,			'excelfile:s' 	=> \$o_excel_file,
    'o'   => \$o_overwrite,             'overwrite-if-exists' => \$o_overwrite,
    'p:i' => \$o_periodically_save,
    'V'	  => \$o_version,               'version'       => \$o_version
  );

  if ($o_help) { print_help; }

  if ($o_version) {
  	print VERSION, "\n";
  	exit;
  }

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

		# exception: autodetect_win_disks
		if (/^AUTODETECT_WIN_DISKS$/) {
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

	# how that we know $hostdata is consistent, push it through the API of op5 Monitor
	# ...but first check if the host already exists

	if (op5api_host_exists($hostdata->{host_name}) ) {

		if ($o_overwrite) {

			my $url = op5api_get_url_for_host($hostdata->{host_name});
			my $res = patch_op5_api_url( $url, (encode_json( $hostdata )) );

			if ($res->{code} == 200) {
				return (1, "host overwritten, success - " . $hostdata->{host_name});
			} else {
				my $msg = decode_json($res->{content});
				return (0, "host \"" . $hostdata->{host_name} . "\" not overwritten, API return code " . $res->{code} . " - " . $msg->{full_error});
			}

		} else {
			return (0, "host \"" . $hostdata->{host_name} . "\" not created, host already exists");
		}

	} else {

		my $res = post_op5_api_url( 'https://'.$config->{op5api}->{server}.'/api/config/host', (encode_json( $hostdata )) );

		if ($res->{code} == 201) {
			return (1, "success - " . $hostdata->{host_name});
		} else {
			my $msg = decode_json($res->{content});
			return (0, "host \"" . $hostdata->{host_name} . "\"not created, API return code " . $res->{code} . " - " . $msg->{full_error});
		}

	}

}

sub op5api_write_service {
	my $host = shift;
	my $svcdescription = shift;
	my $svcdata = shift;

	my $url = 'https://'.$config->{op5api}->{server}.'/api/config/service';

	my $res = post_op5_api_url($url, (encode_json( $svcdata )) );

	if ($res->{code} == 201) {
		return "    success - added \"" . $svcdescription . "\" to host \"" . $host . "\"";

	} elsif ($res->{code} == 409) {
		if ($o_overwrite) {

			my $url = op5api_get_url_for_service($host, $svcdescription);
			my $res = delete_op5_api_url($url);

			if ($res->{code} == 200) {
				print "    delete success - \"" . $svcdescription . "\" on \"" . $host . "\"\n";
				op5api_write_service($host, $svcdescription, $svcdata);
			} else {
				return "    could not delete \"" . $svcdescription . "\" on \"" . $host . "\", error code: " . $res->{content};
			}

		} else {
			return "    could not add \"" . $svcdescription . "\" to \"" . $host . "\", service already exists";
		}
	} else {
		my $msg = decode_json($res->{content});
		return "    could not add \"" . $svcdescription . "\" to \"" . $host . "\" , error code: " . $res->{code} . " - " . $msg->{full_error};
	}
}

sub op5api_write_service_dependency {
	my $dependent_host = shift;
	my $dependent_svcdescription = shift;
	my $dependency = shift;

	my $dependent_service = $dependent_host . ";" . $dependent_svcdescription;
	$dependency->{dependent_service} = $dependent_service;

	my $url = 'https://'.$config->{op5api}->{server}.'/api/config/servicedependency';
	my $res = post_op5_api_url($url, (encode_json( $dependency )) );

	if ($res->{code} == 201) {

		return "    success - servicedependency for " . $dependent_service . " depending on " . $dependency->{service} . " successful added";

	} else {
		my $msg = decode_json($res->{content});
		return "    could not add dependency for " . $dependent_service . " depending on " . $dependency->{service} . ", error code: " . $res->{code} . " - " . $msg->{full_error};
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

sub op5api_get_complete_host {
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
	return $content;
}

sub op5api_get_all_servicedescriptions_from_host {
	my $host = shift;

	my $content = op5api_get_complete_host($host);
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

		my $temporary_svcdependencies;

		foreach my $svcdescription (@from_host_svcdescriptions) {

			# create the service on the to_host
			my $svcdata = op5api_get_svcdescription_from_host($from_host, $svcdescription);

			if ($svcdata->{servicedependencys}) {
				foreach(@{$svcdata->{servicedependencys}}) {
					push(@{$temporary_svcdependencies->{$svcdescription}}, $_);
				}
				delete $svcdata->{servicedependencys};
			}

			$svcdata->{host_name} = $to_host;
			my $output = op5api_write_service($to_host, $svcdescription, $svcdata);
			print $output , "\n";
			
		}

		foreach my $dependent_svcdescription (keys %$temporary_svcdependencies) {

			foreach my $dependency (@{$temporary_svcdependencies->{$dependent_svcdescription}}) {

				# check if the destination of the dependency is the same as the host where the whole
				# service came from. If yes, change that!
				my $dependency_svcdescription = $dependency->{service};
				$dependency_svcdescription =~ s/^[^;]+;//;

				if ($dependency->{service} eq $from_host . ";" . $dependency_svcdescription) {
					$dependency->{service} = $to_host . ";" . $dependency_svcdescription;
				}
				my $output = op5api_write_service_dependency($to_host, $dependent_svcdescription, $dependency);
				print $output , "\n";
			}
		}
	}
}

sub op5api_add_windows_disk_drive_service {
	my $host = shift;
	my $driveletter = shift;

	# make sure no strange characters are contained in host name and drive letter variable strings
	chomp $host;
	chomp $driveletter;

	my $service_description = $config->{excel_import}->{windows_disk_checks}->{service_description};
	$service_description =~ s/%s/$driveletter/g;

	my $check_command_args = $config->{excel_import}->{windows_disk_checks}->{check_command_args};
	$check_command_args =~ s/%s/$driveletter/g;

	my $service = {
		'service_description' => $service_description,
		'template' => $config->{excel_import}->{windows_disk_checks}->{template},
		'host_name' => $host,
		'check_command' => $config->{excel_import}->{windows_disk_checks}->{check_command},
		'check_command_args' => $check_command_args
	};

	my $res = post_op5_api_url( 'https://'.$config->{op5api}->{server}.'/api/config/service', (encode_json( $service )) );

	if ($res->{code} == 201) {
		return "    success - \"" . $service_description . "\" created on host \"" . $host;
	} elsif ($res->{code} == 409) {

		if ($o_overwrite) {

			my $url = op5api_get_url_for_service($host, $service_description);
			my $res = patch_op5_api_url( $url, (encode_json( $service )) );

			if ($res->{code} == 200) {
				return "    overwrite success - \"" . $service_description . "\" created on host \"" . $host;
			} else {
				my $msg = decode_json($res->{content});
				return "    could not overwrite \"" . $service_description . "\" on \"" . $host . "\", error code: " . $res->{code} . " - " . $msg->{full_error};
			}

		} else {
			return "    could not add \"" . $service_description . "\" on \"" . $host . "\", service already exists";
		}

	} else {
		my $msg = decode_json($res->{content});
		return "    could not add \"" . $service_description . "\" on \"" . $host . "\", error code: " . $res->{code} . " - " . $msg->{full_error};
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

	$full_command .= " 2>&1";

	# execute the command
	my $output = `$full_command`;
	my $exitcode = $?;
	chomp $output;

	if ($exitcode > 3) {
		# something went wrong
		# convert multi-line error messages into one line
		$output =~ s/\R/ - /g;
		$result->{error} = $output;
	}

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
	$nrpe_output =~ s/\\:[^,]+, /#/g;
	$nrpe_output =~ s/\\:[^:]+$//;

	my @return_drives = split(/#/, $nrpe_output);
	chomp @return_drives;

	$return->{drives} = \@return_drives;
	return $return;
} 

sub autodetect_and_add_windows_disks {
	my $host = shift;

	# first, get the host address from the API
	my $hostcontent = op5api_get_complete_host($host);
	my $hostaddress = $hostcontent->{address};

	my $disks = get_existing_windows_disks_via_nrpe($hostaddress);

	if ($disks->{error}) {
		print "    ERROR: disks could not be scanned (address: " . $hostaddress . "): " . $disks->{error} . "\n";
		return 0;
	}

	my @diskdrives = @{$disks->{drives}};
	foreach my $driveletter (@diskdrives) {
		my $msg = op5api_add_windows_disk_drive_service($host, $driveletter);
		print $msg, "\n";
	}
	return 1;
}


### MAIN WORKFLOW

# saveonly
if ($o_saveonly) {
	$o_save = 1;
	op5_api_check_and_save();
	exit;
}

# all the rest
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
	my $autodetect_windows_disks;

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

			# check if auto-detection of windows services should be done
			if ($current_column eq "AUTODETECT_WIN_DISKS") {
				if ($cellcontent eq "1" or $cellcontent eq "yes" or $cellcontent eq "true") {
					$autodetect_windows_disks = 1;
				}
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

	# execute windows host auto-detection of disk drives via NRPE
	if ($autodetect_windows_disks) {
		$written = autodetect_and_add_windows_disks($hostdata->{host_name});
		if ($written) {
			$this_host_written = 1;
		}
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
	if ($written_hosts_counter % $o_periodically_save == 0) {
		op5_api_check_and_save();
	}
}

# check if save is necessary and save the configuration
op5_api_check_and_save();
