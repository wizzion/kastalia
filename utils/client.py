import websocket,sys,ssl
mikroserver_host=sys.argv[1]
scorer=sys.argv[2]
human=sys.argv[3]
language=sys.argv[4]
segment_wav=sys.argv[5]
ws = websocket.WebSocket(sslopt={"cert_reqs": ssl.CERT_NONE})
ws.connect("wss://"+mikroserver_host+":8080/hmpl/"+scorer+"/UNK/"+human+"/"+language+"/0/0")
with open(segment_wav, mode='rb') as file:  # b is important -> binary
    audio = file.read()
    ws.send_binary(audio)
    result =  ws.recv()
    print(result) 

