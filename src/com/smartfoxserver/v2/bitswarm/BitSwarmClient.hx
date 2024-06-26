package com.smartfoxserver.v2.bitswarm;

import com.smartfoxserver.v2.bitswarm.socket.SocketEvent;
import com.smartfoxserver.v2.bitswarm.wsocket.WSEvent;
import com.smartfoxserver.v2.bitswarm.wsocket.WSClient;
import com.smartfoxserver.v2.SmartFox;
import com.smartfoxserver.v2.bitswarm.bbox.BBClient;
import com.smartfoxserver.v2.bitswarm.bbox.BBEvent;
import com.smartfoxserver.v2.controllers.ExtensionController;
import com.smartfoxserver.v2.controllers.SystemController;
import com.smartfoxserver.v2.util.ClientDisconnectionReason;
import com.smartfoxserver.v2.util.ConnectionMode;
import com.smartfoxserver.v2.util.CryptoKey;
import com.smartfoxserver.v2.errors.ArgumentError;
import com.smartfoxserver.v2.events.Event;
import com.smartfoxserver.v2.events.EventDispatcher;
import com.smartfoxserver.v2.events.IOErrorEvent;
import com.smartfoxserver.v2.util.ByteArray;

/** @private */
class BitSwarmClient extends EventDispatcher
{
	#if !js
	private var _socket:com.smartfoxserver.v2.bitswarm.socket.SocketClient;
	#end
	private var _wsClient:WSClient;
	private var _bbClient:BBClient;
	private var _ioHandler:IoHandler;
	private var _controllers:Map<Int,IController>;
	private var _compressionThreshold:Int=2000000;
	private var _maxMessageSize:Int = 10000;
	private var _sfs:SmartFox;
	private var _connected:Bool;
	private var _lastIpAddress:String;
	private var _lastTcpPort:Int ;
	private var _reconnectionDelayMillis:Int = 1000;
	private var _reconnectionSeconds:Int = 0;
	private var _attemptingReconnection:Bool = false;
	private var _sysController:SystemController;
	private var _extController:ExtensionController;
	private var _udpManager:IUDPManager;
	private var _controllersInited:Bool = false;
	@:isVar
	public var cryptoKey(get, set):CryptoKey;
	private var _useWebSocket:Bool = false;
	private var _useBlueBox:Bool = false;
	private var _connectionMode:String;
	private var _firstReconnAttempt:Float=-1;
	private var _reconnCounter:Int=1;

	public function new(sfs:SmartFox=null)
	{
		super();

		_controllers = new Map<Int,IController>();
		_sfs = sfs;
		_connected = false;
		_udpManager = new DefaultUDPManager(sfs);
	}

	public var sfs(get, null):SmartFox;

	public var connected(get, null):Bool;

	public var connectionMode(get, never):String;
	private function get_connectionMode():String
	{
		return _connectionMode;
	}

	public var ioHandler(get, set):IoHandler;
 	private function get_ioHandler():IoHandler
	{
		return _ioHandler;
	}

	private function set_ioHandler(value:IoHandler):IoHandler
	{
		//if(_ioHandler !=null)
		//throw new SFSError("IOHandler is already set!")

		return _ioHandler = value;
	}

	public var maxMessageSize(get, set):Int;
	private function get_maxMessageSize():Int
	{
		return _maxMessageSize;
	}

	private function set_maxMessageSize(value:Int):Int
	{
		return _maxMessageSize = value;
	}

	public var compressionThreshold(get, set):Int;
	private function get_compressionThreshold():Int
	{
		return _compressionThreshold;
	}

	/*
	* Avoid compressing data whose size is<100 bytes
	* Ideal default value should be 300 bytes or more...
	*/
	private function set_compressionThreshold(value:Int):Int
	{
		if(value>100)
			return _compressionThreshold = value;
		else
			throw new ArgumentError("Compression threshold cannot be<100 bytes.");
	}

	public var reconnectionDelayMillis(get, set):Int;
	private function get_reconnectionDelayMillis():Int
	{
		return _reconnectionDelayMillis;
	}

	public var useSSL(get, never):Bool;
	private function get_useSSL():Bool
	{
		return sfs.useSSL;
	}

	public var useWebSocket(get, set):Bool;
	private function get_useWebSocket():Bool
	{
		return _useWebSocket;
	}

	private function set_useWebSocket(value:Bool):Bool
	{
		return _useWebSocket = value;
	}

	public var useBlueBox(get, never):Bool;
	private function get_useBlueBox():Bool
	{
		return _useBlueBox;
	}

	public function forceBlueBox(value:Bool):Void
	{
		if(!connected)
			_useBlueBox = value;
		else
			throw "You can't change the BlueBox mode while the connection is running";
	}

	private function set_reconnectionDelayMillis(millis:Int):Int
	{
		return _reconnectionDelayMillis = millis;
	}

	public function enableBBoxDebug(value:Bool):Void
	{
		_bbClient.isDebug = value;
	}

	public function init():Void
	{
		// Do it once
		if(!_controllersInited)
		{
			initControllers();
			_controllersInited = true;
		}

		#if !js
		_socket = new com.smartfoxserver.v2.bitswarm.socket.SocketClient();

		//if(_socketClient.hasOwnProperty("timeout"))// condition required to avoide FP<10.0 to throw an error at runtime
			//_socketClient.timeout = 5000;

		_socket.addEventListener(SocketEvent.CONNECT, onSocketConnect);
		_socket.addEventListener(SocketEvent.DATA, onSocketData);
		_socket.addEventListener(SocketEvent.CLOSED, onSocketClose);
		_socket.addEventListener(SocketEvent.IO_ERROR, onSocketIOError);
		_socket.addEventListener(SocketEvent.SECURITY_ERROR, onSocketSecurityError);
		#end

		_bbClient = new BBClient();
		_bbClient.addEventListener(BBEvent.CONNECT, onBBConnect);
		_bbClient.addEventListener(BBEvent.DATA, onBBData);
		_bbClient.addEventListener(BBEvent.DISCONNECT, onBBDisconnect);
		_bbClient.addEventListener(BBEvent.IO_ERROR, onBBError);
		_bbClient.addEventListener(BBEvent.SECURITY_ERROR, onBBError);

		_wsClient = new WSClient();
		_wsClient.addEventListener(WSEvent.CONNECT, this.onWSConnect);
		_wsClient.addEventListener(WSEvent.DATA, this.onWSData);
		_wsClient.addEventListener(WSEvent.CLOSED, this.onWSClose);
		_wsClient.addEventListener(WSEvent.IO_ERROR, this.onWSError);
		_wsClient.addEventListener(WSEvent.SECURITY_ERROR, this.onWSSecurityError);
	}

	private function onWSConnect(evt : WSEvent) : Void
	{
		processConnect();
	}

	private function onWSData(evt : WSEvent) : Void
	{
		var buffer : ByteArray = evt.params.data;
		if (buffer != null)
		{
			processData(buffer);
		}
	}

	private function onWSClose(evt : WSEvent) : Void
	{
		if (Std.isOfType(evt, BitSwarmEvent)) {
			var evt : BitSwarmEvent = cast evt;
			processClose(evt.params.reason == ClientDisconnectionReason.MANUAL, evt);
		} else {
			processClose(false);
		}
	}

	private function onWSError(evt : WSEvent) : Void
	{
		processIOError(evt.params.message);
	}

	private function onWSSecurityError(evt : WSEvent) : Void
	{
		processSecurityError(evt.params.message);
	}

	public function destroy():Void
	{
		#if !js
		_socket.removeEventListener(SocketEvent.CONNECT, onSocketConnect);
		_socket.removeEventListener(SocketEvent.CLOSED, onSocketClose);
		_socket.removeEventListener(SocketEvent.DATA, onSocketData);
		_socket.removeEventListener(SocketEvent.IO_ERROR, onSocketIOError);
		_socket.removeEventListener(SocketEvent.SECURITY_ERROR, onSocketSecurityError);

		if(_socket.connected)
			_socket.close();

		_socket = null;
		#end
	}

	public function getController(id:Int):IController
	{
		return _controllers.get(id);
	}

	public var systemController(get, null):SystemController;
	private function get_systemController():SystemController
	{
		return _sysController;
	}

	public var extensionController(get, null):ExtensionController;
	private function get_extensionController():ExtensionController
	{
		return _extController;
	}

	public var isReconnecting(get, set):Bool;
	private function get_isReconnecting():Bool
	{
		return _attemptingReconnection;
	}

	private function set_isReconnecting(value:Bool):Bool
	{
		return _attemptingReconnection = value;
	}

	public function getControllerById(id:Int):IController
	{
		return _controllers.get(id);
	}

	public var connectionIp(get, null):String;
	private function get_connectionIp():String
	{
		if(!connected)
			return "Not Connected";
		else
			return _lastIpAddress;
	}
	@:isVar
	public var connectionPort(get, set):Int;


	private function addController(id:Int, controller:IController):Void
	{
		if(controller==null)
			throw new ArgumentError("Controller is null, it can't be added.");

		if(_controllers.exists(id))
			throw new ArgumentError("A controller with id:" + id + " already exists! Controller can't be added:" + controller);

		_controllers.set(id, controller);
	}

	public function addCustomController(id:Int, controllerClass:Class<IController>):Void
	{
		var controller:IController = Type.createInstance(controllerClass,[this]);
		addController(id, controller);
	}

	public function connect(host:String="127.0.0.1", port:Int=9933):Void
	{
		_lastIpAddress = host;
		_lastTcpPort = port;

		if(_useWebSocket)
		{
			_wsClient.connect(host, port, useSSL);
			_connectionMode = ConnectionMode.WEBSOCKET;
		}
		else if(_useBlueBox)
		{
			_bbClient.pollSpeed=(sfs.config !=null)? sfs.config.blueBoxPollingRate:750;
			_bbClient.connect(host, port);
			_connectionMode = ConnectionMode.HTTP;
		}
		#if !js
		else
		{
			_socket.connect(host, port);
			_connectionMode = ConnectionMode.SOCKET;
		}
		#end
	}

	public function send(message:IMessage):Void
	{
		_ioHandler.codec.onPacketWrite(message);
	}

	#if !js
	public var socket(get, never):com.smartfoxserver.v2.bitswarm.socket.SocketClient;
	#end

	//private function get_socket():Socket
	//{
	//return _socket;
	//}

	public var httpSocket(get , never):BBClient;

	public function get_httpSocket():BBClient
	{
		return _bbClient;
	}

	public var webSocket(get , never):WSClient;

	public function get_webSocket():WSClient
	{
		return _wsClient;
	}

	public function disconnect(reason:String=null):Void
	{
		if(_useBlueBox)
		{
			_bbClient.close();
		}
		#if !js
		else if(socket.connected)
		{
			_socket.close();
		}
		#end
		else if(_wsClient.connected)
		{
			_wsClient.close();
		}

		onSocketClose(new BitSwarmEvent(BitSwarmEvent.DISCONNECT, { reason:reason } ));
	}

	public function nextUdpPacketId():Float
	{
		return _udpManager.nextUdpPacketId();
	}

	/*
	* Simulates abrupt disconnection
	* For testing/simulations only
	*/
	public function killConnection():Void
	{
		if(_useBlueBox)
		{
			_bbClient.close();
		}
		#if !js
		else if(socket.connected)
		{
			_socket.close();
		}
		#end
		else if(_wsClient.connected)
		{
			_wsClient.close();
		}
		onSocketClose(new SocketEvent(SocketEvent.CLOSED));
	}

	public function stopReconnection():Void
	{
		_attemptingReconnection=false;
		_firstReconnAttempt=-1;

		if(_useBlueBox)
		{
			_bbClient.close();
		}
		#if !js
		else if(socket.connected)
		{
			_socket.close();
		}
		#end
		else if(_wsClient.connected)
		{
			_wsClient.close();
		}

		_connected = false;
		executeDisconnection(null);
	}

	public var udpManager(get, set):IUDPManager;
	private function get_udpManager():IUDPManager
	{
		return _udpManager;
	}

	private function set_udpManager(manager:IUDPManager):IUDPManager
	{
		return _udpManager = manager;
	}

	private function initControllers():Void
	{
		_sysController = new SystemController(this);
		_extController = new ExtensionController(this);

		addController(0, _sysController);
		addController(1, _extController);
	}

	public var reconnectionSeconds(get, set):Int;
	private function get_reconnectionSeconds():Int
	{
		return _reconnectionSeconds;
	}

	private function set_reconnectionSeconds(seconds:Int):Int
	{
		if(seconds<0)
			return _reconnectionSeconds = 0;
		else
			return _reconnectionSeconds = seconds;
	}

	//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	// Handler processes
	//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

	private function processConnect():Void
	{
		_connected = true;

		var event:BitSwarmEvent = new BitSwarmEvent(BitSwarmEvent.CONNECT);

		event.params = {
			success: true,
			_isReconnection: _attemptingReconnection // internal
		};

		dispatchEvent(event);
	}

	private function processClose(manual:Bool, ?evt:BitSwarmEvent):Void
	{
		// Connection is off
		_connected = false;

		var isRegularDisconnection:Bool = !_attemptingReconnection && sfs.getReconnectionSeconds() == 0;

		if(isRegularDisconnection || manual)
		{
			// Reset UDP Manager
			_udpManager.reset();
			_firstReconnAttempt=-1;

			executeDisconnection(evt);
			return;
		}

			// Already trying to reconnect...
		else if(_attemptingReconnection)
			reconnect();

			// First reconnection attempt
		else
		{

			/*
			* If we aren't in any of the above three cases then it's time to attempt a
			* reconnection to the server.
			*/
			_attemptingReconnection = true;
			_firstReconnAttempt = haxe.Timer.stamp() * 1000;
			_reconnCounter=1;

			// Fire event and retry
			dispatchEvent(new BitSwarmEvent(BitSwarmEvent.RECONNECTION_TRY));

			reconnect();
		}
	}

	private function reconnect():Void
	{
		if(!_attemptingReconnection)
			return;

		var reconnectionSeconds:Int = sfs.getReconnectionSeconds() * 1000;
		var now:Float = haxe.Timer.stamp() * 1000;
		var timeLeft:Float=(_firstReconnAttempt + reconnectionSeconds)- now;

		if(timeLeft>0)
		{
			sfs.logger.info('Reconnection attempt:$_reconnCounter - time left: ${Std.int(timeLeft/1000)}sec.');

			// Retry connection:pause 1 second and retry
			haxe.Timer.delay(function():Void { connect(_lastIpAddress, _lastTcpPort); }, _reconnectionDelayMillis);
			_reconnCounter++;
		}

		// We are out of time... connection failed:(
		else
		{
			// Do not attempt to reconnect anymore
			_attemptingReconnection = false;
			dispatchEvent(new BitSwarmEvent(BitSwarmEvent.DISCONNECT, {reason:ClientDisconnectionReason.UNKNOWN}));
		}
	}

	private function executeDisconnection(evt:Event):Void
	{
		/*
		* A BitSwarmEvent is passed if the disconnection was requested by the server
		* The event includes a reason for the disconnection(idle, kick, ban...)
		*/
		if(Std.isOfType(evt, BitSwarmEvent))
			dispatchEvent(evt);

			/*
			* Disconnection at socket level
			*/
		else
			dispatchEvent(new BitSwarmEvent(BitSwarmEvent.DISCONNECT, { reason:ClientDisconnectionReason.UNKNOWN } ));
	}

	/**
	@param buffer - Big endian byte array.
	*/
	private function processData(buffer:ByteArray):Void
	{
		try {
			_ioHandler.onDataRead(buffer);
		} catch(error:Dynamic) {
			try {
				trace("## SocketDataError:" + error + " " + error.message);
				trace(haxe.CallStack.toString( haxe.CallStack.exceptionStack()));
				trace(buffer.toString());
				var event:BitSwarmEvent = new BitSwarmEvent(BitSwarmEvent.DATA_ERROR);
				event.params = { message:error.message, details:error.details };
				dispatchEvent(event);
			} catch (e:Dynamic) {
				trace(e);
			}
		}
	}

	private function processIOError(error:String):Void
	{
		// Reconnection failure
		if(_attemptingReconnection)
		{
			reconnect();
			return;
		}

		trace("## SocketError:" + error);
		var event:BitSwarmEvent = new BitSwarmEvent(BitSwarmEvent.IO_ERROR);
		event.params = {
			message: error
		};

		dispatchEvent(event);
	}

	private function processSecurityError(error:String):Void
	{
		// Reconnection failure
		if(_attemptingReconnection)
		{
			reconnect();
			return;
		}

		trace("## SecurityError:" + error);
		var event:BitSwarmEvent = new BitSwarmEvent(BitSwarmEvent.SECURITY_ERROR);
		event.params = {
			message: error
		};

		dispatchEvent(event);
	}

	//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	// Socket handlers
	//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

	private function onSocketConnect(evt:SocketEvent):Void
	{
		processConnect();
	}

	private function onSocketClose(evt:Dynamic):Void
	{
		if (Std.isOfType(evt, BitSwarmEvent)) {
			var evt : BitSwarmEvent = cast evt;
			processClose(evt.params.reason == ClientDisconnectionReason.MANUAL, evt);
		} else {
			processClose(false);
		}
	}


	private function onSocketData(evt:SocketEvent):Void
	{
		var buffer:ByteArray = evt.params.data;
		processData(buffer);
	}

	private function onSocketIOError(evt:SocketEvent):Void
	{
		processIOError(evt.toString());
	}

	private function onSocketSecurityError(evt:SocketEvent):Void
	{
		processSecurityError(evt.toString());
	}

	//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	// BlueBox handlers
	//:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

	private function onBBConnect(evt:BBEvent):Void
	{
		_connected = true;

		var event:BitSwarmEvent = new BitSwarmEvent(BitSwarmEvent.CONNECT);
		event.params = { success:true };

		dispatchEvent(event);
	}

	private function onBBData(evt:BBEvent):Void
	{
		var buffer:ByteArray = evt.params.data;

		if(buffer !=null)
			_ioHandler.onDataRead(buffer);
	}

	private function onBBDisconnect(evt:BBEvent):Void
	{
		// Connection is off
		_connected = false;

		// Fire event
		dispatchEvent(new BitSwarmEvent(BitSwarmEvent.DISCONNECT, { reason:ClientDisconnectionReason.UNKNOWN } ));
	}

	private function onBBError(evt:BBEvent):Void
	{
		trace("## BlueBox Dynamic:" + evt.params.message);
		var event:BitSwarmEvent = new BitSwarmEvent(BitSwarmEvent.IO_ERROR);
		event.params = { message:evt.params.message };

		dispatchEvent(event);
	}

	function get_connectionPort():Int
	{
		if(!connected)
			return -1;
		else
			return _lastTcpPort;
	}

	function set_connectionPort(value:Int):Int
	{
		return connectionPort = value;
	}

	function get_sfs():SmartFox
	{
		return _sfs;
	}

	function get_connected():Bool
	{
		return _connected;
	}

	#if !js
	function get_socket():com.smartfoxserver.v2.bitswarm.socket.SocketClient
	{
		return _socket;
	}
	#end

	function get_cryptoKey():CryptoKey
	{
		return cryptoKey;
	}

	function set_cryptoKey(value:CryptoKey):CryptoKey
	{
		return cryptoKey = value;
	}

}