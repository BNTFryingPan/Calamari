package commands;

class Build extends Command {
	@flag('test', 'wacky')
	var test:Bool;

	@option('opt')
	var opt:String;
	
	var other:String;

	public function run() {
      trace('running build command $opt $test');
   }

	public function getCompletions(input:String):Array<String> {
		return [];
	}

	public function getHelpText():String {
		return 'help text for build command';
	}

	public function getLiteral():String {
		return 'build';
	}
}