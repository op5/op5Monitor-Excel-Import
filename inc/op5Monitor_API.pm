#!/usr/bin/perl

# op5 API related functions
sub prepare_http_request {
  my $op5_api_authentication_realm;

  my $http_browser = LWP::UserAgent->new;
  $http_browser->agent('op5-api-scripts/0.0.0');

  # check if a non-standard authentication realm is set in config and use it, otherwise
  # use the default that op5 Monitor should be set to
  if ($config->{op5api}->{authentication_realm}) {
    $op5_api_authentication_realm = $config->{op5api}->{authentication_realm};
  } else {
    $op5_api_authentication_realm = 'op5 Monitor API Access';
  }

  $http_browser->credentials(
    $config->{op5api}->{server} . ':443',
    $op5_api_authentication_realm,
    $config->{op5api}->{user},
    $config->{op5api}->{password}
  );

  if ($http_browser->can('ssl_opts')) {
    if ($config->{op5api}->{ssl_verify_hostname} and $config->{op5api}->{ssl_verify_hostname} eq "true") {
      $http_browser->ssl_opts(
        verify_hostname => 1
      );
    } else {
      $http_browser->ssl_opts(
        verify_hostname => 0
      );
    }
  }
  return $http_browser;
}

sub get_op5_api_url {
  my $url = shift;
  my $return;

  my $http_browser = prepare_http_request();
  my $response = $http_browser->get($url);

  if ($response->is_success) {
    $return->{content} = $response->content;
  } else {
    $return->{content} = $response->status_line;
  }
  $return->{code} = $response->code;
  return $return;
}

sub post_op5_api_url {
  my $url = shift;
  my $json = shift;
  my $return;

  my $http_browser = prepare_http_request();

  my $req = HTTP::Request->new(POST => $url);
  $req->content_type('application/json');
  $req->content($json);

  my $res = $http_browser->request($req);

  if ($res->is_success) {
    $return->{content} = $res->content;
  } else {
    $return->{content} = $res->status_line;
  }
  $return->{code} = $res->code;
  return $return;
}

sub delete_op5_api_url {
  my $url = shift;
  my $return;

  my $http_browser = prepare_http_request();
  my $req = HTTP::Request->new(DELETE => $url);

  my $res = $http_browser->request($req);

  if ($res->is_success) {
    $return->{content} = $res->content;
  } else {
    $return->{content} = $res->status_line;
  }
  $return->{code} = $res->code;
  return $return;
}

sub patch_op5_api_url {
  my $url = shift;
  my $json = shift;
  my $return;

  my $http_browser = prepare_http_request();

  my $req = HTTP::Request->new(PATCH => $url);
  $req->content_type('application/json');
  $req->content($json);

  my $res = $http_browser->request($req);

  if ($res->is_success) {
    $return->{content} = $res->content;
  } else {
    $return->{content} = $res->status_line;
  }
  $return->{code} = $res->code;
  return $return;
}

1;