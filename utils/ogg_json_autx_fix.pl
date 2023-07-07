use strict;
use warnings;

binmode( STDIN,  ':utf8' );
binmode( STDOUT, ':utf8' );

use JSON::XS;
use DBD::Pg;
use Pg::hstore qw/hstore_encode/;
use Encode       qw( encode );
use String::ShellQuote qw( shell_quote );

my $dbh = DBI->connect("dbi:Pg:dbname=kastalia_db", '', '', {AutoCommit => 1});
my $sth=$dbh->prepare("select attributes->'voice' as voice, attributes->'zodiac' as zodiac, attributes->'motherlang' as motherlang, attributes->'consent' as consent, attributes->'gender' as gender,attributes->'age' as age,attributes->'autx_content' as autx_content,attributes->'ogg_url' as ogg_url from knots where attributes->'autx_content' is not null");
#my $sth=$dbh->prepare("select attributes->'voice' as voice, attributes->'zodiac' as zodiac, attributes->'motherlang' as motherlang, attributes->'consent' as consent, attributes->'gender' as gender,attributes->'age' as age,attributes->'autx_content' as autx_content,attributes->'ogg_url' as ogg_url from knots where knot_id=3407");

$sth->execute();
while (my $h=$sth->fetchrow_hashref()) {
	my $json_orig='['.$h->{'autx_content'}.']';
	$json_orig=~s/[^[:print:]]//g;
	my $json = encode('UTF-8', $json_orig); 
	my $json_out = eval { decode_json($json) };
	my $file= $h->{'ogg_url'};
	my $metadata='author={"voice":"'.$h->{'voice'}.',"zodiac:"'.$h->{'zodiac'}.'",age":"'.$h->{'age'}.'",gender:"'.$h->{'gender'}.'",consent":"'.$h->{'consent'}.'",motherlang":"'.$h->{'motherlang'}."\"}\ntext=".$json_orig;
	#$metadata=~s/'/\\'/g;
	my $cmd1 = shell_quote('echo', $metadata);

	if ($@)
	{
		    print STDERR "$file decode_json failed, invalid json. $metadata error:$@\n";
	}

	else {
		my $cmd="$cmd1 | ./opuscomment -R -w ../public$file";
		`$cmd`;
		print $cmd;
	}
}
