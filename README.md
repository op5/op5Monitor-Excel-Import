op5Monitor-Excel-Import
=======================

This program is intented to bulk-import hosts into op5 Monitor using the HTTP APIs of the product. It reads an Excel-File (xlsx format) line-by-line, while the first line is interpreted as the header line. The headings in the first line must conclude with op5 Monitor / Nagios Core object attribute names, such as "address, alias, hostgroups, parents, ..." in order to create the host objects. Each column of the Excel file has to use either one of the below listed header captions as a heading or one of the following special headings:

- a custom host variable in the `_VARIABLENAME` form
- the word `CLONEFROM`
- the word `AUTODETECT_WIN_DISKS`

Even if the heading is defined for a certain column, you can leave the cell empty for one of several hosts. In this case the script will act as if the corresponding column would not exist at all.


## Excel file column headers

### Scalar headers

The following header captions can be used for scalar type attributes, meaning that the attribute contains a single string or number as an argument. Please note Excel's behavior of automatically reformatting strings when an inappropriate cell formatting is enabled. Especially, IP addresses get easily misformatted when using the "standard" cell formatting in Excel.

- `host_name`
- `alias`
- `address`
- `action_url`
- `icon_image`
- `statusmap_image`
- `template`
- `check_command`
- `max_check_attempts`
- `check_interval`
- `retry_interval`
- `check_period`
- `notification_interval`
- `notification_period`
- `display_name`
- `check_command_args`
- `freshness_threshold`
- `event_handler`
- `event_handler_args`
- `low_flap_threshold`
- `high_flap_threshold`
- `first_notification_delay`
- `icon_image_alt`
- `notes`
- `notes_url`

The only required attributes to be set for a host to be added correctly, are the "host_name" and "address" attributes.


### Array-style headers

Some of the header captions can be used for multi-value options. Every of the cells may contain a single word or value, but also a list of values, separated by commas. This way, you can add for example two host groups by using the "network,servers" notation. The array-style header captions are the following ones:

- `hostgroups`
- `flap_detection_options`
- `parents`
- `contact_groups`
- `notification_options`
- `children`
- `contacts`
- `stalking_options`

Non of these attributes are required.


### BOOLean headers

Some of the host object attributes that you can use as headings for the Excel columns are booleans. They can have a "true" or a "false" value. You can use the content "1", "true" or "yes" as a value to set the cell to "true", all other content will set the cell to "false" and an empty cell will make the script NOT pass this attribute to op5 Monitor which means that the default value will be used. The following header captions are the booleans:

- `active_checks_enabled`
- `passive_checks_enabled`
- `event_handler_enabled`
- `flap_detection_enabled`
- `process_perf_data`
- `retain_status_information`
- `retain_nonstatus_information`
- `notifications_enabled`
- `obsess`
- `obsess_over_host`
- `check_freshness`


### CLONEFROM - clone service checks attached to specific host(s)

If the special word `CLONEFROM` is found as a header for any of the columns and the value of the corresponding cell for the specific host that is to be added is set to "true", "1" or "yes", all service check objects that are directly attached to the host object(s) defined in the `CLONEFROM` cell for the specific host (comma-notation can be used to list several source hosts) are cloned to the newly created host.

Please note that only DIRECTLY attached service objects are cloned, not those that are attached to the source host using host groups. 


### AUTODETECT_WIN_DISKS - scanning for and adding service checks for disk drives on Windows through NSClient++

If the special word `AUTODETECT_WIN_DISKS` is found as a header for any of the columns and the value of the corresponding cell for the specific host that is to be added is set to "true", "1", or "yes", the host object's address will be connected through the "check_nrpe" check plugin to ask the NSClient++ agent on the remote Windows host for available Windows disk drives (C:, D: etc.) that are of type "fixed" (normal hard drives, no CDROMs etc.). For each of the disk drives detected on the remote host, a corresponding service check is automatically added. 


# Configuration

# Usage