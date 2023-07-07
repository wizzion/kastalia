//webkitURL is deprecated but nevertheless
URL = window.URL || window.webkitURL;

var gumStream; 						//stream from getUserMedia()
var rec; 							//Recorder.js object
var input; 							//MediaStreamAudioSourceNode we'll be recording

// shim for AudioContext when it's not avb. 
var AudioContext = window.AudioContext || window.webkitAudioContext;
var audioContext //audio context to help us record

var recordButton = document.getElementById("recordButton");
var stopButton = document.getElementById("stopButton");
//var pauseButton = document.getElementById("pauseButton");
var recordingStarted;

//add events to those 2 buttons
/*
recordButton.addEventListener("click", startRecording);
stopButton.addEventListener("click", stopRecording);
recordButton.addEventListener("mouseover", startRecording);
stopButton.addEventListener("mouseover", stopRecording);
recordButton.addEventListener("touchstart", startRecording);
stopButton.addEventListener("touchstart", stopRecording);
*/
recordButton.addEventListener("pointerenter", startRecording);
recordButton.addEventListener("touchstart", startRecording);
recordButton.addEventListener("click", startRecording);
recordButton.addEventListener("mouseenter", startRecording);
stopButton.addEventListener("pointerenter", stopRecording);


//pauseButton.addEventListener("click", pauseRecording);

function startRecording() {
	console.log("recording started");
	/*
		Simple constraints object, for more advanced audio features see
		https://addpipe.com/blog/audio-constraints-getusermedia/
	*/
    
    var constraints = { audio: true, video:false }

 	/*
    	Disable the record button until we get a success or fail from getUserMedia() 
	*/

	recordButton.disabled = true;
	stopButton.disabled = false;
	//pauseButton.disabled = false

	/*
    	We're using the standard promise based getUserMedia() 
    	https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia
	*/
	navigator.mediaDevices.getUserMedia(constraints).then(function(stream) {
		console.log("getUserMedia() success, stream created, initializing Recorder.js ...");

		/*
			create an audio context after getUserMedia is called
			sampleRate might change after getUserMedia is called, like it does on macOS when recording through AirPods
			the sampleRate defaults to the one set in your OS for your playback device

		*/
		audioContext = new AudioContext();

		//update the format 
		document.getElementById("formats").innerHTML="Format: 1 channel pcm @ "+audioContext.sampleRate/1000+"kHz"

		/*  assign to gumStream for later use  */
		gumStream = stream;
		
		/* use the stream */
		input = audioContext.createMediaStreamSource(stream);

		/* 
			Create the Recorder object and configure to record mono sound (1 channel)
			Recording 2 channels  will double the file size
		*/
		rec = new Recorder(input,{numChannels:1})

		//start the recording process
		rec.record()
		recordingStarted=performance.now();
		console.log("Recording started");

	}).catch(function(err) {
	  	//enable the record button if getUserMedia() fails
	console.log("what's up?");
    	recordButton.disabled = false;
    	stopButton.disabled = true;
    	//pauseButton.disabled = true
	});
}
/*
function pauseRecording(){
	console.log("pauseButton clicked rec.recording=",rec.recording );
	if (rec.recording){
		//pause
		rec.stop();
		pauseButton.innerHTML="Resume";
	}else{
		//resume
		rec.record()
		pauseButton.innerHTML="Pause";

	}
}
*/
function stopRecording() {
	console.log("stopButton clicked");

	//disable the stop button, enable the record too allow for new recordings
	stopButton.disabled = true;
	recordButton.disabled = false;
	//pauseButton.disabled = true;

	//reset button just in case the recording is stopped while paused
	//pauseButton.innerHTML="Pause";
	
	//tell the recorder to stop the recording
	rec.stop();

	//stop microphone access
	gumStream.getAudioTracks()[0].stop();

	//create the wav blob and pass it on to createDownloadLink
	rec.exportWAV(createDownloadLink);
}

function createDownloadLink(blob) {
	
	var url = URL.createObjectURL(blob);
	var au = document.getElementById('logos');
	var li = document.createElement('li');
	var link = document.createElement('a');

	//name of .wav file to use during upload and download (without extendion)
	var filename = new Date().toISOString();

	//add controls to the <audio> element
	au.controls = true;
	au.src = url;
	au.id = 'logos';
	//save to disk link
	link.href = url;
	$("#downloadlink").href=url;
	alert(url);
	link.download = filename+".wav"; //download forces the browser to donwload the file using the  filename
	link.innerHTML = "Save to disk";
	//add the new audio element to li
	li.appendChild(au);
	//add the filename to the li
	li.appendChild(document.createTextNode(filename+".wav "))

	//add the save to disk link to li
	li.appendChild(link);
	
	document.getElementById('#menu').appendChild(link);	
	//upload link
	var upload = document.createElement('a');
	upload.href="#";
	upload.innerHTML = "Upload";
	upload.addEventListener("click", function(event){
		  var xhr=new XMLHttpRequest();
		xhr.onreadystatechange=function(){
       /*if (xhr.readyState==4 && xhr.status==200){
          var data = $.parseJSON(xhr.responseText);
          var uploadResult = data['message']
              if (uploadResult=='failure'){
             console.log('failed to upload file');
          }else if (uploadResult=='success'){
             console.log('successfully uploaded file');
		window.location.href='/knot/'+$('#knot_parent').text();
          }
       }*/
    }
		  xhr.onload=function(e) {
		      if(this.readyState === 4) {
		          console.log("Server returned: ",e.target.responseText);
			if ($('#knot_next').text() && !$('#update_existing').is(':checked')) {
				window.location.href='/view/'+$('#knot_next').text()+'/textrec/';
			} else {
				window.location.href='/knot/'+$('#knot_parent').text();
			}
		      }
		  };
		  var fd=new FormData();
		  fd.append("timestamps",$('#timestamps').text().replace(/,$/,""));
		  alert($('#timestamps').text());
		  fd.append("content", $('#content').text());
		  fd.append("knot_name",$('#knot_name').text());
		  fd.append("container_id",$('#container_id').val());
		  if ($('#update_existing').is(':checked')) {
			  fd.append("update_existing",1);
		  }
		  fd.append("knot_parent",$('#knot_parent').text());
		  console.log(timestamps);
		  fd.append("audio_data",blob, filename);

		  xhr.open("POST","/new_audio_knot",true);
		  xhr.send(fd);
	})
	li.appendChild(document.createTextNode (" "))//add a space in between
	li.appendChild(upload)//add the upload link to li

	//add the li element to the ol
	//recordingsList.appendChild(li);
	document.getElementById('#recordingsList').appendChild(li);	
}