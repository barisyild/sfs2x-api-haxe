package com.smartfoxserver.v2.test;

import com.smartfoxserver.v2.SmartFox;

class ControllerInjection
{
	var sfs:SmartFox;
	
	public function new()
	{
		sfs=new SmartFox();
		//sfs.kernel::socketEngine.addCustomController(4, new GridController())
	}
}