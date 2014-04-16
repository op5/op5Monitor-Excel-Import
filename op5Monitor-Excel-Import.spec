Name: op5Monitor-Excel-Import
Version: 0.3.2
Release: 1.el6
Summary: Tool to import hosts from an Excel file as a source.
Group: Third Party		
BuildArch: noarch
License: MIT
URL: http://www.op5.com		
Source0: distribution/op5Monitor-Excel-Import-%{version}.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

Requires: perl perl-libwww-perl perl-JSON perl-URI perl-YAML perl-Text-Iconv perl-Spreadsheet-XLSX

%description
This program is intented to bulk-import hosts into a op5 Monitor installation using the op5 Monitor's HTTP API. It reads an Excel-file (.xlsx format, introduced in Excel 2007) line-by-line. The first line is interpreted as the header line. The headings have to conclude with Nagios Core's host object attribute names, such as "address", "alias", "hostgroups", "parents", ... in order to create the host objects. Additional to this, the script also supports cloning services from one or several hosts and auto-detecting and adding service checks for Windows Disk checks.

%prep
%setup

%install
rm -rf %{buildroot}
install -d %{buildroot}/opt/api-scripts
install -d %{buildroot}/opt/api-scripts/inc
install -m 755 op5Monitor-Excel-Import.pl %{buildroot}/opt/api-scripts/op5Monitor-Excel-Import.pl
install -m 644 README.md %{buildroot}/opt/api-scripts/README.md
install -m 644 LICENSE %{buildroot}/opt/api-scripts/LICENSE
install -m 644 Hosts-Example.xlsx %{buildroot}/opt/api-scripts/Hosts-Example.xlsx
install -m 644 inc/op5Monitor_API.pm %{buildroot}/opt/api-scripts/inc/op5Monitor_API.pm
install -m 644 op5Monitor-Excel-Import_README.pdf %{buildroot}/opt/api-scripts/op5Monitor-Excel-Import_README.pdf
install -m 644 api-scripts.config.yml %{buildroot}/opt/api-scripts/api-scripts.config.yml

%clean
rm -rf %{buildroot}

%files
/opt/api-scripts/op5Monitor-Excel-Import.pl
/opt/api-scripts/README.md
/opt/api-scripts/LICENSE
/opt/api-scripts/Hosts-Example.xlsx
/opt/api-scripts/inc/op5Monitor_API.pm
/opt/api-scripts/op5Monitor-Excel-Import_README.pdf
%config(noreplace) /opt/api-scripts/api-scripts.config.yml