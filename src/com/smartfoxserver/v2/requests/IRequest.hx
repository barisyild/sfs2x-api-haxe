package com.smartfoxserver.v2.requests;

import com.smartfoxserver.v2.SmartFox;
import com.smartfoxserver.v2.bitswarm.IMessage;

/** @private */
interface IRequest
{
	function validate(sfs:SmartFox):Void;
	function execute(sfs:SmartFox):Void;

	@:flash.property public var targetController(get, set):Int;

	@:flash.property public var isEncrypted(get, set):Bool;
	
	function getMessage():IMessage;
}