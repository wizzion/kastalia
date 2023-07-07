<script>
	
        var feedback=0;
	function next_slide() {
        	feedback=0;
		$.deck('next');
	}
	var mediaRecorder;
	var stream;
	var port=8080;
	navigator.allMediaStreams = [];
	var collects="<%t='collects'%><%t.get_session_key%>";
	async function newRequest() {
	  //let stream = null;
	  var alphabet=/[^\p{Letter},§„“?.!\-:;()' ]/gu;
	  current_token=current_token.replace(alphabet,'');
	  try {
		  if (current_token.match(alphabet)) {
			  console.log("bypassing tokens '"+current_token+"' containing non-letter characters");
			  return;
		  }
		  stream = await navigator.mediaDevices.getUserMedia({audio:true,video:false});
		  console.log(navigator.allMediaStreams);
		  console.log("pushin to allmedia");
		  navigator.allMediaStreams.push(stream);
		  console.log(navigator.allMediaStreams);
		  console.log("startin media");
		  mediaRecorder = new MediaRecorder(stream, {
			mimeType: 'audio/webm'
		  });
		  console.log(mediaRecorder);
		  mediaRecorder.start();
		  console.log("media started");
		  let speaker ="<%t='user'%><%t.get_session_key%>";
		  if (!speaker) { speaker="anonymous"};

		  mediaRecorder.addEventListener('dataavailable', (e) => {
			<%if template_name == 'read' or template_name=='recite' or template_name=='foliorec' or template_name=='explore'%>
			     let token_id = previous_id;
			     var host="pesel.lesen.digital";
			     <%if template_name=='recite'%>
				  var scorer=actual_slide_id;
			          console.log("will use scorer "+scorer);
			  	  var alpha=1;
			     <%else%>
			          var scorer=<%if knot.scorer%><%knot.scorer%><%else%><%knot.knot_id%><%end%>;
			          var alpha="<%if knot.scorer_alpha%><%knot.scorer_alpha%><%else%>0.61<%end%>";
			     <%end%>
			     socket = new WebSocket("wss://"+host+":"+port+"/stt/"+scorer+"/"+current_token+"/"+speaker+"/<%if knot.lang%><%knot.lang%><%else%>de<%end%>/"+alpha);
			     socket.binaryType = "blob";
			     socket.onmessage = function (event) {
				console.log(event.data);
				response=JSON.parse(event.data);
				//document.getElementById("answer").innerHTML+=response.text;
				if (parseInt(response.score)>0) {
					$.ajax({                                            
						url: '/api/increment_score/'+response.score,                        
						async:false,
						success: function(data) { console.log("DAT"+data);}
					});
					score+=parseInt(response.score);
					$("#score").html(score.toString()+" "+collects);
					<%if template_name=='explore'%>
						answer=response.text.replaceAll(' ','_')
						$('.'+answer).css('border','solid '+response.score+'px green');
						setTimeout(function(){$('.'+answer+' > span > a')[0].click() }, 1000);
					<%elsif template_name=='recite'%>
                                                $("#upld").attr('timestamps',JSON.stringify(response.segmentation));
                                                console.log("set "+JSON.stringify(response.segmentation));
					/*$('#'+token_id).css('background-color','transparent');
					if (!response.text) {
						$('#'+token_id).css('border-color','transparent');
					}
					*/
					console.log("match!");
					console.log(token_id);
					$('#'+token_id).css('border-color','green');
					score+=parseInt(response.score);
					$("#score").html(score.toString()+" "+collects);
					<%end%>
				} /*else {
					console.log("mismatch!");
					$('#'+token_id).css('border-color','red');
					console.log(response.text);
					console.log(current_token);
				}*/
			};
			<%elsif template_name=="auth"%>
			    current_token="<%knot.knot_content%>";
			    console.log(current_token);
			     var host="mame.lesen.digital";
			     socket = new WebSocket("wss://"+host+":"+port+"/auth/"+current_token+"/"+speaker+"/");
			     socket.binaryType = "blob";
			     socket.onmessage = function (event) {
				console.log(event.data);
				response=JSON.parse(event.data);
				//document.getElementById("answer").innerHTML+=response.text;
				if (response.login=="" || response.login=="undefined") {
					$(".word").html("Noch einmal '<%knot.knot_content%>' sagen, bitte.");
					return;
				}
				$(".word").html("You will soon log in, "+response.login);
				textFit($(".word"),{maxFontSize:200});

				if (parseFloat(response.similarity)>0) {
					$.ajax({                                            
						url: '/api/auth/',                        
						async:false,
						data:{login:response.login,similarity:response.similarity,hash:response.hash},
						success: function(data) { 
				     			$("#greeting").html("Willkommen zu Hause, "+response.login+" !");
							//console.log("WTF"+data)
							window.location="/";
						}
					});
					
				}
			};
			<%else%>
			  	<!--with scorer socket = new WebSocket("wss://"+host+":"+port+"/hmpl/<%knot.knot_id%>/"+$('#knot_'+actual_slide_id+'_name').text()+"/<%t='user'%><%t.get_session_key%>/");-->
				var host="pesel.lesen.digital";
				current_token=$('#knot_'+actual_slide_id+'_content').text().replace('_',' ');
			  	console.log("CURRENTTOK"+current_token);
				socket = new WebSocket("wss://"+host+":"+port+"/hmpl/<%knot.knot_id%>/"+current_token+"/<%t='user'%><%t.get_session_key%>/<%knot.lang%>/"+phase+"/"+feedback.toString());
				socket.binaryType = "blob";
				console.log(e.data);
				socket.onmessage = function (event) {
					console.log(event.data);
					response=JSON.parse(event.data);
					stream.getTracks()[0].stop(); 
					console.log("CT",current_token.toLowerCase());
					console.log("RT",response.text);
					var re = new RegExp('^'+response.text+'$','i');
					//if (current_token.match(re)) {
					if (parseInt(response.score)>0) {
						console.log("score",response.score);
							$.ajax({                                            
							 	url: '/api/increment_score/'+response.score,                        
							 	async:false,
							 	success: function(data)          
							 	{ 
									console.log("DAT"+data);
							 	}
							});

						//GREEN :: H-M MATCH
						$('.illustration-'+actual_slide_id).css('border','solid 5pt green');
						$("#score").append(collects.repeat(response.score));
						//reduce 'misunderstands' weight
						score+=parseInt(response.score);
						$("#score").html(score.toString()+" "+collects);
						if (phase=="2") {
							illustration_id=current_illustration.match(/\d+/);
							if (illustration_id) {
								$.ajax({                                            
							 	url: '/api/correct/'+actual_slide_id+'/'+illustration_id,                        
							 	async:false,
							 	success: function(data)          
							 	{ 
									console.log("DAT"+data);
							 	},
							});
							}
						}
						setTimeout(next_slide,1000);
					//provide feedback
					} else if (feedback>1) {
						console.log("too much errors, moving forward");
						setTimeout(next_slide,1000);
					} else {
						feedback=feedback+1;
						console.log("incrementing feedback, phase "+phase);
						$("#audio_"+actual_slide_id)[0].play();
						if (phase=="2") {
							console.log("ALL GOOD?");
							$("#audio_"+actual_slide_id)[0].onended = function(){
								console.log("NOT GOOD?");
								//RED :: H most probably said it correctly but the M does not understand yet
								$('.illustration-'+actual_slide_id).css('border','solid 5pt red');
								setTimeout(next_slide,1000);
							}
							illustration_id=current_illustration.match(/\d+/);
							if (illustration_id) {
							$.ajax({                                            
							 	url: '/api/error/'+actual_slide_id+'/'+illustration_id,                        
							 	async:false,
							 	success: function(data)          
							 	{ 
									console.log("DAT"+data);
							 	},
							});
							}
						}
						else {
							//BLUE :: H most probably said it correctly but the M does not understand yet
							$('.illustration-'+actual_slide_id).css('border','solid 5pt blue');
						}
					}
				};
				
			<%end%>
				//console.log(token_sequence);
				console.log(predictions);
			socket.onopen = function (event) {
				socket.send(e.data);
			}
		  });
	  } catch(err) {
		console.log(err);
	  }
	}
</script>
