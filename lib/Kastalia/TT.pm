#Licenced under WPL
#Licensor: wizzion.com UG (haftungsbeschränkt)
#Interface between Kastalia's Core and Template Toolkit.
#please ask DDH for consent if You want to use this code (notably the SQL queries) for own projects
use Template::Stash;
use Time::HiRes qw(time);

use POSIX qw(strftime);
use feature 'unicode_strings';
use utf8;

$Template::Stash::SCALAR_OPS->{process} = sub {
	my $token=shift;
	$token=~s/,$/''/g;
	$token=~s/\t/''/g;
	#$token=~s/(\w)\x{0259}(\w)?/<span style='color:orange'>\1e\2<\/span>/g;
	$token=~s/(\w)\x{0259}(\w)?/\1e\2/g;
	$token=~s/(\w)\x{0250}(\w)?/\1e\2/g;
	#$token=~s/_//g;
	#$token=~s/\/\1LAL\1/g;
	return $token;
};
$Template::Stash::SCALAR_OPS->{tokenize} = sub {
	my $sequence=shift;
	debug $token;
	my $tokens="";
	my $phrase="";
	$sequence=~s/_/ /g;
	while ($sequence=~/"w":"(.*?)"/g) {
		debug $1;
		if ($1 ne ' ') {
			$tokens.=$1."\n";
			#$phrase.=$1." ";
		}
	}
	return $tokens;
};
$Template::Stash::SCALAR_OPS->{get_session_key} = sub {
	my $k= shift;
	my $sd=session->data;
	#debug("GETTING SESSIONKEY ".$k." ".$sd->{$k});
	return $sd->{$k};
};	
$Template::Stash::SCALAR_OPS->{decode_html} = sub {
	use HTML::Entities;
	return decode_entities(shift);
};

$Template::Stash::SCALAR_OPS->{get_language_flag} = sub {
	my $langcode=shift;
	if ($langcode eq 'de') {
		return "🇩🇪";
	}
	if ($langcode eq 'en') {
		return "🇬🇧";
	}
	if ($langcode eq 'sk') {
		return "🇸🇰";
	}
	if ($langcode eq 'es') {
		return "🇪🇸";
	}


};

$Template::Stash::SCALAR_OPS->{get_words} = sub {
	use HTML::Entities;
	my $words=decode_entities(shift);
	#debug $words;
	my $i=0;
	my @a;
	$words=~s/[^[:print:]]+//g;
	$words=~s/([_^\W]+)/ \1 /g;
	$words=~s/"(.*?)"/ \x{201E} $1 \x{201C} /g;
	push @a,(split / +/,$words);
	
	return @a;
};

$Template::Stash::SCALAR_OPS->{get_words_tenfold} = sub {
	use HTML::Entities;
	my $words=decode_entities(shift);
	#debug $words;
	my $i=0;
	my @a;
	$words=~s/[^[:print:]]+//g;
	$words=~s/([_^\W]+)/ \1 /g;
	push @a,(split / +/,$words);
	#return grep {!/_/} @a;
	my @multiplied;
	for my $i (1..10) {
		foreach my $a (@a) {
			push(@multiplied,$a);
		}
	}
	return @multiplied;
};

$Template::Stash::SCALAR_OPS->{get_last_knots} = sub {
	my $limit=shift;
	my $q="select hstore_to_json(attributes) as attribute_json,knots.* from knots order by knot_id desc limit ?";
	my $sth=database('knots')->prepare($q);
	$sth->execute($limit);
	return attach_attributes $sth->fetchall_arrayref({});
};

$Template::Stash::SCALAR_OPS->{get_last_images} = sub {
	my $limit=shift;
	my $q="select hstore_to_json(attributes) as attribute_json,knots.* from knots where attributes->'img_url' IS NOT NULL order by knot_id desc limit ?";
	my $sth=database('knots')->prepare($q);
	$sth->execute($limit);
	return attach_attributes $sth->fetchall_arrayref({});
};


$Template::Stash::SCALAR_OPS->{get_last_related} = sub {
	my $limit=shift;
	my $q="select hstore_to_json(attributes) as attribute_json,knots.* from knots order by knot_id desc limit ?";
	my $sth=database('knots')->prepare($q);
	$sth->execute($limit);
	return attach_attributes $sth->fetchall_arrayref({});
};

$Template::Stash::SCALAR_OPS->{get_subtree_json} = sub {
	my $knot_id=shift;
	my $q="select jsonb_pretty(build_family) from build_family(?)";
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	return $sth->fetchrow_hashref;
};

$Template::Stash::SCALAR_OPS->{get_plain_knot} = sub {
	my $knot_id=shift;
	my $q="select * from knots where knot_id=?";
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
};

$Template::Stash::SCALAR_OPS->{get_foliae} = sub {
	my $knot_id=shift;
	my $q="select distinct on (parent_bound.sub) knots.knot_id as knot_id,knots.knot_name,knots.knot_content as content,knots.attributes as attributes,string_agg(distinct illustration.knot_name,'::') as illustration_names,string_agg(distinct illustration.attributes->'img_url','::') as illustration_urls from bounds as parent_bound left join knots on parent_bound.obj=knots.knot_id and parent_bound.predicate='contains' left join bounds on knots.knot_id=bounds.obj left join knots as illustration on bounds.sub=illustration.knot_id and bounds.predicate='illustrates' where parent_bound.sub=?  group by knots.knot_id,knots.knot_name,knots.knot_content,knots.attributes,parent_bound.ord order by parent_bound.ord asc,knots.knot_id;";
	debug $q;
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
};
$Template::Stash::SCALAR_OPS->{get_children_with_illustrations} = sub {
	my $knot_id=shift;
	#my $q="select knots.knot_id as knot_id,replace(substring(knots.knot_name from '(?<=\\+\\+)[^+]*\$'),'_','') as short_name,knots.knot_name,knots.knot_content as content,knots.attributes as attributes,string_agg(distinct illustration.knot_name,'::') as illustration_names,string_agg(distinct illustration.attributes->'img_url','::') as illustration_urls from bounds as parent_bound left join knots on parent_bound.obj=knots.knot_id and parent_bound.predicate='is_parent' left join bounds on knots.knot_id=bounds.obj left join knots as illustration on bounds.sub=illustration.knot_id and bounds.predicate='illustrates' where parent_bound.sub=?  group by knots.knot_id,knots.knot_name,knots.knot_content,knots.attributes,parent_bound.ord order by parent_bound.ord asc,knots.knot_id;";
	my $q="select knots.knot_id as knot_id,replace(substring(knots.knot_name from '(?<=\\+\\+)[^+]*\$'),'_','') as short_name,knots.knot_name,knots.knot_content as content,knots.attributes as attributes,json_agg(distinct illustration.knot_name) as illustration_names,json_agg(distinct illustration.attributes->'img_url') as illustration_urls,json_agg(distinct '/audio/'||audios.knot_id||'.ogg') as ogg_urls from bounds as parent_bound left join knots on parent_bound.obj=knots.knot_id and parent_bound.predicate='is_parent' left join bounds on knots.knot_id=bounds.obj left join knots as illustration on bounds.sub=illustration.knot_id and bounds.predicate='illustrates' left join bounds as audio_bounds on knots.knot_id=audio_bounds.sub and audio_bounds.predicate='is_uttered_as' left join knots as audios on audio_bounds.obj=audios.knot_id where parent_bound.sub=?  group by knots.knot_id,knots.knot_name,knots.knot_content,knots.attributes,parent_bound.ord order by parent_bound.ord asc,knots.knot_id;";
	#debug $q;
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
};


$Template::Stash::SCALAR_OPS->{get_illustration} = sub {
	my $knot_id=shift;
	#print "$knot_id START".time();
	my $q="select string_agg(distinct illustration.attributes->'img_url','::') as illustration_urls from bounds as parent_bound left join knots as parent on parent.knot_id=parent_bound.sub and (parent_bound.predicate='is_parent' or parent_bound.predicate='is_uttered_as') left join knots as child on child.knot_id=parent_bound.obj left join bounds as illustration_bound on parent.knot_id=illustration_bound.obj and illustration_bound.predicate='illustrates' left join knots as illustration on illustration.knot_id=illustration_bound.sub where parent_bound.obj=?";
	debug $q;
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	my $res=$sth->fetchrow_hashref();
	#debug "$knot_id END".time();
	return $res->{'illustration_urls'};
};

$Template::Stash::SCALAR_OPS->{get_bdlp} = sub {
	my $knot_id=shift;
	my $q="select members.knot_name from bounds left join knots as members on members.knot_id=bounds.sub where bounds.obj=? and bounds.predicate='is_member' order by random() limit 4";
	my $sth=database('knots')->prepare($q);
	#debug "select bounds.sub,recording.knot_content,string_agg(distinct recording.attributes->'ogg_url','::') as recording_urls from bounds left join knots as recording on recording.knot_id=bounds.obj where bounds.predicate='is_uttered_as' and bounds.sub in (select members.knot_id from bounds left join knots as members on members.knot_id=bounds.sub and bounds.predicate='is_member' where bounds.obj='knot_id') group by recording.knot_content,bounds.sub order by random() limit 4";
	$sth->execute($knot_id);
	#return attach_attributes $sth->fetchall_arrayref({});
	return $sth->fetchall_arrayref({});
};


$Template::Stash::SCALAR_OPS->{get_distinct_voices} = sub {
	my $knot_id=shift;
	#my $q="select recordings.attributes as attributes, recordings.knot_id as recording_id from bounds left join knots as recordings on bounds.obj=recordings.knot_id where predicate='is_uttered_as' and sub=?";
	my $q="select distinct on (recordings.attributes->'voice') recordings.attributes,recordings.knot_id as recording_id from bounds left join knots as recordings on bounds.obj=recordings.knot_id where predicate='is_uttered_as' and sub=?";
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
	#return $sth->fetchall_arrayref({});
};


$Template::Stash::SCALAR_OPS->{get_voices} = sub {
	my $knot_id=shift;
	#my $q="select recordings.attributes as attributes, recordings.knot_id as recording_id from bounds left join knots as recordings on bounds.obj=recordings.knot_id where predicate='is_uttered_as' and sub=?";
	my $q="select recordings.attributes,recordings.knot_id as recording_id,recordings.knot_name as recording_name from bounds left join knots as recordings on bounds.obj=recordings.knot_id where predicate='is_uttered_as' and sub=?";
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
	#return $sth->fetchall_arrayref({});
};

$Template::Stash::SCALAR_OPS->{get_newest_child } = sub {
	my $knot_id=shift;
	my $q="select children.*,bounds.*,extract(epoch from children.knot_created at time zone 'cest') as epoch from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and predicate='is_parent' order by knot_created desc limit 1";
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
};
$Template::Stash::SCALAR_OPS->{get_voicevariants} = sub {
	my $knot_id=shift;
	#my $q="select source,json_agg(e) from (select variant.attributes->'voice' as voice,variant.attributes->'autx_content' as autx_content, variant.attributes->'ogg_url' as ogg_url,variants.obj as variant_id,source.obj as source from bounds as source left join bounds as vorlage on source.obj=vorlage.obj and vorlage.predicate='is_uttered_as' left join bounds as variants on vorlage.sub=variants.sub and variants.predicate='is_uttered_as' left join knots as variant on variant.knot_id=variants.obj where source.sub=? and variant.attributes->'voice' is not null) e group by source";
	#where sub=? and predicate=\'is_parent\' and ord>0
	#my $q="select max(e.source_ord) as mes,vorlage.attributes->'difficulty' as difficulty,e.vorlage_id,vorlage.knot_content as vorlage_content,json_agg(e),count(e.voice) from (select distinct on (voice,source_ord,vorlage_id) vorlage.sub as vorlage_id,source.ord as source_ord,variant.attributes->'voice' as voice,variant.attributes->'autx_content' as autx_content,variants.obj as variant_id,source.obj as source from bounds as source left join knots as source_knot on source.sub=source_knot.knot_id left join bounds as vorlage on source.obj=vorlage.obj and vorlage.predicate='is_uttered_as' left join bounds as variants on vorlage.sub=variants.sub and variants.predicate='is_uttered_as' and variants.ord>0 left join knots as variant on variant.knot_id=variants.obj where source.sub=? and source.predicate='contains' and length(variant.attributes->'ogg_url')>0 and (variant.attributes->'voice' != source_knot.attributes->'voice-filter' or source_knot.attributes->'voice-filter' is null)) e left join knots as vorlage on vorlage.knot_id=e.vorlage_id group by e.vorlage_id,vorlage_content,difficulty order by difficulty,mes,vorlage_id desc";
	my $q="select distinct on (voice,source_ord,vorlage_id,source) source_knot.knot_content as vorlage_content,vorlage.sub as vorlage_id,source.ord as source_ord,variant.attributes->'voice' as voice,variant.attributes->'autx_content' as autx_content,variants.obj as variant_id,source.obj as source from bounds as source left join knots as source_knot on source.sub=source_knot.knot_id left join bounds as vorlage on source.obj=vorlage.obj and vorlage.predicate='is_uttered_as' left join bounds as variants on vorlage.sub=variants.sub and variants.predicate='is_uttered_as' and variants.ord>0 left join knots as variant on variant.knot_id=variants.obj where source.sub=? and source.predicate='contains' and length(variant.attributes->'ogg_url')>0 and (variant.attributes->'voice' != source_knot.attributes->'voice-filter' or source_knot.attributes->'voice-filter' is null) order by source_ord,source";
	my $sth=database('knots')->prepare($q);
	debug $q;
	$sth->execute($knot_id);
	return $sth->fetchall_arrayref({});
};

$Template::Stash::SCALAR_OPS->{get_arbre} = sub {
	my $knot_id=shift;
	my $q="with recursive tree as (
	  select obj,
		 sub,
		 predicate,
		 array[obj] as ancestor_ids,
		 array[knot_name] as ancestor_names
	  from bounds left join knots on obj=knot_id
	  where sub=? and ord>0
	  union all
	  select c.obj,
		 c.sub,
		 p.predicate,
		 p.ancestor_ids||c.obj,
		 p.ancestor_names || knot_name
	  from bounds c
	     join tree p
	      on c.sub = p.obj
	      and p.predicate='is_parent'
	     and c.obj <> ALL (p.ancestor_ids) -- avoids endless loops
	     left join knots on c.obj=knot_id and c.ord>0
		      )
	select ancestor_names
	from tree where predicate='is_parent' order by ancestor_names";
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
	#return $sth->fetchall_arrayref({});
};


$Template::Stash::SCALAR_OPS->{get_children_rand} = sub {
	my $knot_id=shift;
	my $q="select children.knot_id as knot_id,children.knot_name as knot_name,children.knot_content as knot_content,bounds.* from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and predicate='is_parent' order by random()";
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
};
# create list op vmethod, sorry its pretty trivial
$Template::Stash::SCALAR_OPS->{get_children} = sub {
	my $knot_id=shift;
	my $q="select children.*,bounds.* from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and predicate='is_parent' order by knot_id desc";
	debug $q;
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
};

# create list op vmethod, sorry its pretty trivial
$Template::Stash::SCALAR_OPS->{get_children_roulette} = sub {
	my $knot_id=shift;
	my $q="select children.*,bounds.* from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and predicate='is_parent' order by random()*bounds.ord asc";
	#debug $q;
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
};


$Template::Stash::SCALAR_OPS->{get_contained} = sub {
	my $knot_id=shift;
	my $q="select children.*,bounds.* from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and predicate='contains' order by ord desc,children.attributes->'epoch' desc";
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
};

$Template::Stash::SCALAR_OPS->{get_children_in_space} = sub {
	my $knot_id=shift;
	my $q="select Xb.ord as X_coordinate,Yb.ord as Y_coordinate,Zb.ord as Z_coordinate,children.*,bounds.* from bounds left join knots as children on children.knot_id=bounds.obj left join bounds as Xb on Xb.sub=bounds.sub and Xb.obj=bounds.obj and Xb.predicate='contains_at_X_coordinate' left join bounds as Yb on Yb.sub=bounds.sub and Yb.obj=bounds.obj and Yb.predicate='contains_at_Y_coordinate' left join bounds as Zb on Zb.sub=bounds.sub and Zb.obj=bounds.obj and Zb.predicate='contains_at_Z_coordinate'  where bounds.sub=? and bounds.predicate='is_parent'";
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
};


$Template::Stash::SCALAR_OPS->{get_uncurated_grandchildren} = sub {
        my $knot_id=shift;
        my $q="select
                children.ord,children.knot_id as parent_id, '2' as depth,
                bounds.ord as ord2,
                children.knot_name as parent,
                grandchildren.knot_id as knot_id,
                grandchildren.knot_name as name,
                grandchildren.attributes->'ogg_url' as ogg_url,
                grandchildren.knot_content as content,
                grandchildren.attributes->'autx_content' as autx_content              
		from  (select children.*,bounds.* from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and predicate='is_parent') 
        children join bounds on bounds.sub=children.knot_id and bounds.predicate='is_uttered_as' join knots as grandchildren on bounds.obj=grandchildren.knot_id left join bounds as qb on qb.sub=grandchildren.knot_id and qb.predicate='has_quality' and qb.bound_creator=? where qb.obj is NULL order by children.knot_id limit 100";
        my $sth=database('knots')->prepare($q);
        $sth->execute($knot_id,session('user_id'));
        return $sth->fetchall_arrayref({});
};

$Template::Stash::SCALAR_OPS->{get_curated} = sub {
        my $knot_id=shift;
        my $q="select attributes->'ogg_url' as ogg_url from bounds left join knots on knot_id=sub where obj=? and predicate='has_quality'";
	my $sth=database('knots')->prepare($q);
	#debug($q);
        $sth->execute($knot_id);
        return $sth->fetchall_arrayref({});
};



$Template::Stash::SCALAR_OPS->{get_grandchildren_audiotext} = sub {
        my $knot_id=shift;
        my $q="select
                children.ord,children.knot_id as parent_id, '2' as depth,
                bounds.ord as ord2,
                children.knot_name as parent,
                grandchildren.knot_id as knot_id,
                grandchildren.knot_name as name,
                grandchildren.attributes->'ogg_url' as ogg_url,
                grandchildren.knot_content as content,
                grandchildren.attributes->'autx_content' as autx_content              
		from  (select children.*,bounds.* from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and predicate='is_parent') 
        children join bounds on bounds.sub=children.knot_id and bounds.predicate='is_uttered_as' join knots as grandchildren on bounds.obj=grandchildren.knot_id where  bounds.ord>0 order by children.knot_id";
        my $sth=database('knots')->prepare($q);
        $sth->execute($knot_id);
        return $sth->fetchall_arrayref({});
};

$Template::Stash::SCALAR_OPS->{check_HMPL} = sub {
	my $action=shift;
	my $q="select * from zeitgeist where method=? and vars->'state'='COMPLETE' and action_executed>NOW()-interval '20 HOURS' and action=? and agent_id=? order by action_executed desc limit 1";
	#debug($q);
	#database('knots')->trace(2);
	my $sth=database('knots')->prepare($q);
	$sth->execute($action,session('knot_id'),session('user_id'));
	#my $r= $sth->fetchall_arrayref({});
	my $r= $sth->fetchrow_hashref();
	#use Data::Dumper;
	#debug Dumper($r);
	session 'HMPL_phase'=>$action;
	return $r;
};


$Template::Stash::SCALAR_OPS->{get_all_useraudio} = sub {
	my $user=shift;
	debug($user);
	#my $q='select attributes->\'ogg_url\' as ogg_url from knots where knot_name like \'% by iolanda-maitreya-%\'';
	my $q='select attributes->\'ogg_url\' as ogg_url from knots where knot_name like ?';
	debug($q);
	my $sth=database('knots')->prepare($q);
	$sth->execute("% by $user-%");
	my $r= $sth->fetchall_arrayref({});
	use Data::Dumper;
	debug Dumper($r);
	return $r;
};


$Template::Stash::SCALAR_OPS->{get_members} = sub {
	my $knot_id=shift;
	debug "GETTIN MEMBERS OF $knot_id\n";
	my $q="
select state.sub,state.ord,bounds.*, children.knot_id as knot_id,children.knot_name as knot_name,children.knot_content as knot_content,children.attributes as attributes from bounds left join knots as children on children.knot_id=bounds.sub left join bounds as state on children.knot_id=state.obj and state.sub=? and state.predicate='misunderstands' where bounds.obj=? and (state.ord>=0.5 or state.ord IS NULL) and bounds.predicate='is_member' order by bounds.ord,attributes->'difficulty',state.ord,knot_id";
	if (session('HMPL_phase') eq 'TEST') {
		$q=$q." limit 10";
		session 'HMPL_phase'=>'';
	} elsif (session('HMPL_phase') eq 'LEARN') {
		$q=$q." limit 20";
		session 'HMPL_phase'=>'';
	}
	#debug "select state.sub,state.ord,bounds.*, children.knot_id as knot_id,children.knot_name as knot_name,children.knot_content as knot_content,children.attributes as attributes from bounds left join knots as children on children.knot_id=bounds.sub left join bounds as state on children.knot_id=state.obj and state.sub=".session('user_id')." and state.predicate='misunderstands' where bounds.obj=$knot_id and (state.ord>=0.5 or state.ord IS NULL) and bounds.predicate='is_member' order by state.ord desc,bounds.ord desc,knot_id";
	my $sth=database('knots')->prepare($q);
	$sth->execute(session('user_id'),$knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
};


$Template::Stash::SCALAR_OPS->{get_2generations} = sub {
	my $knot_id=shift;
	my $q="
		(select
		children.ord,children.knot_id as parent_id, '2' as depth,
		bounds.ord as ord2,
		children.knot_name as parent_name,
		grandchildren.knot_id as knot_id,
		grandchildren.knot_name as knot_name,
		grandchildren.knot_content as knot_content,
		grandchildren.attributes as attributes
 from (select children.*,bounds.* from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and predicate='is_parent' order by ord asc,knot_id asc) as children left join bounds on bounds.sub=children.knot_id left join knots as grandchildren on bounds.obj=grandchildren.knot_id and bounds.predicate='is_parent' where ";
	$q.=" bounds.ord>0 order by bounds.ord,children.ord,children.knot_id asc)
		UNION (
		select ord,children.knot_id as parent_id, '1' as depth,
		1 as ord2,
		'' as parent_name,
		children.knot_id as knot_id,
		children.knot_name as knot_name,
		children.knot_content as knot_content,
		children.attributes as attributes
		from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and ord>0 and predicate='is_parent' order by ord,knot_id asc
		) 
		order by ord,parent_id desc,depth,ord2
";

	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id,$knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
};
	#3generations do not work yet

$Template::Stash::SCALAR_OPS->{get_materialized_paths} = sub {
	my $knot_name=shift;
	#debug $knot_name;
	my $sth=database('knots')->prepare("select knot_id,knot_content,knot_name,attributes->'template' as template from knots where knot_name like ? order by knot_name");
	$sth->execute($knot_name.'%');
	return attach_attributes $sth->fetchall_arrayref({});
};

$Template::Stash::SCALAR_OPS->{get_3generations} = sub {
	my $knot_id=shift;
	my $q="
(select grandchildren.ord,grandchildren.knot_id as parent_id, '3' as depth,bounds.predicate as predicate,bounds.ord as ord2,grandchildren.knot_name as parent_name,grandgrandchildren.knot_id as knot_id,grandgrandchildren.knot_name as knot_name,grandgrandchildren.knot_content as knot_content,grandgrandchildren.attributes as attributes from (select grandchildren.*,bounds.* from bounds left join knots as grandchildren on grandchildren.knot_id=bounds.obj where sub=? order by ord desc,knot_id) grandchildren left join bounds on bounds.sub=grandchildren.knot_id left join knots as grandgrandchildren on bounds.obj=grandgrandchildren.knot_id where bounds.ord>0 order by bounds.ord desc,grandchildren.ord desc,grandchildren.knot_id asc)
        UNION
	(select children.ord,children.knot_id as parent_id, '2' as depth,bounds.predicate as predicate,bounds.ord as ord2,children.knot_name as parent_name,grandchildren.knot_id as knot_id,grandchildren.knot_name as knot_name,grandchildren.knot_content as knot_content, grandchildren.attributes as attributes from (select children.*,bounds.* from bounds left join knots as children on children.knot_id=bounds.obj where sub=? order by ord desc,knot_id) children left join bounds on bounds.sub=children.knot_id left join knots as grandchildren on bounds.obj=grandchildren.knot_id where bounds.ord>0 order by bounds.ord desc,children.ord desc,children.knot_id asc)
	        UNION
		(select ord,children.knot_id as parent_id, '1' as depth,bounds.predicate as predicate,1 as ord2,'' as parent_name,children.knot_id as knot_id,children.knot_name as knot_name,children.knot_content as knot_content,children.attributes as attributes from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and ord>0 order by ord desc,knot_id ) order by depth,ord desc,parent_id,ord2 desc
	";
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id,$knot_id,$knot_id);
	return attach_attributes $sth->fetchall_arrayref({});
};


$Template::Stash::SCALAR_OPS->{get_graph} = sub {
	my $knot_id=shift;
	my $q="select knot_content from knots where knot_id=?"; 
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	$ref=$sth->fetchall_arrayref({});
};

$Template::Stash::SCALAR_OPS->{get_group} = sub {
	my $knot_id=shift;
	my $q="select 
		children.knot_id as knot_id,
		children.knot_name as knot_name,
		children.knot_content as knot_content,
		children.attributes as attributes
		from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and predicate='is_member' and ord>0 order by ord desc,knot_id";
	 
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	$ref=$sth->fetchall_arrayref({});
	my $map_keys="";
	my $map_rels="";
	my @ids;
	for my $k (@$ref) {
		$ki=($k->{'knot_id'});
		$kn=($k->{'knot_name'});
		#$kc=($k->{'knot_content'});
		#$map_keys=$map_keys."{ \"id\": \"$kn\", \"group\": 1 },";
		$map_keys=$map_keys."\"$kn\":{\"name\":\"$kn\"},";
		push @ids,$ki;
	}
	chop $map_keys;
	my $ids=join(',',@ids);
	my $q="select predicate,source.knot_name as source,target.knot_name as target,ord as distance from bounds left join knots as source on bounds.sub=source.knot_id left join knots as target on bounds.obj=target.knot_id where obj in ($ids) and sub in ($ids) and ord>0";
	#debug $q;
	my $sth=database('knots')->prepare($q);
	$sth->execute();
	$ref=$sth->fetchall_arrayref({});
	for my $k (@$ref) {
		#$ki=($k->{'knot_id'});
		$source=($k->{'source'});
		$target=($k->{'target'});
		$distance=($k->{'distance'});
		$predicate=($k->{'predicate'});
		$map_rels=$map_rels."{ \"source\": \"$source\", \"target\": \"$target\", \"distance\": \"$distance\", \"label\":\"$predicate\"},";
		push @ids,$ki;
	}
	chop $map_rels;

	return '{"nodes":{'.$map_keys.'},"links":['.$map_rels.']}';

};	

$Template::Stash::SCALAR_OPS->{get_map} = sub {
	my $knot_id=shift;
	my $q="select 
		children.knot_id as knot_id,
		children.knot_name as knot_name,
		children.knot_content as knot_content,
		children.attributes as attributes
		from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and ord>0 order by ord desc,knot_id";
	 
	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id);
	$ref=$sth->fetchall_arrayref({});
	my %concepts;
	my @terms;
	my %net;
	my $map_keys="";
	my $map_rels="";
	for my $k (@$ref) {
		$ki=($k->{'knot_id'});
		$kn=($k->{'knot_name'});
		$kc=($k->{'knot_content'});
		#$kn=~s/ /<br>/g;
		my @lok;
		my %used;
		$kc=~s/<[^>]*>//gs;
		#$kn=~s/<[^>]*>//gs;
		#push (@lok,$1) while($kn=~/[, ]([A-Z][a-z]+)/g);
		push @terms,$kn;
		$map_keys=$map_keys."{ \"id\": \"$kn\", \"group\": 1 },";
		push (@lok,$1) while($kc=~/[, ]([A-Z][a-z]+)/g);
		for  my $term (@lok) {
			if (!(exists $concepts{$term})) {
				#debug "T $term K $kn";
				$concepts{$term}=[];
			}
			push @{$concepts{$term}},$kn;
		}
		#debug "$term",@{$concepts{$term}};
	}
	for my $source (keys %concepts) {
		next if length($source)<1;
		if (@{$concepts{$source}}>1) {
			$map_keys=$map_keys."{ \"id\": \"$source\", \"group\": 1 },";
			for my $target (@{$concepts{$source}}) {	
				$map_rels=$map_rels."{ \"source\": \"$source\", \"target\": \"$target\", \"distance\": 1 },";
			}
		}
	}
	chop $map_keys;
	if (!$map_rels) {
		#debug "CREATIN PRODUCT";
		for my $source (@terms) {
			#debug "SOU $source";
			for my $target (@terms) {
				if ($source ne $target) {
					$map_rels=$map_rels."{ \"source\": \"$source\", \"target\": \"$target\", \"distance\": 1 },";
				}
			}
		}
	}

	chop $map_rels;
	return '{"nodes":['.$map_keys.'],"links":['.$map_rels.']}';

};	
	
$Template::Stash::SCALAR_OPS->{get_2generations_map} = sub {
	my $knot_id=shift;
	my $q="
		(select
		children.ord,children.knot_id as parent_id, '2' as depth,
		bounds.ord as ord2,
		children.knot_name as parent_name,
		grandchildren.knot_id as knot_id,
		grandchildren.knot_name as knot_name,
		grandchildren.knot_content as knot_content,
		grandchildren.attributes as attributes
 from (select children.*,bounds.* from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and predicate='is_parent' order by ord desc,knot_id) children left join bounds on bounds.sub=children.knot_id left join knots as grandchildren on bounds.obj=grandchildren.knot_id where ";
	$q.=" bounds.ord>0 order by bounds.ord desc,children.ord desc,children.knot_id asc)
		UNION (
		select ord,children.knot_id as parent_id, '1' as depth,
		1 as ord2,
		'' as parent_name,
		children.knot_id as knot_id,
		children.knot_name as knot_name,
		children.knot_content as knot_content,
		children.attributes as attributes
		from bounds left join knots as children on children.knot_id=bounds.obj where sub=? and ord>0 order by ord desc,knot_id 
		) 
		order by ord desc,parent_id,depth,ord2 desc
";

	my $sth=database('knots')->prepare($q);
	$sth->execute($knot_id,$knot_id);
	$ref=$sth->fetchall_arrayref({});
	my %concepts;
	my %net;
	for my $k (@$ref) {
		$ki=($k->{'knot_id'});
		$kn=($k->{'knot_name'});
		$kc=($k->{'knot_content'});
		my @lok;
		my %used;
		$kc=~s/<[^>]*>//gs;
		$kn=~s/<[^>]*>//gs;
		push (@lok,$1) while($kn=~/[, ]([A-Z][a-z]+)/g);
		push (@lok,$1) while($kc=~/[, ]([A-Z][a-z]+)/g);
		#$map=$map."$kn,@lok\n";
		for $l1 (@lok) {
			next if exists $used{$l1};	
			next if length $l1 < 4;
			if (exists $concepts{$l1}) {
				$concepts{$l1}=$concepts{$l1}+1;
			} else {
				$concepts{$l1}=1;
			}
			for $l2 (@lok) {
				#next if exists $used{$l2};	
				next if length $l2 < 4;
				if (!exists $net{$l1}{$l2}) {
					$net{$l1}{$l2}=1;
				} else {
					$net{$l1}{$l2}=$net{$l1}{$l2}+1;
				}
			}
			#$used{$l1}=1;
		}
	}
	for my $k (%concepts) {
		if ($concepts{$k}>1) {
			$map_keys=$map_keys."{ \"id\": \"$k\", \"group\": $concepts{$k} },";
		}
	}
	for $k1 (keys %net) {
		for $k2 (keys @{$net{$k1}}) {
			if ($net{$k1}{$k2} && ($k1 ne $k2) && $concepts{$k1}>1 && $concepts{$k2} >1) {
				$map_rels=$map_rels."{ \"source\": \"$k1\", \"target\": \"$k2\", \"distance\": $net{$k1}{$k2} },";
			}
		}
	}
	chop $map_keys;
	chop $map_rels;
	my $json= '{"nodes":['.$map_keys.'],"links":['.$map_rels.']}';
	return $json;
};

