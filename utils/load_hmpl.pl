use strict;
use warnings;

binmode( STDIN,  ':utf8' );
binmode( STDOUT, ':utf8' );

die "You need to specify creator_id parameter" if !$ARGV[0];
die "You need to specify container_id parameter" if !$ARGV[1];

my $creator_id=$ARGV[0];
my $container_id=$ARGV[1];

use DBD::Pg;
use Pg::hstore qw/hstore_encode/;
my $dbh = DBI->connect("dbi:Pg:dbname=kastalia_db", '', '', {AutoCommit => 1});

sub addBound {
	(my $sub, my $predicate, my $obj, my $ord) = @_;
	$ord=1 if (!$ord);
	my $sth=$dbh->prepare('INSERT INTO bounds(sub,predicate,obj,ord, bound_creator) VALUES (?,?,?,?,?)');						
	$sth->execute($sub,$predicate,$obj,$ord,'1');
	my $bound_id = $dbh->last_insert_id(undef,undef,undef,undef,{sequence=>'bound_id_seq'});
	#addZeitgeist(session('user_id'),'add_bound','post',{obj=>$obj, sub=>$sub, predicate=>$predicate,ord=>$ord,bound_id=>$bound_id});
}

sub get_first_knot_with_name {
	my $knot_name = shift;
	#my $sth=database('knots')->prepare("select * from knots where knot_name like ? order by knot_id limit 1");
	my $sth=$dbh->prepare("select * from knots where knot_name = ? order by knot_id limit 1");
	#debug "select * from knots where knot_name = '$knot_name' order by knot_id limit 1";
	$sth->execute($knot_name);
	#return $sth->fetchrow_hashref();
	my $aref=$sth->fetchall_arrayref({});
	use Data::Dumper;
	#debug Dumper($aref->[0]);
	#return attach_attributes($aref)->[0];
	return ($aref)->[0];
}

while(<STDIN>) {
	chomp;
	print;
	my $knot=get_first_knot_with_name($_);
	my $knot_id=$knot->{'knot_id'};
	addBound($container_id,'is_parent',$knot_id,1,$creator_id);
}
