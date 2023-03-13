package;

/**
   abstracts file io away from the main command.
**/
class FileManager {
   static function getUserHomeFolder():String {
      switch Calamari2.host {
         case Linux:
            return '~/';
         case Windows:
            return 
      }
   }

   public static function exists(path:String):Bool {
      #if 
   }
}