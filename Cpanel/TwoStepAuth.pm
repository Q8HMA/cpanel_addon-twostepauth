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
my $settings_file = $users_dir . 'conf';
my $backup_codes = $users_dir . 'backups';
my $cp_config = Cpanel::TwoStepAuth::Utils::load_Config($CP_CONF_FILE);
my $bu_length = $cp_config->{'bu_length'} ? $cp_config->{'bu_length'}:16; 
my $bu_number = $cp_config->{'bu_number'} ? $cp_config->{'bu_number'}:5;

sub TwoStepAuth_init {
  return if !Cpanel::hasfeature('twostepauth');

  if(!-e $users_dir) {
	Cpanel::SafeDir::safemkdir( $users_dir, '0700' );
  }
  if(!-e $settings_file) {
      _setup_settings_file();
  }

  if(!-e $backup_codes) {
    _setup_backupcodes();
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

    _setup_settings_file();

    return;    
}

sub TwoStepAuth_resetbackupcodes {
    return if !Cpanel::hasfeature('twostepauth');

     _setup_backupcodes();

    return;    
}

sub TwoStepAuth_system_enabled {
  return if !Cpanel::hasfeature('twostepauth');

  my $locale = Cpanel::Locale->get_handle();
  if ($cp_config->{'policy'} == 1) {
    print 1;
    return;
  }

}

sub TwoStepAuth_user_enabled {
    if(_active()) {
        print 1;
        return;
    }
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

sub api2_backupcodes {
    my $conf = Cpanel::TwoStepAuth::Utils::load_Config($backup_codes);

    my @RSD;

    foreach my $sym (sort keys %$conf) {
        if ($sym =~ /^\d+$/) {
            my $ref = $conf->{$sym};
	    my $state = ($conf->{$sym.'-used'}) ? '1':'0';
            push( @RSD, { 'key' => $ref, 'state' => $state } );
        }
    }
    return @RSD;
}

sub _setup_settings_file {
    my $conf = { 'enabled' => 0, 'salt' => Cpanel::Rand::getranddata(32) };
    Cpanel::TwoStepAuth::Utils::flushConfig($conf, $settings_file);
    chmod 0600, $settings_file;
}

sub _setup_backupcodes {
    my $conf = {};
    for (my $i = 1; $i <= $bu_number; $i += 1) {
        $conf->{$i} = Cpanel::Rand::getranddata($bu_length);
    }
    Cpanel::TwoStepAuth::Utils::flushConfig($conf, $backup_codes);
    chmod 0600, $backup_codes;
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

sub api2 {
    my $func = shift;

    my %API;
    $API{'backupcodes'} = {};

    return $API{$func};
}

1;
