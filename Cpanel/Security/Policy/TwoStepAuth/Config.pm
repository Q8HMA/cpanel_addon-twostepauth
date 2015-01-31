package Cpanel::Security::Policy::TwoStepAuth::Config;

## As per SecurityPolicy/Interface.pod

use Cpanel::Security::Policy::TwoStepAuth ();
use Cpanel::Locale                        ();

my $locale;

my $logger = Cpanel::Logger->new();

sub new {
    my ( $class, $policy ) = @_;
    die "No policy object supplied.\n" unless defined $policy;
    return bless { 'policy' => $policy }, $class;
}

sub config {
    my ( $self, $formref, $cpconf_ref, $is_save ) = @_;

    if(lc($formref->{'cmd'}) eq 'save') {
      my $CP_CONF_FILE = '/usr/local/cpanel/base/3rdparty/twostepauth/twostepauth.conf';
      if(defined $formref->{'TwoStepAuth'}) {
        $cp_config->{'policy'} = 1;
      } else {
        $cp_config->{'policy'} = 0;
      }

      Cpanel::TwoStepAuth::Utils::flushConfig( $cp_config, $CP_CONF_FILE );
    }

    $locale ||= Cpanel::Locale->get_handle();
    return {
	'header' => $locale->maketext('Two Step Auth Security Policy')
    };


}

1;
