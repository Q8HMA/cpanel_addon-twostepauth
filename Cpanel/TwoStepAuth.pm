package Cpanel::TwoStepAuth;

use strict;
use Cpanel::SafeFile             ();
use Cpanel::SafeDir              ();
use Cpanel::FileUtils::TouchFile ();
use Cpanel::Logger               ();
use Cpanel::Config               ();
use Cpanel::Locale               ();
use Cpanel::Hostname		();
use Cpanel::Locale ();
use Digest::MD5                qw(md5_hex);
use Cpanel::TwoStepAuth::Utils;
our $VERSION = '1.0';

my $logger = Cpanel::Logger->new();
my $CP_CONF_FILE = '/usr/local/cpanel/base/3rdparty/twostepauth/twostepauth.conf';
my $users_dir = $Cpanel::homedir . '/.twostepauth/';
my $cp_config = Cpanel::TwoStepAuth::Utils::load_Config($CP_CONF_FILE);
my $bu_length = $cp_config->{'bu_length'} ? $cp_config->{'bu_length'}:16; 

sub TwoStepAuth_init {
  return if !Cpanel::hasfeature('twostepauth');

  my $settings_file = $users_dir . 'conf';
  my $backup_codes = $users_dir . 'backups';

  if(!-e $users_dir) {
	Cpanel::SafeDir::safemkdir( $users_dir, '0700' );
  }
  if(!-e $settings_file) {
      my $conf = { 'enabled' => 0, 'salt' => Cpanel::Rand::getranddata(32) };
      Cpanel::TwoStepAuth::Utils::flushConfig($conf, $settings_file);
      chmod 0600, $settings_file;
  }

  if(!-e $backup_codes) {
      my $conf = { '1' => Cpanel::Rand::getranddata($bu_length), '2' => Cpanel::Rand::getranddata($bu_length), '3' => Cpanel::Rand::getranddata($bu_length) };
      Cpanel::TwoStepAuth::Utils::flushConfig($conf, $backup_codes);
      chmod 0600, $backup_codes;
  }
  return 1;
}

sub TwoStepAuth_switch {
    return if !Cpanel::hasfeature('twostepauth');

    my $active = _active();

    if($active) {
      _active(0);
      $active = 0;
    } else {
      _active(1);
      $active = 1;
    }

    return;
}

sub TwoStepAuth_resetsalt {
    return if !Cpanel::hasfeature('twostepauth');

    my $settings_file = $users_dir . 'conf';

    if (-e $settings_file ) {
        my $conf = Cpanel::TwoStepAuth::Utils::load_Config($settings_file);
        $conf->{'salt'} = Cpanel::Rand::getranddata(32);
        $conf->{'enabled'} = 0;
        Cpanel::TwoStepAuth::Utils::flushConfig($conf, $settings_file);
    }

    return;    
}

sub TwoStepAuth_resetbackupcodes {
    return if !Cpanel::hasfeature('twostepauth');

    my $backup_codes = $users_dir . 'backups';
    if (-e $backup_codes ) {
    my $conf = { '1' => Cpanel::Rand::getranddata($bu_length), '2' => Cpanel::Rand::getranddata($bu_length), '3' => Cpanel::Rand::getranddata($bu_length) };
        Cpanel::TwoStepAuth::Utils::flushConfig($conf, $backup_codes);
    }
    return;    
}

sub TwoStepAuth_show_form {
  return if !Cpanel::hasfeature('twostepauth');

  my $locale = Cpanel::Locale->get_handle();
  if (!$cp_config->{'policy'}) {
    print  $locale->maketext('TwoStepAuth_is_not_active');
    return;
  }

  my ($active, $switch_form, $reset_form);

  if(_active()) {
    $active = $locale->maketext('TwoStepAuth_enabled');
    $switch_form = " <input class='input-button' type='submit' name='switch' value='" . $locale->maketext('TwoStepAuth_disable') . "'>";
    $reset_form = "";
  } else {
    $active = $locale->maketext('TwoStepAuth_disabled');
    $switch_form = "<input class='input-button' type='submit' name='switch' value='" . $locale->maketext('TwoStepAuth_enable') . "'>";
    $reset_form = "<input class='input-button' type='submit' name='resetsalt' value='".$locale->maketext('TwoStepAuth_reset_salt')."'>";
  }
  my $extra = "";

  my $form =<<EOF;
	<form method="POST">
	<h2>$active</h2>
	$reset_form
	$switch_form
	</form>
EOF

  print $form;
  return;
}

sub TwoStepAuth_active {
  return _active();
}

sub TwoStepAuth_show_backupcodes {
  return if !Cpanel::hasfeature('twostepauth');
  return if !$cp_config->{'policy'};
  my $backups = $users_dir . 'backups';
  my $conf = Cpanel::TwoStepAuth::Utils::load_Config($backups);
  my $keys = '';

  foreach my $sym (sort keys %$conf) {
    my $ref = $conf->{$sym};
    $keys .= "<b>Key #$sym:</b> <input type='text' value='$ref' readonly><br/>";
  }
  my $HTML=<<HTML;
        <div>
        <h2>Backup Codes</h2>
        $keys	
        </div>
	<form method="POST">
		<input class='input-button' type="submit" name="resetbackupcodes" value="Reset backup codes">
	</form>

HTML
  print $HTML;

}

sub TwoStepAuth_show_help {
my $HTML=<<HTML;
	<div>
	<h2>Help</h2>
	<p><b>Important:</b> Before enabling take note of the one time recover codes, print them off and put them somewhere safe. If you ever use a code it will cause them all to be reset</p>
	<p>Scan the QR code with your mobile phone's TOTP (Timed-based One Time Password) application, Google Authenticator is recommended. If you reset the salt you will need to rescan the QR.</p>
        <p>Enable the feature with the button, your account is now protected.</p>
	<p>When prompted use the code displayed on your mobile phone screen to log into cPanel securely.</p>
	</div>
HTML
print $HTML;
}

sub TwoStepAuth_qr_text {
      return if !Cpanel::hasfeature('twostepauth');

      my $config = Cpanel::TwoStepAuth::Utils::load_Config($users_dir . 'conf');
      my $hash = md5_hex($config->{'salt'} . $Cpanel::user);
      my $hostname = Cpanel::Hostname::gethostname();
      my $cmd = "/usr/local/cpanel/base/3rdparty/twostepauth/gauth.php -c=qr_text -t='cPanel $Cpanel::user' -i='$hostname' -p=$hash";
      my $out = `$cmd`;
      print $out;
      return;
}

sub TwoStepAuth_registration_qr {
      return if !Cpanel::hasfeature('twostepauth');
      my $config = Cpanel::TwoStepAuth::Utils::load_Config($users_dir . 'conf');
      my $hash = md5_hex($config->{'salt'} . $Cpanel::user);
      my $hostname = Cpanel::Hostname::gethostname();
      my $cmd = "/usr/local/cpanel/base/3rdparty/twostepauth/gauth.php -c=qr -t='cPanel $Cpanel::user' -i='$hostname' -p=$hash";
      my $out = `$cmd`;
      print "<img src='$out'>";
      return;
}

sub _active {
  my ($value) = @_;

  my $settings_file = $users_dir . 'conf';

  if (-e $settings_file ) {
    my $conf = Cpanel::TwoStepAuth::Utils::load_Config($settings_file);

    if (defined $value) {
      $conf->{'salt'} = ($conf->{'salt'} ? $conf->{'salt'}:Cpanel::Rand::getranddata(32));
      $conf->{'enabled'} = $value;
      Cpanel::TwoStepAuth::Utils::flushConfig($conf, $settings_file);
    }
    return $conf->{'enabled'};
  } 
  return 0;
}
