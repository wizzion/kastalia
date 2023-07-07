use strict;
use warnings;

binmode( STDIN,  ':utf8' );
binmode( STDOUT, ':utf8' );

die "You need to specify knot_id as input parameters" if !$ARGV[0];

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


sub addKnot {
	(my $knot_name, my $knot_content, my $attributes) = (@_);
	if ($attributes) {
		my $sth=$dbh->prepare('insert into knots (knot_name,knot_content,attributes) values (?,?,?)');
		#$sth->execute($knot_name, $knot_content, Pg::hstore::encode($attributes));
		$sth->execute($knot_name, $knot_content, $attributes);
	} else {
		my $sth=$dbh->prepare('insert into knots (knot_name,knot_content) values (?,?)');
		$sth->execute($knot_name, $knot_content);
	
	}
	my $knot_id = $dbh->last_insert_id(undef,undef,undef,undef,{sequence=>'knots_knot_id_seq'});
	#addAttribute($knot_id,'epoch',time);
	print "new knot is $knot_id";
	return $knot_id;
}

use Pg::hstore qw/hstore_encode/;
sub addAttribute {
	(my $knot_id, my $a_name, my $a_value) = (@_);
	my $sth2 = $dbh->prepare("update knots set attributes=attributes || ? where knot_id=?");
	$sth2->execute(hstore_encode({$a_name=>$a_value}),$knot_id);
} 

my $knot_id=$ARGV[0];

my $s=$dbh->prepare("select knot_name from knots where knot_id=?");
$s->execute($knot_id);
my $knot_name=$s->fetchrow_hashref()->{'knot_name'};

#my $sth=$dbh->prepare("select bound_creator,count(distinct obj) as c from bounds where sub=? and predicate='contains' group by bound_creator order by c asc");
my $sth=$dbh->prepare("select creator_bound.sub as creator,count(distinct bounds.obj) as c from bounds left join bounds as creator_bound on bounds.obj=creator_bound.obj and creator_bound.predicate='created_by' where bounds.sub=? and bounds.predicate='contains' group by creator order by c");
$sth->execute($knot_id);

my $session_id;
while (my $h=$sth->fetchrow_hashref()) {
	my $creator=$h->{'creator'};
	print("getting voice for $creator");
	next if !$creator;
	my $s=$dbh->prepare("select attributes->'voice' as voice from knots where knot_id=?");
	$s->execute($creator);
	my $voice=$s->fetchrow_hashref()->{'voice'};
	$session_id=addKnot("$knot_name++$voice","");
	addBound($knot_id,'has_session',$session_id);
	my $sth2=$dbh->prepare("update bounds set sub=? where bound_id in (select bounds.bound_id from bounds left join bounds as cb on bounds.obj=cb.obj and cb.predicate='created_by' where bounds.sub=? and bounds.predicate='contains' and cb.sub=?)");
	$sth2->execute($session_id,$knot_id,$creator);
	addAttribute($session_id,'template','play');
}
addAttribute($knot_id,'exemplar_session',$session_id);
