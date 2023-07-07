use strict;
use warnings;

binmode( STDIN,  ':utf8' );
binmode( STDOUT, ':utf8' );

die "You need to specify folio_image, parent_id as input parameters" if !$ARGV[1];

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



use Text::CSV qw(csv);
use Data::Dumper;
my $page_id=$ARGV[0];
my $tsv=`tesseract palope3/$page_id.png stdout -l deu tsv`;
my $aoh = csv (in => \$tsv, headers => "auto",  sep_char=> "\t", escape_char => "\\" );
my $line_count=0;
my $json="";
my $fulltext="";


for my $row (@$aoh) {
        my $text=$row->{'text'};
	#$text=s/\\,\\\\/g;
	#$text=~s/'"','\\"'/g;/
        if ($text) {
		$json = $json . '{"id":"w_KNOTID_'.$line_count.'","ocr":"'.$text.'","left":'.$row->{left}.',"top":'.$row->{top}.',"width":'.$row->{'width'}.',"height":'.$row->{'height'}.'},';
	}
	$line_count += 1;
	$fulltext=$fulltext." ".$text;
}
print $json;
my $knot_id=addKnot($page_id,$fulltext);
print $knot_id;
addBound($ARGV[1],'is_parent',$knot_id);
$json=~s/w_KNOTID/w_$knot_id/g;
addAttribute($knot_id,'ocr',$json);
addAttribute($knot_id,'img_url','/data/img/'.$page_id.'.png');

print($json);
