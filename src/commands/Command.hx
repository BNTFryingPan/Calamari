package commands;

interface ICommand {
   public function getCommandInfo():CommandInfo;
   public function execute(args:Array<String>, flags:Array<String>, options:Map<String, String>):Int;
   public var commandName(get, never):String;
}

abstract class Command implements ICommand {
   public function new() {}

   abstract public function getCommandInfo():CommandInfo;

   abstract public function execute(args:Array<String>, flags:Array<String>, options:Map<String, String>):Int;

   public var commandName(get, never):String;

   abstract function get_commandName():String;
}

typedef CommandInfo = {
   var name:String;
   var ?description:String;
   var shortDescription:String;
   var ?args:Array<{
      var name:String;
      var ?required:Bool;
      var description:String;
   }>;
   var ?flags:Array<{
      var name:String;
      var ?aliases:Array<String>;
      var description:String;
   }>;
   var ?options:Array<{
      var name:String;
      var description:String;
      var ?value:String;
   }>;
   var ?examples:Array<{
      var usage:String;
      var description:String;
   }>;
}
