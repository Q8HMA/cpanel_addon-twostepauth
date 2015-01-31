package Cpanel::Security::Policy::TwoStepAuth::UI::HTML;

# cpanel - Cpanel/Security/Policy/PasswordAge/UI/HTML.pm
#                                                 Copyright(c) 2011 cPanel, Inc.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use Cpanel::Security::Policy::TwoStepAuth ();
use Cpanel::ChangePasswd                  ();
use Cpanel::Email::PasswdPop              ();
use Cpanel::Encoder::Tiny                 ();
use Cpanel::Locale                        ();
use Cpanel::SecurityPolicy::UI            ();
use Digest::MD5                qw(md5_hex);
use Cpanel::TwoStepAuth::Utils;

my $locale;

my $CP_CONF_FILE = '/usr/local/cpanel/base/3rdparty/twostepauth/twostepauth.conf';

sub new {
    my ( $class, $policy ) = @_;
    die "No policy object supplied.\n" unless defined $policy;
    return bless { 'policy' => $policy }, $class;
}


sub process {
    my ( $self, $formref, $sec_ctxt, $cpconf_ref ) = @_;

    my $cookie_ref = $sec_ctxt->{'cookies'};

    my $user;

    if ( $sec_ctxt->{'is_possessed'} ) {
        $user = $sec_ctxt->{'possessor'};
    }
    else {
        $user = $sec_ctxt->{'user'};
    }

    $user =~ /(.*)/;    # TODO: brute-force untaint
    $user = $1;

    my ($login,$pass,$uid,$gid) = getpwnam($user);

    my $homedir = ( Cpanel::PwCache::getpwuid($uid) )[7];
    my $settings_file = $homedir.'/.twostepauth/conf';

    my $user_conf = Cpanel::TwoStepAuth::Utils::load_Config($settings_file);

    if (!$user_conf->{'enabled'} || !$user_conf->{'salt'}) {
       _redirect_home($sec_ctxt);
       return;
    }

    my $cp_config = Cpanel::TwoStepAuth::Utils::load_Config($CP_CONF_FILE);

    if (!$cp_config->{'policy'}) {
      _redirect_home($sec_ctxt);
      return;
    }

    my $bu_length = $cp_config->{'bu_length'} ? $cp_config->{'bu_length'}:16;

    $locale ||= Cpanel::Locale->get_handle();
    my $error = "";

    if ($formref->{'cp_auth'} eq 'Authenticate' || $formref->{'cp_verify'}) {
      my ($cp_verify)   = $formref->{'cp_verify'} ? $formref->{'cp_verify'} : "";
       
      if ($user_conf->{'salt'}) {
	my $out;
	if (length($cp_verify) eq 6) {
	        my $hash = md5_hex($user_conf->{'salt'} . $user);
	        my @cmd = ("/usr/local/cpanel/base/3rdparty/twostepauth/gauth.php", "-c=verify", "-p=$hash", "-v=$cp_verify");
	        $out = system(@cmd);
	} else {
		my $backups = $homedir.'/.twostepauth/backups';
		if (-e $backups ) {
			my $backup_codes = Cpanel::TwoStepAuth::Utils::load_Config($backups);
			foreach my $sym (sort keys %$backup_codes) {
				if (($sym =~ /^\d+$/) && ($cp_verify eq $backup_codes->{$sym}) && !(exists $backup_codes->{$sym.'-used'})) {
					$out = 0;
                                        $backup_codes->{$sym.'-used'} = 1;
					Cpanel::TwoStepAuth::Utils::flushConfig($backup_codes, $backups);
				}
			}
		}
	}

        if($out =~ /^0$/i) {

	  my $cpsession = md5_hex($ENV{'cp_security_token'});

          if ($cpsession) {
            $user_conf->{'skip'} = $cpsession;
            Cpanel::TwoStepAuth::Utils::flushConfig($user_conf, $settings_file);
          }

          _redirect_home($sec_ctxt);

          return;
        } else {
            $error = $locale->maketext('Error, please check your code.');
        }
      }
    } 

    my %template_vars = (
        'cp_security_token' => $ENV{'cp_security_token'}, 
        'cp_error'          => $error,
    );

    process_appropriate_template(
        'app'  => $sec_ctxt->{'appname'},
        'file' => 'cp',
        'data' => \%template_vars,
    );

    return;
}

sub process_appropriate_template {
    my (%opts) = @_;
    Cpanel::SecurityPolicy::UI::html_header();
    Cpanel::SecurityPolicy::UI::process_template( "TwoStepAuth/$opts{'file'}.html.tmpl", $opts{'data'} );
    Cpanel::SecurityPolicy::UI::html_footer();
}

sub _redirect_home {
  my ($acctref) = @_;

  my $theme = 'x3';
  $theme = $acctref->{'cptheme'} if defined $acctref->{'cptheme'} && -f "/usr/local/cpanel/base/frontend/$acctref->{'cptheme'}/index.html";
  Cpanel::SecurityPolicy::UI::force_redirect("$ENV{'cp_security_token'}/frontend/$theme/index.html");
}

1;
