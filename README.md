cpanel_addon-twostepauth
========================

Allows two step authentication via Integrate Google Authenticator (TOTP) for cPanel accounts

Install:

Ensure YAML::Syck available

 * perl -MCPAN -e shell
 * cpan> install YAML::Syck

* cd /tmp/
* git clone https://git hub.com/steadramon/cpanel_addon-twostepauth.git
* cd cpanel_addon-twostepauth
* ./install
* Enable Security Policy in WHM » Home » Security Center » Configure Security Policies
* Enable plugin at WHM » Home » Plugins » cPanel Two Step Auth
