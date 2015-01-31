package Cpanel::Security::Policy::TwoStepAuth;

use base 'Cpanel::SecurityPolicy::Base';

use Digest::MD5                qw(md5_hex);
use Cpanel::SafeDir              ();
use Cpanel::Logger               ();
use Cpanel::Config               ();
use Cpanel::TwoStepAuth::Utils;
use Cpanel::PwCache

my $CP_CONF_FILE = '/usr/local/cpanel/base/3rdparty/twostepauth/twostepauth.conf';

sub new {
  my ($class) = @_;

  # Compiler does not necessarily properly load the base class.
  unless ( exists $INC{'Cpanel/SecurityPolicy/Base.pm'} ) {
    eval 'require Cpanel::SecurityPolicy::Base;';
  }
  return Cpanel::SecurityPolicy::Base->init( __PACKAGE__, 20 );
}

sub fails {
  my ( $self , $sec_ctxt, $cpconf ) = @_;

  my $cookie_ref = $sec_ctxt->{'cookies'};

  if ($sec_ctxt->{"request_type"} ne "normal" || $sec_ctxt->{'appname'} ne "cpaneld") {
      return 0;
  }
  if ( !$sec_ctxt->{'is_possessed'} && $sec_ctxt->{'virtualuser'} ) {
      return 0;
  }
  if ( $sec_ctxt->{'auth_by_accesshash'} ) {
      return 0;
  }

  my $user;
  if ( $sec_ctxt->{'is_possessed'} ) {
      return 0;
      $user = $sec_ctxt->{'possessor'};
  }
  else {
      $user = $sec_ctxt->{'user'};
  }
  $user =~ /(.*)/;    # TODO: brute-force untaint
  $user = $1;

  ($login,$pass,$uid,$gid) = getpwnam($user);

  my $homedir = ( Cpanel::PwCache::getpwuid($uid) )[7];
  $settings_file = $homedir.'/.twostepauth/conf';

  my $user_conf = Cpanel::TwoStepAuth::Utils::load_Config($settings_file);

  my $cpsession = md5_hex($ENV{'cp_security_token'});

  if (defined $user_conf->{'skip'} && $user_conf->{'skip'} eq $cpsession ) {
     return 0;
  }

  if ($user_conf->{'salt'} && $user_conf->{'enabled'}) {
	return 1;
  }

  return 0;
}

sub description {
    $locale ||= Cpanel::Locale->get_handle();

    return $locale->maketext('Two Step Auth Security Policy');
}

1;

