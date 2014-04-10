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



### MAIN WORKFLOW
my $converter = Text::Iconv -> new ("utf-8", "windows-1251");
my $parser = Spreadsheet::XLSX->new();

#my $excel = Spreadsheet::XLSX -> new ($o_excel_file, $converter);
my $excel = $parser->parse($o_excel_file);

print Dumper($excel);

exit;
foreach my $sheet (@{$excel -> {Worksheet}}) {
 
    printf("Sheet: %s\n", $sheet->{Name});
    
    $sheet -> {MaxRow} ||= $sheet -> {MinRow};
    
    foreach my $row ($sheet -> {MinRow} .. $sheet -> {MaxRow}) {
     
            $sheet -> {MaxCol} ||= $sheet -> {MinCol};
            
            foreach my $col ($sheet -> {MinCol} ..  $sheet -> {MaxCol}) {
            
                    my $cell = $sheet -> {Cells} [$row] [$col];

                    if ($cell) {
                        printf("( %s , %s ) => %s\n", $row, $col, $cell -> {Val});
                    }

            }

    }
 
}


