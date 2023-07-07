#!/data/deepspeech-train-jetson-venv/bin/python3
# Usage: python3 split_audio_by_silence.py -i input_audio.m4a -o segments
#  will save segments in mp3 format into the segments directory
#  based on https://github.com/mozilla/DeepSpeech/tree/master/examples/vad_transcriber
# Dependencies: webrtcvad

import os,json
import argparse
from pathlib import Path
import collections
import subprocess
import webrtcvad

import websocket,sys,ssl

# 0,10,3 almost there
parser = argparse.ArgumentParser()
# parser.add_argument('-f', '--input-file', required=True)
parser.add_argument('--host', default="127.0.0.1", help ="Hostname of machine running lesen-mikroserver secure websocket (WSS) on port 8080")
parser.add_argument('-v', '--voice', default="testing-voice", help ="Name of the voice, most often of a form firstname-surname")
parser.add_argument('-s', '--scorer', default="en-large", help ="Name of the scorer")
parser.add_argument('-l', '--language', default="en", help ="Language (en, de, sk, ...)")
parser.add_argument('-i', '--input-file', default="data/raw", help ="Path to input file")
parser.add_argument('-o', '--output-dir', default="data/segs",help="Output directory")
parser.add_argument('-a', '--aggressive', default=0,
                    type=int, choices=[0, 1, 2, 3])
parser.add_argument('-d', '--frame_duration_ms', default=30,
                    type=int, choices=[10, 20, 30, 40, 50])
parser.add_argument('-m', '--min_segment_duration', type=int, default=2)

args = parser.parse_args()

# create directory for segments
# os.makedirs(args.output_dir, exist_ok=True)

# define output csv abs path
# segmentation function


def detect_voice_segments(vad, audio, sample_rate, frame_bytes, frame_duration_ms, triggered_sliding_window_threshold=0.1):
    padding_duration_ms = frame_duration_ms * 10
    #print("detecting segments")
    num_padding_frames = int(padding_duration_ms / frame_duration_ms)
    ring_buffer = collections.deque(maxlen=num_padding_frames)
    triggered = False
    def makeseg(voiced_frames): return b''.join(voiced_frames)
    voiced_frames = []
    for frame in (audio[offset:offset + frame_bytes] for offset in range(0, len(audio), frame_bytes) if offset + frame_bytes < len(audio)):
        is_speech = vad.is_speech(frame, sample_rate)
        if not triggered:
            ring_buffer.append((frame, is_speech))
            num_voiced = len([f for f, speech in ring_buffer if speech])
            #print(num_voiced, triggered_sliding_window_threshold * ring_buffer.maxlen)
            if num_voiced > triggered_sliding_window_threshold * ring_buffer.maxlen:
                #print("TRIGGERIN")
                triggered = True
                for f, s in ring_buffer:
                    voiced_frames.append(f)
                ring_buffer.clear()
        else:
            voiced_frames.append(frame)
            ring_buffer.append((frame, is_speech))
            num_unvoiced = len([f for f, speech in ring_buffer if not speech])
            # print("UNVOICE",is_speech,num_unvoiced,triggered_sliding_window_threshold * ring_buffer.maxlen)
            if num_unvoiced > triggered_sliding_window_threshold * ring_buffer.maxlen:
                # print("TRIGGERIN UNVOICE")
                triggered = False
                yield makeseg(voiced_frames)
                ring_buffer.clear()
                voiced_frames = []
    if triggered:
        pass
    if voiced_frames:
        yield makeseg(voiced_frames)

if __name__ == '__main__':
    file=args.input_file
    if file.endswith(('.wav', '.WAV', 'm4a', 'ogg','.mp3')):
        sample_rate, audio = 16000, subprocess.check_output(['ffmpeg', '-loglevel', 'fatal', '-hide_banner', '-nostats', '-nostdin','-i', file, '-ar', '16000', '-f', 's16le', '-acodec', 'pcm_s16le', '-ac', '1', '-vn', '-'], stderr=subprocess.DEVNULL)
        frame_bytes = int(2 * sample_rate * (args.frame_duration_ms / 1000.0))
        segments = detect_voice_segments(webrtcvad.Vad(args.aggressive), audio, sample_rate, frame_bytes, args.frame_duration_ms)
        file_id=0
        for i, segment in enumerate(segments):
            #print(len(segment) / (2 * sample_rate), args.min_segment_duration)
            if len(segment) / (2 * sample_rate) > args.min_segment_duration:
                #segment_wav=os.path.join(Path(file).stem+"-"+str(file_id)+".wav")
                segment_wav=os.path.join(str(Path(file))+"-"+str(file_id)+".wav")
                #print(segment_wav)
                subprocess.Popen(['ffmpeg', '-loglevel', 'debug', '-hide_banner', '-nostats', '-nostdin', '-y', '-f', 's16le', '-ar', '16000', '-ac', '1', '-i', '-', '-vn', '-ar', '16000', '-ac', '1',segment_wav],stdin=subprocess.PIPE,stderr=subprocess.DEVNULL).communicate(segment)

                ws = websocket.WebSocket(sslopt={"cert_reqs": ssl.CERT_NONE})
                ws.connect("wss://"+args.host+":8080/hmpl/"+args.scorer+"/UNK/"+args.voice+"/"+args.language+"/0/0")
                with open(segment_wav, mode='rb') as wav_file:  # b is important -> binary
                    audio = wav_file.read()
                    ws.send_binary(audio)
                    result =  ws.recv()
                    ws.close()
                    response=json.loads(result)
                    print(response['text'])
                file_id=file_id+1
