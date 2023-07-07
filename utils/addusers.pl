use YAML::Tiny;
my $yaml = YAML::Tiny->read( './project_config.yml' );
my $appname = $yaml->[0]->{appname};
my $ldap_base  = $yaml->[0]->{ldap_base};
my $ldap_pass  = $yaml->[0]->{ldap_pass};
my $ldap_ou  = $yaml->[0]->{ldap_ou};
my $ldap_bind_cn  = $yaml->[0]->{ldap_bind_cn};
my $ldap_host  = $yaml->[0]->{ldap_host};
my $mail_user  = $yaml->[0]->{mail_user};
my $mail_pwd  = $yaml->[0]->{mail_pwd};
my $mail_smtp_host  = $yaml->[0]->{mail_smtp_host};
my $mail_smtp_port  = $yaml->[0]->{mail_smtp_port};
my $creator="sysop";
my $project_name="Projekt X";
my $project_domain="";

use utf8;
use open qw(:std :utf8);
use Net::SMTP;
use Email::Stuffer;
use Net::LDAP;
use Data::Dumper;

my $ldap=Net::LDAP->new($ldap_host);
my $mesg = $ldap->bind("$ldap_bind_cn,$ldap_base",password => $ldap_pass ,version => 3 ); 
print ($mesg);

sub mail_send {
	 (my $mail_to,my $mail_msg)=@_;
	 my $mailer0 = new Net::SMTP(
		$mail_smtp_host,
		Hello   =>      $mail_smtp_host,
		Port    =>      $mail_smtp_port, #redundant
	);
	#$mailer0->debug(1);
	$mailer0->auth($mail_user,$mail_pwd);
	$mailer0->mail($mail_user);
	if ($mailer0->to($mail_to)) {
	 $mailer0->data();
	 #$mailer0->datasend("From: $mail_user\n");
	 #$mailer0->datasend("To: $mail_to\n");
	 #$mailer0->datasend("Content-Type: text/html; charset=UTF-8\n");
	 $mailer0->datasend("$mail_msg\n");
	 $mailer0->dataend();
	 print "MSG registration mail sent to $mail_to";
	} else {
	 print "Error: ", $mailer0->message();
	}
	 $mailer0->quit;
}


sub account_exists {
	my $account = shift @_;
	#my $ldap = shift @_;
	my $result = $ldap->search ( base    => config->{ldap_base},scope   => "sub",filter  => "cn=$account");
	#print Dumper($result);
	if ($result->entries) {
		print("$account is already registered. Please change name or surname.");
		return 1;
	}
	return 0;
}

sub create_account {
	my $firstname=shift;
	my $surname=shift;
	my $account=shift;
	my $email=shift;
	#print "creating $account for $firstname $surname\n";

	#print(Dumper($ldap));
	#if (!account_exists($account)) {
		print("creating cn=$account,$ldap_ou");
		my $result = $ldap->add ("cn=$account,ou=$ldap_ou,$ldap_base", attrs => [objectClass=>'inetOrgPerson',mail=>$email,givenName=>$firstname,sn=>$surname,uid=>$account,cn=>$account] );
		print(Dumper($result));
		if ($result->{'resultCode'}==68) {
			print "\nWARN $account exists, switching to password update modus\n";
		} elsif ($result->{'resultCode'}) {
			print "\nERROR creating $account\n";
			print(Dumper($mesg));
			return 0;
		}

		use Crypt::YAPassGen;
		my $passgen=Crypt::YAPassGen->new(length=>9);
		my $password=$passgen->generate();

		#set LDAP password
		use Net::LDAP::Extension::SetPassword;
		$mesg = $ldap->set_password(user=>"cn=$account,ou=$ldap_ou,$ldap_base", newpasswd => $password );

		#my $credentials="\n\nlogin:$account\npassword:$password\n\n";
		#print $credentials;
		if (!$mesg->{'resultCode'}) {
			print "$account $password\n";
			return $password;
		} else {
			print "\nERROR updating password for $account\n";
			print(Dumper($mesg));
			return 0;
		}
		#}
}

while(<>) {
	chomp;
	(my $firstname,my $surname,my $email)=split(/;/);

	my $account=lc "$firstname-$surname";
	#matrix does not support diacritics in user IDs, c.f. https://matrix.org/docs/spec/appendices#identifier-grammar
	$account=~s/ä/ae/g;
	$account=~s/ö/oe/g;
	$account=~s/ü/ue/g;
	$account=~s/ß/ss/g;
	$account=~s/ß/ss/g;

	my $password=create_account($firstname,$surname,$account,$email);

	if ($password) {

my $body=<<"EOM";
Liebe/r $firstname $surname!

beim $project_name werden wir vorrangig mit zwei Online-Tools arbeiten: BigBlueButton für Videokonferenzen und Matrix zum Chatten sowie dem Austausch kleiner Dateien.

Um den Chat nutzen zu können, musst du dich mit deinen persönlichen Zugangsdaten einloggen. Diese sind wie folgt:

Benutzername: $account
Passwort: $password

Um den Matrix-Chat mit dem Mobiltelefon nutzen zu können, empfehlen wir die App »Element« zu installieren. Diese findest du im App-Store oder im Google Play Store. Achte darauf, dass folgender Homeserver bei der Anmeldung in der Element-App ausgewiesen ist: paf-campus.de

Der Chat ist auch via Browser erreichbar unter: https://chat.$project_domain

Unter folgendem Link werden zeitnah einige technische Informationen bezüglich der Nutzung von BigBlueButton und Matrix zu finden sein:
https://paf-campus.de/howtos/howtoBBBandMatrix.pdf

Wichtig: Bitte logge dich bis spätestens Freitagabend, den 07.05.2021 bei Matrix ein, damit die Leiter:innen deines Workshops dich rechtzeitig zu den jeweiligen Workshopräumen hinzufügen können.

Im Falle von Problemen beim Einloggen, die selbstständig nicht gelöst werden können, kontaktiere bitte den Support unter: pafsupport\@wizzion.com
Wir freuen uns auf den PAF Campus mit dir!

——

Dear $firstname $surname!

At the $project_name, we will primarily work with two online tools: BigBlueButton for video conferencing and Matrix for chatting and exchanging files.

In order to use the Matrix chat tool, you have to log in with your personal access data as follows:

Accountname: $account
Password: $password

With this access data you can log in at https://chat.$project_domain

In order to be able to use the matrix chat with your mobile phone, we recommend installing the App »Element«. You can find this in the App Store or in the Google Play Store.

Please note that following homeserver has to be selected in the Element-App: paf-campus.de

The following link will serve technical informations and instructions regarding the usage of BigBlueButton and Matrix:
https://paf-campus.de/howtos/howtoBBBandMatrix.pdf

Important: Please log in to Matrix by Friday evening, May 7th, 2021 at the latest so that the leaders of your workshop can add you to the respective workshop rooms in due time.

In case of urgent troubles logging in into our systems please reach out to: pafsupport\@wizzion.com

We are looking forward to the PAF campus with you!

PAF technical support / wizzion.com UG

EOM

	$msg=Email::Stuffer->from($mail_user)->to($email)->text_body($body)->subject("$ldap_ou Zugangs für $firstname $surname")->as_string();
	#mail_send($email,$msg);
	}
}
