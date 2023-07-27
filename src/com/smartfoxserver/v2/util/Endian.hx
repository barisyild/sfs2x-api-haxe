package com.smartfoxserver.v2.util;

#if flash
typedef Endian = flash.utils.Endian;
#elseif openfl
typedef Endian = openfl.utils.Endian;
#else
typedef Endian = com.hurlant.util.Endian;
#end