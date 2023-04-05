package commands;

interface ICommand {
   // public function getCommandInfo():CommandInfo;
   public function execute(args:Array<String>, flags:Array<String>, options:Map<String, String>):Int;
}

abstract class Command implements ICommand {
   public function new() {}

   // abstract public function getCommandInfo():CommandInfo;

   abstract public function execute(args:Array<String>, flags:Array<String>, options:Map<String, String>):Int;

   public function completions(input:Array<String>):Array<String> {
      return [];
   }
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
      var ?value:String; // used for --thing=path style descriptions
      var ?values:Array<{ // used for listing available values
         var value:String;
         var ?aliases:Array<String>;
         var ?description:String;
      }>;
   }>;
   var ?examples:Array<{
      var usage:String;
      var description:String;
   }>;
}
