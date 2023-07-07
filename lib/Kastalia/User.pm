#Licenced under WPL
#Licensor: wizzion.com UG (haftungsbeschränkt)
package Kastalia::User;
#use Dancer2::Plugin::Database;
#use Net::SMTP::TLS;
#use JSON::XS;
our $VERSION = '0.1';

use Dancer2 appname => 'Kastalia::Main'; #appname important to interconnect modules!

my $account_admins=config->{account_admins};
#my $ldp_heslo=config->{ldap_pass};
#my $ldp_base=config->{ldap_base};
#my $ldp_ou=config->{ldap_ou};
#my $ldp_cn=config->{ldap_bind_cn};
#my $ldp_domain=config->{ldap_domain};


sub valid_creator {
	 my $creator_mail=shift @_;
	 
	 if ($creator_mail !~ /($account_admins)/) {
		debug "SECWARN User::valid_creator $creator_mail unknown";
		Kastalia::Main::rdrct('/user_constructor','',"You are not (yet) allowed to invite people. Specify a valid registrator account or ask Your colleagues (administrator has been already notified).");
	}
	return true;
}

sub account_exists {
	my $account = shift @_;
	my $ldap = shift @_;
	my $result = $ldap->search ( base    => config->{ldap_base},scope   => "sub",filter  => "cn=$account");
	if ($result->entries) {
		return true;
		#Kastalia::Main::rdrct('/user_constructor','',"$account is already registered. Please change name or surname.");
	}
	return false;
}

get qr{/user_constructor/?} => sub {
	debug 'USER'.session 'user';
	debug session;
	template 'user_constructor',{'err'=>(session 'err'),'registrar_login'=> (session 'user')};
};

post qr{/newpwd} => sub {
	my $ldap_ou=config->{ldap_ou};
	if (param 'ou') {
		$ldap_ou=param 'ou';
		debug "OU $ldap_ou"; 
	}
	use Net::LDAP;
	my $ldap=Net::LDAP->new('127.0.0.1');
	#my $mesg = $ldap->bind(config->{ldap_bind_cn}.','.config->{ldap_base},password => config->{ldap_pass} ,version => 3 ); 

	my $mesg = $ldap->bind("cn=".params->{login}.",ou=".params->{ou}.",".config->{ldap_base},password => params->{pwd});
	if ($mesg->code!=0) {
		my $err="Authentication failed. SysOp notified.";
		Kastalia::Main::rdrct('/newpwd','',"Authentication failed. SysOp notified.");
	}
       	 
		debug $mesg;
		#use Crypt::YAPassGen;
		#my $passgen=Crypt::YAPassGen->new(length=>9);
		#my $password=$passgen->generate();
		#set LDAP password
		use Net::LDAP::Extension::SetPassword;
		debug "cn=".params->{login}.",ou=$ldap_ou,".config->{ldap_base};
		my $new_pwd=param 'new_pwd';
		$mesg = $ldap->set_password(user=>"cn=".params->{login}.",ou=$ldap_ou,".config->{ldap_base}, newpasswd => $new_pwd );
		Kastalia::Main::rdrct('/newpwd',"Your password is now <b>$new_pwd</b>",'');
};

get qr{/newpwd/?} => sub {
	debug 'USER'.session 'user';
	debug session;
	template 'newpwd',{'err'=>(session 'err'),'msg'=>(session 'msg'),'registrar_login'=> (session 'user')};
};
get qr{/user_resetpwd/?} => sub {
	debug 'USER'.session 'user';
	debug session;
	template 'user_resetpwd',{'err'=>(session 'err'),'msg'=>(session 'msg'),'registrar_login'=> (session 'user')};
};



post qr{/user_constructor/?} => sub {
	my $firstname=param "firstname";
	my $surname=param "surname";

	if (!$firstname or !$surname) {
		Kastalia::Main::rdrct('/user_constructor','',"Invalid firstname or surname.");
	}
	my $ldap_ou=config->{ldap_ou1};
	if (param 'ou') {
		$ldap_ou="ou=".param 'ou';
		#my $ldap_ou=config->{ldap_ou};
		#if (param 'ou') {
		#$ldap_ou=param 'ou';
		debug "OU $ldap_ou"; 
	}

	my $creator_mail=session('login');
	my $account=lc "$firstname-$surname";
	debug "SUBMIT $creator_mail wants to create $account";
	use Net::LDAP;
	my $ldap=Net::LDAP->new(config->{ldap_host});
	my $mesg = $ldap->bind(config->{ldap_bind_cn}.','.config->{ldap_base},password => config->{ldap_pass} ,version => 3 ); 
	#my $mesg = $ldap->bind("cn=".params->{login}.",ou=".params->{ou},password => params->{pwd});
        debug $mesg;
	if (account_exists($account,$ldap)) {
		Kastalia::Main::rdrct('/user_constructor','',"$account is already registered. Please change name or surname.");
	}
	if (valid_creator($creator_mail)) {
		debug "creating cn=$account,$ldap_ou";
		my $result = $ldap->add ("cn=$account,$ldap_ou,".config->{ldap_base}, attrs => [objectClass=>'inetOrgPerson',mail=>$account."@".$ldap_ou,givenName=>$firstname,sn=>$surname,uid=>$account,cn=>$account] );
		use Crypt::YAPassGen;
		debug("cn=$account,$ldap_ou,".config->{ldap_base});
		debug $result;
		my $passgen=Crypt::YAPassGen->new(length=>9);
		my $password=$passgen->generate();
		#set LDAP password
		use Net::LDAP::Extension::SetPassword;
		$mesg = $ldap->set_password(user=>"cn=$account,$ldap_ou,".config->{ldap_base}, newpasswd => $password );
		debug $mesg;
		debug "$account PASS $password";

		my $user_knot =  Kastalia::Main::addKnot($account,"Profile of $account\n",{"type"=>"human"});	
		Kastalia::Main::addBound(session('user_id'),'registered',$user_knot);
		Kastalia::Main::rdrct('/last',"Account registered, please transfer the sequence <b>$password</b> to $account by secure means.");
	}
};


post qr{/user_resetpwd/?} => sub {
	my $firstname=param "firstname";
	my $surname=param "surname";

	if (!$firstname or !$surname) {
		Kastalia::Main::rdrct('/user_resetpwd','',"Invalid firstname or surname.");
	}

	my $ldap_ou=config->{ldap_ou1};
	if (param 'ou') {
		$ldap_ou="ou=".param 'ou';
	}

	debug "OU $ldap_ou"; 
	my $creator_mail=session('login');
	my $account=lc "$firstname-$surname";
	debug "SUBMIT $creator_mail wants to updated password for $account";
	use Net::LDAP;
	my $ldap=Net::LDAP->new(config->{ldap_host});
	my $msg = $ldap->bind(config->{ldap_bind_cn}.','.config->{ldap_base},password => config->{ldap_pass} ,version => 3 ); 
	#my $mesg = $ldap->bind("cn=".params->{login}.",ou=".params->{ou},password => params->{pwd});
        debug $msg;
	if (valid_creator($creator_mail) && account_exists($account,$ldap)) {
		use Crypt::YAPassGen;
		my $passgen=Crypt::YAPassGen->new(length=>9);
		my $password=$passgen->generate();
		#set LDAP password
		use Net::LDAP::Extension::SetPassword;
		$msg = $ldap->set_password(user=>"cn=$account,$ldap_ou,".config->{ldap_base}, newpasswd => $password );
		debug $msg;
		debug "cn=$account,$ldap_ou,".config->{ldap_base}." PASS $password";
		Kastalia::Main::rdrct('/last',"Password changed, please transfer the sequence <b>$password</b> to $account by secure means.");
	}
};


true;
