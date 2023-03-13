package;

import haxe.ui.HaxeUIApp;
import haxe.ui.containers.VBox;
import haxe.ui.events.MouseEvent;

class Main {
   static function main() {
      var app = new HaxeUIApp();
      app.ready(function() {
         app.addComponent(new MainView());
         app.start();
      });
   }
}

@:build(haxe.ui.ComponentBuilder.build('main-view.xml'))
class MainView extends VBox {
   public function new() {
      super();
      button1.onClick = function (e) {button1.text = "thanks!";};
   }

   @:bind(button2, MouseEvent.CLICK)
   private function onMyButton(e:MouseEvent) {
      button2.text = "Thanks!";
   }
}