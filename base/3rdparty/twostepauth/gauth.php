#!/usr/local/bin/php
<?php

require_once 'googleauth.php';

$shortopts  = "";
$shortopts .= "c:";
$shortopts .= "p:";  // Required value
$shortopts .= "v::";
$shortopts .= "t::"; // Optional value
$shortopts .= "i::";

$longopts  = array(
    "command:",     // Required value
    "privatekey:",     // Required value
    "title::",    // Optional value
    "issuer::",    // Optional value
);
$options = getopt($shortopts, $longopts);
$ga = new PHPGangsta_GoogleAuthenticator();
$options['p'] = $ga->setSecret($options['p']);
$options['p'] = str_replace('=', '', $options['p']);

switch ($options['c']) {
	case "qr":
		echo $ga->getQRCodeGoogleUrl($options['t'], $options['p']);
		break;
	case "verify":
		if ($ga->verifyCode($options['p'], $options['v'], 1)) {
			echo "true";
			exit(0);
		} else {
			echo "false";
			exit(255);
		}
		break;
	case "qr_text":
		if (array_key_exists('i', $options)) {
			echo $ga->getURI(rawurlencode($options['t']), $options['p'], $options['i']);
		} else {
			echo $ga->getURI(rawurlencode($options['t']), $options['p']);
		}
		break;
}
