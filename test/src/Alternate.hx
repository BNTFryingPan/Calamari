package;

class Alternate {
	static function main() {
		trace('alternate main!');

		#if test_define
		trace('test define!');
		#end
	}
}
