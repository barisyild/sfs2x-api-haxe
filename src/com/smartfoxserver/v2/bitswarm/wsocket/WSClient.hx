package com.smartfoxserver.v2.bitswarm.wsocket;

#if flash
import flash.utils.Endian;
#elseif openfl
import openfl.utils.Endian;
#else
import com.hurlant.util.Endian;
#end
import haxe.io.Bytes;
import haxe.net.WebSocket;
import com.smartfoxserver.v2.events.EventDispatcher;
import com.smartfoxserver.v2.util.ByteArray;

class WSClient extends EventDispatcher
{
	public var connected(get, never) : Bool;
	public var isDebug(get, set) : Bool;

	private var ws:WebSocket = null;
	private var _debug : Bool = false;
	private var _connected:Bool = false;
	private var _useSSL:Bool = true;

	public function new(debug : Bool = false)
	{
		super();
	}

	private function get_connected() : Bool
	{
		if (ws == null)
		{
			return false;
		}
		return _connected;
	}

	private function get_isDebug() : Bool
	{
		return this._debug;
	}

	private function set_isDebug(value : Bool) : Bool
	{
		this._debug = value;
		return value;
	}

	public var protocol(get, never) : String;

	private function get_protocol():String
	{
		return _useSSL ? "wss://" : "ws://";
	}

	public function connect(url : String, port:Int, useSSL:Bool = false) : Void
	{
		if (connected)
		{
			throw "WebSocket session is already connected";
		}
		_useSSL = useSSL;
		ws = WebSocket.create(protocol + url + ":" + port +"/BlueBox/websocket", null, _debug);
		ws.onopen = function () {
			_connected = true;
			dispatchEvent(new WSEvent(WSEvent.CONNECT, {}));
		};
		ws.onmessageBytes = function(bytes:Bytes) {
			var byteArray:ByteArray = #if flash @:privateAccess bytes.b #else ByteArray.fromBytes(bytes) #end;
			byteArray.endian = Endian.BIG_ENDIAN;
			dispatchEvent(new WSEvent(WSEvent.DATA, {
				data: byteArray
			}));
		};
		ws.onclose = function(?e:Dynamic) {
			_connected = false;
			dispatchEvent(new WSEvent(WSEvent.CLOSED, { }));
			//ws = null;
		};
		ws.onerror = function(error:String) {
			_connected = false;
			var wsEvt : WSEvent = new WSEvent(WSEvent.IO_ERROR, {
				message : error
			});
			dispatchEvent(wsEvt);
			//ws = null;
		};

		#if openfl
			openfl.Lib.current.addEventListener(openfl.events.Event.ENTER_FRAME, onEnterFrame);
		#elseif (target.threaded)
			sys.thread.Thread.create(() -> {
				runThread();
			});
		#elseif python
			var threadOptions:python.lib.threading.Thread.ThreadOptions = {target: runThread};
			var thread = new python.lib.threading.Thread(threadOptions);
			thread.run();
		#end
	}

	private function runThread():Void
	{
		while(true)
		{
			if(ws == null)
				break; //Kill Thread!
			ws.process();
		}
		trace("WebSocket thread died");
	}

	#if openfl
	private function onEnterFrame(e:openfl.events.Event):Void
	{
		//trace("onEnterFrame");
		if(ws != null)
			ws.process();
	}
	#end

	public function send(binData : ByteArray) : Void
	{
		ws.sendBytes(cast binData);
	}

	public function close() : Void
	{
		ws.close();
		_connected = false;
	}
}

