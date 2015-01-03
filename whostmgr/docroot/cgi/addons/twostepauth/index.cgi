#!/usr/local/cpanel/3rdparty/bin/perl
# start main
#WHMADDON:addonupdates:cPanel Two Step Auth
use CGI::Carp qw(fatalsToBrowser);
use File::Path;
use File::Copy;
use Fcntl qw(:DEFAULT :flock);
use IPC::Open3;

use lib '/usr/local/cpanel', '/usr/local/cpanel/whostmgr/docroot/cgi';
use whmlib;

use Cpanel::cPanelFunctions ();
use Cpanel::Form			();
use Cpanel::Config          ();
use Cpanel::Version         ();
use Whostmgr::ACLS			();
use Cpanel::TwoStepAuth::Utils();

Whostmgr::ACLS::init_acls();

my $CP_CONF_FILE = '/usr/local/cpanel/base/3rdparty/twostepauth/twostepauth.conf';

my $cp_config = Cpanel::TwoStepAuth::Utils::load_Config($CP_CONF_FILE);

$| = 1;
print "Content-type: text/html\r\n\r\n";

if (!Whostmgr::ACLS::hasroot()) {
	print "You do not have access to Two Step Auth Admin.\n";
	exit();
}

if (-e "/usr/local/cpanel/bin/register_appconfig") {
	$script = "index.cgi";
	$versionfile = "/usr/local/cpanel/base/3rdparty/twostepauth/version.txt";
} else {
        exit();
}

eval ('use Cpanel::Rlimit			();');
unless ($@) {Cpanel::Rlimit::set_rlimit_to_infinity()}

open (IN, "<$versionfile") or die $!;
$myv = <IN>;
close (IN);
chomp $myv;

defheader("cPanel Two Step Auth - twostepauth v$myv" );

%FORM = Cpanel::Form::parseform();

if ($FORM{action} eq "upgrade") {
	print "Retrieving new twostepauth package...\n";
	print "<pre style='font-family: Courier New, Courier; font-size: 12px'>";
	system ("rm -Rfv /usr/src/cpanel_addon-twostepauth; cd /usr/src ; git clone https://github.com/steadramon/cpanel_addon-twostepauth.git 2>&1");
	print "</pre>";
	if (-e "/usr/src/cpanel_addon-twostepauth/base/3rdparty/twostepauth/version.txt") {
		print "Installing new version of twostepauth";
		print "<pre style='font-family: Courier New, Courier; font-size: 12px'>";
		system ("cd /usr/src/cpanel_addon-twostepauth ; ./install 2>&1");
		print "</pre>";
		print "Tidying up...\n";
		print "<pre style='font-family: Courier New, Courier; font-size: 12px'>";
		system ("rm -Rfv /usr/src/cpanel_addon-twostepauth");
		print "</pre>";
		print "...All done.\n";
	}

	open (IN, "<$versionfile") or die $!;
	$myv = <IN>;
	close (IN);
	chomp $myv;

	print "<p align='center'><form action='$script' method='post'><input type='submit' class='input' value='Return'></form></p>\n";
}
elsif ($FORM{action} eq "users") {
	&manage_users;
}
elsif ($FORM{action} eq "user_switch") {
	&user_switch;
}
elsif ($FORM{action} eq "config") {
	&tsaconfig;
}
else {
	&index_page;
}
  print "<p>&copy;2015 <a href='https://github.com/steadramon/cpanel_addon-twostepauth/' target='_blank'>steadramon</a></p>\n";
  print "<pre style='font-family: Courier New, Courier; font-size: 12px'>twostepauth v$myv</pre>";
# end main

###############################################################################
sub index_page {
	my ($status, $text) = &urlget("https://raw.githubusercontent.com/steadramon/cpanel_addon-twostepauth/master/base/3rdparty/twostepauth/version.txt");
	my $actv = $text;
	chomp $actv;

	my $up = 0;
	my $upgrade = '';
	if ($actv ne "") {
		if ($actv =~ /^[\d\.]*$/) {
			if ($actv > $myv) {
				$upgrade = "<form action='$script' method='post'><td><input type='hidden' name='action' value='upgrade'><input type='submit' class='input' value='Upgrade TwoStepAuth'></td><td width='100%'><b>A new version of TwoStepAuth (v$actv) is available. Upgrading will retain your settings</td></form>\n";
			} else {
				$upgrade =  "<td colspan='2'>You appear to be running the latest version of twostepauth. An Upgrade button will appear here if a new version becomes available</td>\n";
			}
			$up = 1;
		}
	}
	unless ($up) {
		$upgrade = "<td colspan='2'>Failed to determine the latest version of twostepauth. An Upgrade button will appear here if new version is detected</td>\n";
	}

	
my $HTML=<<HTML;
<table width="95%" align="center" class="sortable">
	<tbody>
		<tr><th align="left" colspan="2">cPanel Two Step Auth Control <!--(<u><a href="index.cgi?action=help">Help</a></u>)--></th></tr>
		<tr class="tdshade1"><td><form method="post" action="index.cgi"><input type="hidden" value="config" name="action"><input type="submit" value="Config" class="input"></form></td><td width="100%">You can enable and configure Two Step Auth</td></tr>
		<tr class="tdshade2"><td><form method="post" action="index.cgi"><input type="hidden" value="users" name="action"><input type="submit" value="User Setup" class="input"></form></td><td width="100%">You can enable/disable for users</td></tr>
	</tbody>
</table>
<br><table width="95%" align="center" class="sortable">
	<tbody>
		<tr><th align="left" colspan="2">Upgrade</th></tr>
		<tr>$upgrade</tr>
	</tbody>
</table>
<br>
HTML
	print $HTML;

}

sub manage_users {
        my @users;
        opendir (DIR, "/var/cpanel/users") or die $!;
        while (my $user = readdir (DIR)) {
                if ($user =~ /^\./) {next}
                my (undef,undef,undef,undef,undef,undef,undef,$homedir,undef,undef) = getpwnam($user);
                $homedir =~ /(.*)/;
                $homedir = $1;
                if ($homedir eq "") {next}
                if (not -d "$homedir") {next}
                push (@users, $user);
        }
	closedir (DIR);
        @users = sort @users; 
        foreach my $user (@users) {
            my $active = active($user);
	    $info .= "<tr><td>$user</td><td>".( $active ? 'Active':'Inactive' )."</td><td><form method='POST'><input value='$user' type='hidden' name='userid'><input type='hidden' value='user_switch' name='action'><input type='submit' value='".( $active ? 'Deactivate':'Activate' )."'></form></td></tr>";
        }
my $HTML=<<HTML;
<table width="95%" align="center" class="sortable">
<tr>
<th>User</th>
<th>State</th>
<th>Action</th>
</tr>
$info
</table>
HTML

print $HTML;
  print "<p align='center'><form action='$script' method='post'><input type='submit' class='input' value='Return'></form></p>\n";
}

sub user_switch {
	my $user = $FORM{userid};
	my $active = active($user);
	if ($active) {
		active($user, 0);
	} else {
		active($user, 1);
	}
	&manage_users;	
}

sub active {
	my ($user, $value) = @_;

	($login,$pass,$uid,$gid) = getpwnam($user);
	my $homedir = ( Cpanel::PwCache::getpwuid($uid) )[7];
	$settings_file = $homedir.'/.twostepauth/conf';
	if (-e $settings_file ) {
		my $conf = Cpanel::TwoStepAuth::Utils::load_Config($settings_file);
		if (defined $value) {
			$conf->{'enabled'} = $value;
			Cpanel::TwoStepAuth::Utils::flushConfig($conf, $settings_file);
		}
		return $conf->{'enabled'};
  	}
  	return 0;
}
sub tsaconfig {
  my $enabled;
  my $disabled;
  my $save;

  if($FORM{'save'}) {
    my $enabled = ($FORM{'enabled'} == 1) ? 1:0;

    $cp_config->{'policy'} = $enabled;
    Cpanel::TwoStepAuth::Utils::flushConfig( $cp_config, $CP_CONF_FILE );
    $save = '<div id="alert_success"><div id="alert_img"></div>
             <div id="alert_content"><span class="message">Changes stored successfully</span></div></div>';
  }

  $enabled = ($cp_config->{'policy'}? 'checked':'');
  $disabled = ($cp_config->{'policy'}? '':'checked');

my $HTML=<<HTML;
<form method="POST" action='$script?action=config'>
<table width="95%" align="center" class="sortable">
	<tbody>
		<tr><th align="left" colspan="2">Configure Two Step Auth</th></tr>
		<tr class="tdshade1">
			<td width="70%" >Enabled?</td>
			<td width="30%">
				<input type="radio" name="enabled" value="0" id="tsadisable" $disabled>
				<label for="tsadisable">Disabled</label>
				<br>
				<input type="radio" name="enabled" id="tsaenable" value="1" $enabled>
				<label for="tsaenable">Enabled</label>
			</td>
		</tr>
		<tr><th colspan="2"><input type="submit" name="save" value="Save"></th></tr>
	</tbody>
</table>
</form>
HTML
  print $save;
  print $HTML;
  print "<p align='center'><form action='$script' method='post'><input type='submit' class='input' value='Return'></form></p>\n";
}

###############################################################################
# start printcmd
sub printcmd {
	my ($childin, $childout);
	my $pid = open3($childin, $childout, $childout, @_);
	while (<$childout>) {print $_}
	waitpid ($pid, 0);
}
# end printcmd
###############################################################################
# start splitlines
sub splitlines {
	my $line = shift;
	my $cnt = 0;
	my $newline;
	for (my $x = 0;$x < length($line) ;$x++) {
		if ($cnt > 120) {
			$cnt = 0;
			$newline .= "<WBR>";
		}
		my $letter = substr($line,$x,1);
		if ($letter =~ /\s/) {
			$cnt = 0;
		} else {
			$cnt++;
		}
		$newline .= $letter;
	}

	return $newline;
}
# end splitlines
###############################################################################

###############################################################################
# start urlget (v1.3)
sub urlget {
	my $url = shift;
	my $file = shift;
	my $status = 0;
	my $timeout = 1200;

	use LWP::UserAgent;
	my $ua = LWP::UserAgent->new;
	$ua->timeout(30);
	my $req = HTTP::Request->new(GET => $url);
	my $res;
	my $text;

	($status, $text) = eval {
		local $SIG{__DIE__} = undef;
		local $SIG{'ALRM'} = sub {die "Download timeout after $timeout seconds"};
		alarm($timeout);
		if ($file) {
			$|=1;
			my $expected_length;
			my $bytes_received = 0;
			my $per = 0;
			my $oldper = 0;
			open (OUT, ">$file\.tmp") or return (1, "Unable to open $file\.tmp: $!");
			binmode (OUT);
			print "...0\%\n";
			$res = $ua->request($req,
				sub {
				my($chunk, $res) = @_;
				$bytes_received += length($chunk);
				unless (defined $expected_length) {$expected_length = $res->content_length || 0}
				if ($expected_length) {
					my $per = int(100 * $bytes_received / $expected_length);
					if ((int($per / 5) == $per / 5) and ($per != $oldper)) {
						print "...$per\%\n";
						$oldper = $per;
					}
				} else {
					print ".";
				}
				print OUT $chunk;
			});
			close (OUT);
			print "\n";
		} else {
			$res = $ua->request($req);
		}
		alarm(0);
		if ($res->is_success) {
			if ($file) {
				rename ("$file\.tmp","$file") or return (1, "Unable to rename $file\.tmp to $file: $!");
				return (0, $file);
			} else {
				return (0, $res->content);
			}
		} else {
			return (1, "Unable to download: ".$res->message);
		}
	};
	alarm(0);
	if ($@) {
		return (1, $@);
	}
	if ($text) {
		return ($status,$text);
	} else {
		return (1, "Download timeout after $timeout seconds");
	}
}
# end urlget
###############################################################################

1;
