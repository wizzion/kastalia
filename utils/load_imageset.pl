use strict;
use warnings;

binmode( STDIN,  ':utf8' );
binmode( STDOUT, ':utf8' );

die "You need to specify parent_id input parameter" if !$ARGV[0];

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

sub get_first_knot_with_name {
	my $knot_name = shift;
	#my $sth=database('knots')->prepare("select * from knots where knot_name like ? order by knot_id limit 1");
	my $sth=$dbh->prepare("select * from knots where knot_name = ? order by knot_id limit 1");
	#debug "select * from knots where knot_name = '$knot_name' order by knot_id limit 1";
	#$sth->execute('%'.$knot_name.'%');
	$sth->execute($knot_name);
	#return $sth->fetchrow_hashref();
	my $aref=$sth->fetchall_arrayref({});
	use Data::Dumper;
	#debug Dumper($aref->[0]);
	return attach_attributes($aref)->[0];
}
sub attach_attributes {
	my $aref=shift;
	for my $item (@$aref) {
		my $attributes = Pg::hstore::decode($item->{attributes});
		for my $a_k (keys %$attributes) {
			if ($a_k eq 'epoch') {
				my @t=localtime($attributes->{$a_k});
				#debug "TIME $item->{$a_k} @t";
				#my $year=$t[5]-70;
				#my $suffix=strftime('%m%d',@t);
				#$item->{'ae_epoch'}='AE'.$year.$suffix;
				#$item->{'date'}=strftime('%d.%m.%Y',@t);
			}
			#else {
				$item->{$a_k}=$attributes->{$a_k};
			#}
			#debug "ATTACHIN $a_k".$item->{$a_k};
		}
	}
	#debug $aref;
	return $aref;
}


use Pg::hstore qw/hstore_encode/;
sub addAttribute {
	(my $knot_id, my $a_name, my $a_value) = (@_);
	my $sth2 = $dbh->prepare("update knots set attributes=attributes || ? where knot_id=?");
	$sth2->execute(hstore_encode({$a_name=>$a_value}),$knot_id);
} 



use Text::CSV qw(csv);
use Data::Dumper;
my $folder=$ARGV[0];
my @files=<$folder*.png>;
my $ord=scalar(@files);
for my $file (@files) {
	chomp $file;
	#my $img_desc=`identify $file`;
	my $token=$file;
	$token=~s/\.png//;
	$token=~s/$folder//;
	my $knot_name="Wort::$token";
	my $knot=get_first_knot_with_name($knot_name);
	my $knot_id=$knot->{'knot_id'};
	if (!$knot_id) {
		$knot_id=addKnot($knot_name,$token);
		addBound($ARGV[1],'is_parent',$knot_id,1);
	}
	my $illustration_id=addKnot("Illustration::$token","Illustration of $token by Carlotte Klee");
	addBound($illustration_id,'illustrates',$knot_id,2);
	addBound("18298",'is_parent',$illustration_id);
	addAttribute($illustration_id,'licence',"CC BY NC-SA");
	addAttribute($illustration_id,'author',"Carlotta Klee");
	addAttribute($illustration_id,'img_url',"/klee/$token".".png");
	#print($token."LAL".$knot->{'knot_id'}."\n");
	#addBound($ARGV[0],'is_parent',$knot_id,$ord);
	#$json=~s/w_KNOTID/w_$knot_id/g;
	#addAttribute($knot_id,'ocr',$json);
	#addAttribute($knot_id,'img_url','/data/img/'.$file);
	#print($json);
	#$ord--;
}
