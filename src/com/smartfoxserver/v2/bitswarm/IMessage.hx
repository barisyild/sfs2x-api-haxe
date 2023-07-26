package com.smartfoxserver.v2.bitswarm;

import com.smartfoxserver.v2.entities.data.ISFSObject;

/** @private */
interface IMessage
{
	@:flash.property var id(get,set):Int;
	@:flash.property var content(get, set):ISFSObject;
	//function get_content():ISFSObject;
	//function set_content(obj:ISFSObject):Void;

	@:flash.property var targetController(get, set):Int;
	//function get_targetController():Int;
	//function set_targetController(value:Int):Void;

	@:flash.property var isEncrypted(get, set):Bool;
	//function get_isEncrypted():Bool;
	//function set_isEncrypted(value:Bool):Void;

	@:flash.property var isUDP(get, set):Bool;
	//function get_isUDP():Bool;
	//function set_isUDP(value:Bool):Void;

	@:flash.property var packetId(get, set):Float;
	//function get_packetId():Float;
	//function set_packetId(value:Float):Void;
}