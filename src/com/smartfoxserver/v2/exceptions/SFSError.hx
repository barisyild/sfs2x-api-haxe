package com.smartfoxserver.v2.exceptions;

import com.smartfoxserver.v2.errors.Error;

/** @private */
class SFSError extends Error
{
	private var _details:String;

	public function new(message:String, errorId:Int=0, extra:String=null)
	{
		super(message, errorId);
		_details=extra;
	}

	public function details():String
	{
		return _details;
	}
}