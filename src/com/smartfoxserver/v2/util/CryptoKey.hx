package com.smartfoxserver.v2.util;
import com.smartfoxserver.v2.util.ByteArray;

/**
 * ...
 * @author vincent blanchet
 */
class CryptoKey
{
	@:flash.property public var iv(get, null):ByteArray;
	@:flash.property public var key(get, null):ByteArray;
	public function new(iv:ByteArray, key:ByteArray) 
	{
		this.iv = iv;
		this.key = key;	
	}
	
	function get_iv():ByteArray 
	{
		return iv;
	}
	
	function get_key():ByteArray 
	{
		return key;
	}
	
}