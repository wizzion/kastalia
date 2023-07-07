use YAML::Tiny;
 
my $yaml = YAML::Tiny->read( '../config.yml' );
my $config = $yaml->[0];
my $appname = $yaml->[0]->{appname};
#my $ldap_base  = $yaml->[0]->{section}->{one};
my $ldap_base  = $yaml->[0]->{ldap_base};
print("$appname $ldap_base\n");
