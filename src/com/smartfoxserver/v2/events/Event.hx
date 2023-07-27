package com.smartfoxserver.v2.events;

#if flash
typedef Event = flash.events.Event;
#elseif openfl
typedef Event = openfl.events.Event;
#else
class Event {
    public var type (default, null):String;
    public var bubbles (default, null):Bool;
    public var cancelable (default, null):Bool;

    public function new (type:String, bubbles:Bool = false, cancelable:Bool = false) {
        this.type = type;
        this.bubbles = bubbles;
        this.cancelable = cancelable;
    }

    public function clone ():Event {
        return new Event (type, bubbles, cancelable);
    }

    public function toString()
    {
        return "[" + type + "]";
    }
}

#end