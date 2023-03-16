import Calamari.SysTarget;

class Project {
   var file:ProjectFile;

   public function new(file:ProjectFile) {
      this.file = file;
   }

   public function build(target:SysTarget) {}
}
