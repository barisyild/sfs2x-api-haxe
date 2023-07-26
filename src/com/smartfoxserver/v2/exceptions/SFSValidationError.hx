package com.smartfoxserver.v2.exceptions;

import com.smartfoxserver.v2.errors.Error;

/** @private */
class SFSValidationError extends Error
{
	private var _errors:Array<String>;
	
	public function new(message:String, errors:Array<String>, errorId:Int=0)
	{
		super(message, errorId);
		_errors = errors;
	}

	@:flash.property public var errors(get, null):Array<String>;
 	private function get_errors():Array<String>
	{
		return _errors;
	}
}