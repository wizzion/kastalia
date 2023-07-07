#Licenced under WPL
#Licensor: wizzion.com UG (haftungsbeschränkt)
sub attach_attributes {
	my $aref=shift;
	for my $item (@$aref) {
		my $attributes = Pg::hstore::decode($item->{attributes});
		for my $a_k (keys %$attributes) {
			if ($a_k eq 'epoch') {
				my @t=localtime($attributes->{$a_k});
				#debug "TIME $item->{$a_k} @t";
				my $year=$t[5]-70;
				my $suffix=strftime('%m%d',@t);
				$item->{'ae_epoch'}='AE'.$year.$suffix;
				$item->{'date'}=strftime('%d.%m.%Y',@t);
			}
			#else {
			if ($a_k !~/^knot_/ and $attributes->{$a_k}) {
				$item->{$a_k}=$attributes->{$a_k};
			}
			#debug "ATTACHIN $a_k".$item->{$a_k};
		}
	}
	#debug $aref;
	return $aref;
}

sub upsertBound {
	(my $sub, my $predicate, my $obj, my $init_weight, my $operation, my $parameter, my $msg) = @_;
	debug("MSG$msg");
	#database('knots')->trace(2);
	#$ord=1 if (!$ord);
	my $q="insert into bounds (sub,predicate,obj,ord,bound_creator) values (?,?,?,((select ord from bounds as b where sub=? and predicate=? and obj=?) union (select ?) limit 1),?) on conflict(sub, obj, predicate, ord) do update set ord=excluded.ord $operation ? returning bound_id,ord";
	my $user_id=session('user_id');
	#debug("UPSERT $sub,$predicate,$obj,$sub,$predicate,$obj,$init_weight,$user_id,$parameter,$msg");
	my $sth=database('knots')->prepare($q);
	#debug($q);
	#database('knots')->trace(2);
	$sth->execute($sub,$predicate,$obj,$sub,$predicate,$obj,$init_weight,$user_id,$parameter);
	$result = $sth->fetchrow_hashref;
	my $bound_id=$result->{'bound_id'};
	my $ord=$result->{'ord'};
	#debug("UPSERTED $bound_id to $ord");
	addZeitgeist(session('user_id'),'upsert_bound','TEST',{obj=>$obj, sub=>$sub, predicate=>$predicate,ord=>$ord,bound_id=>$bound_id,bound_creator=>$user_id,msg=>$msg,operation=>"$operation $parameter"});
}


sub addBound {
	(my $sub, my $predicate, my $obj, my $ord) = @_;
	$ord=1 if (!$ord);
	my $sth=database('knots')->prepare('INSERT INTO bounds(sub,predicate,obj,ord, bound_creator) VALUES (?,?,?,?,?)');						
	debug "ADDBOUND $sub $predicate $obj $ord".session('user_id');
	$sth->execute($sub,$predicate,$obj,$ord,session('user_id'));
	my $bound_id = database('knots')->last_insert_id(undef,undef,undef,undef,{sequence=>'bound_id_seq'});
	addZeitgeist(session('user_id'),'add_bound','post',{obj=>$obj, sub=>$sub, predicate=>$predicate,ord=>$ord,bound_id=>$bound_id});
}

sub strenghtenBound {
	my $knot_id=shift;
	my $role=shift;
	$role='sub' if !$role;
	my $predicate=shift;
	my $sth=database('knots')->prepare("update bounds set ord=ord+1 where $role=? and predicate=?");	
	$sth->execute($knot_id,$predicate);
}

sub resetBound {
	my $knot_id=shift;
	my $role=shift;
	$role='sub' if !$role;
	my $predicate=shift;
	my $sth=database('knots')->prepare("update bounds set ord=0 where $role=? and predicate=?");	
	$sth->execute($knot_id,$predicate);
}



sub addZeitgeist {
	(my $agent, my $action, my $method, my $vars) = (@_);
	my $sth=database('knots')->prepare('insert into zeitgeist values (NOW(),?,?,?,?)');
	$vars->{'login'}=session('login') if session('login');
	$sth->execute($agent,$action,$method,Pg::hstore::encode($vars));
}


sub addKnot {
	(my $knot_name, my $knot_content, my $attributes) = (@_);
	if ((session('login'))) {
		$attributes->{'creator'}=(session('login'));
	}
	if ($attributes) {
		my $sth=database('knots')->prepare('insert into knots (knot_name,knot_content,attributes) values (?,?,?)');
		$sth->execute($knot_name, $knot_content, Pg::hstore::encode($attributes));
	} else {
		my $sth=database('knots')->prepare('insert into knots (knot_name,knot_content) values (?,?)');
		$sth->execute($knot_name, $knot_content);
	
	}
	my $knot_id = database('knots')->last_insert_id(undef,undef,undef,undef,{sequence=>'knots_knot_id_seq'});
	addAttribute($knot_id,'epoch',time);
	addBound((session('user_id')),'created_by',$knot_id) if (session('user_id'));
	return $knot_id;
}

sub addAttribute {
	(my $knot_id, my $a_name, my $a_value) = (@_);
	my $sth2 = database('knots')->prepare("update knots set attributes=attributes || ? where knot_id=?");
	$sth2->execute(hstore_encode({$a_name=>$a_value}),$knot_id);
} 

sub login {
	($login,$ajax)=shift;
	debug("LOGIN IN ".$login);
	session 'user'=>$login;
	my $user_knot=get_first_knot_with_name($login);
	if ($user_knot->{knot_id}) {
		session 'user_id' => $user_knot->{knot_id};
		#server-side variables ... 
		for my $k ('zodiac','consent','gender','age','motherlang','voice','home_knot','collects','font','score','text_transform') {
			#debug "$k $user_knot->{$k}";
			session $k => $user_knot->{$k};
		}
	} else {
		session 'user_id' => addKnot($l,"Profile of $l\n");	
	}
	my $dispatch = session 'dispatch';
	my $home_knot = session 'home_knot';
	#debug "Logging in $l with ID ".$user_knot->{knot_id};
	session 'bookmarks' => get_bookmarks($user_knot->{knot_id});
	#my $shortlogin=$l;
	session 'login' => $login;
	$dispatch = params->{force_dispatch} if params->{force_dispatch};
	if ($home_knot) {
		debug "HK".$home_knot;
		$ajax ? return $home_knot : forward  "/".$home_knot ,{err=>''},{method=>'GET'};
	}
	elsif ($dispatch) {
		debug "DISPATCH ".$dispatch;
		forward  $dispatch ,{err=>''},{method=>'GET'};
	} else {
		forward  "/last/" ,{},{method=>'GET'};
	}
}

true;
