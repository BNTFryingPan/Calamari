package commands;

import haxe.DynamicAccess;
import haxe.rtti.Meta;
import haxe.rtti.Rtti;

abstract class Command {
   public function new() {
      
   }

   public function init(args:Array<String>, flags:Array<String>, options:Map<String, String>) {
      var meta:DynamicAccess<Dynamic> = Meta.getFields(Type.getClass(this));
      trace(meta);

      for (field => data in meta) {
         trace('info for field $field');
         var d:DynamicAccess<Array<Dynamic>> = data;
         for (type => aliases in d) {
            (type : String);
            switch type {
               case "option":
                  // handle option
                  for (alias in aliases)
                     if (options.exists(alias))
                        Reflect.setField(this, field, options.get(alias));
               case "flag":
                  // handle flag
                  for (alias in aliases)
                     if (flags.contains(alias))
                        Reflect.setField(this, field, true);
               default:
                  // ignore
            }
            //trace(aliases);
            //trace('$type => [${aliases == null ? "" : '"' + aliases.join('", "') + '"'}]');
         }
      }

      this.run();
   }

   public abstract function run():Void;
   public abstract function getCompletions(input:String):Array<String>;
   public abstract function getHelpText():String;
   public abstract function getLiteral():String;
}