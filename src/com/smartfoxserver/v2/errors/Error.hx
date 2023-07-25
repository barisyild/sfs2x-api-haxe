package com.smartfoxserver.v2.errors;
class Error extends haxe.Exception {
    public var errorID (default, null):Int;
    public var name:String;


    public function new (message:String = "", id:Int = 0) {
        super(message);
        this.errorID = id;
        this.name = "Error";
    }

    override public function toString()
    {
        return "[" + name + "]: " + message + " (" + errorID + ")";
    }
}
