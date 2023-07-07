#Kastalia's first intersystem branch cloner
#authored by Daniel Hromada / wizzion.com
#when in public domain, mrGPL applies
#AE510114
use JSON::XS;
use Encode qw/encode/;
use LWP::Simple;
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




my $origin='https://kastalia.medienhaus.udk-berlin.de';
my $json_text = get($origin.'/view/'.$ARGV[0].'/branch3json');
print($json_text);
my $json_text='';
while(<>) {
	$json_text=$json_text.$_;
}
my $json_bytes = encode('UTF-8', $json_text);
print "LALAL";
print($json_bytes);

sub branch2lists {
	my $rh_old_knots=shift;
	my $ra_new_knots=shift;
	my $ra_new_bounds=shift;
	#construct knot list
	push(@$ra_new_knots,{'knot_id'=>$rh_old_knots->{'knot_id'},'knot_name'=>$rh_old_knots->{'knot_name'},'knot_content'=>$rh_old_knots->{'knot_content'},'attributes'=>$rh_old_knots->{'attributes'}});
	#construct bound list
	foreach my $o (@{$rh_old_knots->{'objects'}}) {
		push(@$ra_new_bounds,$o);
	}
	foreach my $child  (@{$rh_old_knots->{'children'}}) {
		#oh recursion!
		branch2lists($child,$ra_new_knots,$ra_new_bounds);
	}
}

my @knots;
my @bounds;

branch2lists(decode_json $json_bytes,\@knots,\@bounds);

my %old2new;
my %old_preceded;
my %old_followed;

for my $knot (@knots) {
	my $knot_name=$knot->{'knot_name'};
	my $knot_content=$knot->{'knot_content'};
	my $old_knot_id=$knot->{'knot_id'};
	my $attributes=$knot->{'attributes'};

	$attributes='"origin"=>"'.$origin.'",'.$attributes;
	$attributes='"origin_id"=>"'.$old_knot_id.'",'.$attributes;
	$attributes=~s/"ogg/"ogg_url/g;
	$attributes=~s/_url"=>"/_url"=>"$origin/g;
	if ($attributes=~/preceded_by\"=>\"(\d+)\"/) {
		$old_preceded{$old_knot_id}=$1;
		print("YO".$old_preceded{$old_knot_id});
	}
	if ($attributes=~/followed_by\"=>\"(\d+)\"/) {
		$old_followed{$old_knot_id}=$1;
		print("HO".$old_preceded{$old_knot_id});
	}
	my $new_id=addKnot($knot_name,$knot_content,$attributes);
	print("$knot_name injected \n");
	$old2new{$old_knot_id}=$new_id;
}

for my $bound (@bounds) {
	my $obj=$old2new{$bound->{'obj'}};
	if (!$obj) {
		my $sth=$dbh->prepare("select knot_id from knots where attributes->'origin'=? and attributes->'origin_id'=?");
		$sth->execute($origin,$bound->{'obj'});
		my $h=$sth->fetchrow_hashref();
		$obj=$h->{'knot_id'} if $h;
	}
	my $sub=$old2new{$bound->{'sub'}};
	if (!$sub) {
		my $sth=$dbh->prepare("select knot_id from knots where attributes->'origin'=? and attributes->'origin_id'=?");
		$sth->execute($origin,$bound->{'sub'});
		my $h=$sth->fetchrow_hashref();
		$sub=$h->{'knot_id'} if $h;
	}
	if (!$obj or !$sub) {
		print "MERDE obj $obj sub $sub \n";
		next;
	}
	my $ord=$bound->{'ord'};
	my $predicate=$bound->{'predicate'};
	addBound($sub,$predicate,$obj,$ord);
}

for my $old (keys %old_preceded) {
	addAttribute($old2new{$old},'preceded_by',$old2new{$old_preceded{$old}});
}

for my $old (keys %old_followed) {
	addAttribute($old2new{$old},'followed_by',$old2new{$old_followed{$old}});
}
