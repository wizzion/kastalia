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
var recordingStarted;

function startRecording() {
	console.log("recordingStarted");
	if (recordingStarted) {
		return;
	}
	audioContext = new AudioContext();
	//alert("AC started");
    	$('#upld').html('');
    	//$('#logos').attr('src','');
	//alert("recording started");
	/*
		Simple constraints object, for more advanced audio features see
		https://addpipe.com/blog/audio-constraints-getusermedia/
	*/
    
    var constraints = { audio: true, video:false }

 	/*
    	Disable the record button until we get a success or fail from getUserMedia() 
	*/

	//recordButton.disabled = true;
	stopButton.disabled = false;
	//pauseButton.disabled = false
if (navigator.mediaDevices === undefined) {
  navigator.mediaDevices = {};
  alert("md undefined!");
}

// Some browsers partially implement mediaDevices. We can't just assign an object
// with getUserMedia as it would overwrite existing properties.
// Here, we will just add the getUserMedia property if it's missing.
/*
if (navigator.mediaDevices.getUserMedia === undefined) {
  navigator.mediaDevices.getUserMedia = function(constraints) {

    // First get ahold of the legacy getUserMedia, if present
    var getUserMedia = navigator.webkitGetUserMedia || navigator.mozGetUserMedia;

    // Some browsers just don't implement it - return a rejected promise with an error
    // to keep a consistent interface
    if (!getUserMedia) {
      return Promise.reject(new Error('getUserMedia is not implemented in this browser'));
alert("no getusermedia");
    }

    // Otherwise, wrap the call to the old navigator.getUserMedia with a Promise
    return new Promise(function(resolve, reject) {
      getUserMedia.call(navigator, constraints, resolve, reject);
    });
  }
}
*/
navigator.mediaDevices.getUserMedia(constraints).then(function(stream) {
		navigator.allMediaStreams.push(stream);
		//alert("getUserMedia() success, stream created, initializing Recorder.js ...");

		/*
			create an audio context after getUserMedia is called
			sampleRate might change after getUserMedia is called, like it does on macOS when recording through AirPods
			the sampleRate defaults to the one set in your OS for your playback device

		*/
		//audioContext = new AudioContext({sampleRate: 44100});
		audioContext = new AudioContext();

		//update the format 
		//document.getElementById("formats").innerHTML="Format: 1 channel pcm @ "+audioContext.sampleRate/1000+"kHz"
		console.log("sample rate"+audioContext.sampleRate);
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
		$("#stopButton").css('display','block');

	}).catch(function(err) {
	  	//enable the record button if getUserMedia() fails
		console.log("what's up?"+err);
    		recordButton.disabled = false;
    	//stopButton.disabled = true;
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
	//alert("stopButton clicked");

	//disable the stop button, enable the record too allow for new recordings
	stopButton.disabled = true;
	//recordButton.disabled = false;
	//pauseButton.disabled = true;

	//reset button just in case the recording is stopped while paused
	//pauseButton.innerHTML="Pause";
	console.log("stoppingrecording");	
	//tell the recorder to stop the recording
	rec.stop();
	console.log("rec stopped");
	//stop microphone access
	gumStream.getAudioTracks()[0].stop();

	//create the wav blob and pass it on to createDownloadLink
	rec.exportWAV(createDownloadLink);
	//console.log("all good?");
	recordingStarted=false;
	$("#stopButton").css('display','none');
}

function createDownloadLink(blob) {
	//alert(output);
	try {
		eval(output);
		//alert("correct JSON");
	}
	catch (e) {
		//alert("invalid JSON");
		return false;
	}
	var url = URL.createObjectURL(blob);
	var au = document.getElementById('logos');
	//var li = document.createElement('li');
	var upld = document.getElementById('upld');
	//var link = document.createElement('a');

	//name of .wav file to use during upload and download (without extendion)
	var filename = new Date().toISOString();

	//add controls to the <audio> element
	au.controls = true;
	au.src = url;
	$("#downloadlink").href=url;
	$("#downloadlink").innerHTML=url;
	console.log(au.src);

	var upload = document.createElement('a');
	upload.href="#";
	upload.innerHTML = "⬆"//#upload symbol
	$("#audiomenu").css('display','block');
	upload.addEventListener("click", function(event){
		console.log("upload click triggered");
		submit_recording(blob);
	})
	//li.appendChild(document.createTextNode (" "))//add a space in between
	//alert($( "#consent" ).val());
	if ($( "#consent" ).val() != 'NOT') {
		upld.appendChild(upload); //add the upload link to li
	}
	//add the li element to the ol
	//recordingsList.appendChild(li);
}
