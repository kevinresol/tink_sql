package;

import tink.sql.types.*;
import tink.sql.drivers.SqlServer;

class Playground {
	static function main() {
		var sql = new SqlServer({
			host: '192.168.0.107',
			user: 'sa',
			password: 'Password123',
		});
		
		var db = new Db('master', sql);
		
		db.test.insertOne({name: 'Ra\'ndom\n' + Std.random(99999), age: Std.random(100)})
			.handle(function(o) switch o {
				case Success(rows): trace(rows); Sys.exit(0);
				case Failure(e): trace(e); Sys.exit(e.code);
			});
		// db.test
		// 	.join(db.location).on(test.name == location.name)
		// 	// .where(test.name == 'Kevin')
		// 	.all()
		// 	.handle(function(o) switch o {
		// 		case Success(rows): trace(rows); Sys.exit(0);
		// 		case Failure(e): trace(e); Sys.exit(e.code);
		// 	});
		
		
	}
}

class Db extends tink.sql.Database {
	@:table var test:TestTable;
	@:table var location:Location;
}

typedef TestTable = {
	var name:Text<255>;
	var age:Integer<255>;
}
typedef Location = {
	var name:Text<255>;
	var location:Text<255>;
}