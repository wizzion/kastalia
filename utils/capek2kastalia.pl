#chatGPT2kastalia
use JSON::XS;
use Encode qw/encode/;
use LWP::Simple;
use DBD::Pg;
use Pg::hstore qw/hstore_encode/;
use warnings;
use strict;

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
		$sth->execute($knot_name, $knot_content, Pg::hstore::encode($attributes));
		#$sth->execute($knot_name, $knot_content, $attributes);
	} else {
		my $sth=$dbh->prepare('insert into knots (knot_name,knot_content) values (?,?)');
		$sth->execute($knot_name, $knot_content);
	
	}
	my $knot_id = $dbh->last_insert_id(undef,undef,undef,undef,{sequence=>'knots_knot_id_seq'});
	#addAttribute($knot_id,'epoch',time);
	print "new knot is $knot_id \n";
	return $knot_id;
}

use Pg::hstore qw/hstore_encode/;
sub addAttribute {
	(my $knot_id, my $a_name, my $a_value) = (@_);
	my $sth2 = $dbh->prepare("update knots set attributes=attributes || ? where knot_id=?");
	$sth2->execute(hstore_encode({$a_name=>$a_value}),$knot_id);
} 

my $i=1;
for (<>) {
	my $filename=my $knot_content=$_;
	$knot_content=~s/_/ /g;
	my %attributes=('seed','1003','styles','anime', 'sampler_index','DDIM', 'steps','30', 'enable_hr','True', 'hr_scale','2', 'hr_upscaler','webuiapi.HiResUpscaler.Latent', 'hr_second_pass_steps','20', 'hr_resize_x','512', 'hr_resize_y','512', 'denoising_strength','0.4','model','https://udk.ai/models/stable_diffusion/ema0.ckpt','img_url','/capek/'.$filename,'licence','CC BY-NC-SA');
	my $knot_id=addKnot("Stable Diffusion Automatic1111 WebUI API meets Simple-Matrix-Bot-Lib test $i",$knot_content,\%attributes);
	addBound(7,'is_parent',$knot_id);
	addBound(9,'created_by',$knot_id);
	$i++;
}

