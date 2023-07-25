# You can download latest sfs2x.py from releases

import sfs2x

def onConnection(e):
    print("onConnection")
    sfs.send(sfs2x.com_smartfoxserver_v2_requests_LoginRequest("Guest#123456789","","BasicExamples"));

def onLogin(e):
    print("onLogin")
    sfs.send(sfs2x.com_smartfoxserver_v2_requests_JoinRoomRequest("The Lobby"));

def onRoomJoin(e):
    print("onRoomJoin")
    sfs.send(sfs2x.com_smartfoxserver_v2_requests_PublicMessageRequest("PublicMessageRequest test!"));

def onPublicMessage(e):
    print("onPublicMessage")
    user = e.params.sender;
    message = e.params.message;
    print(user.name, message);

sfs = sfs2x.com_smartfoxserver_v2_SmartFox()
sfs.addEventListener(sfs2x.com_smartfoxserver_v2_core_SFSEvent.CONNECTION, onConnection)
sfs.addEventListener(sfs2x.com_smartfoxserver_v2_core_SFSEvent.LOGIN, onLogin)
sfs.addEventListener(sfs2x.com_smartfoxserver_v2_core_SFSEvent.ROOM_JOIN, onRoomJoin)
sfs.addEventListener(sfs2x.com_smartfoxserver_v2_core_SFSEvent.PUBLIC_MESSAGE, onPublicMessage)
sfs.connect("127.0.0.1", 9933)