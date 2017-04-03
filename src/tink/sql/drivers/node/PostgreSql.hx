package tink.sql.drivers.node;

import tink.streams.Accumulator;
import tink.streams.Stream;
import tink.sql.Connection;
import tink.sql.Limit;
import tink.sql.Expr;
import tink.sql.Format;
import tink.sql.Info;
import tink.sql.types.*;

using tink.CoreApi;

class PostgreSql implements Driver {
	var settings:Dynamic;
	
	public function new(settings) {
		this.settings = settings;
	}
	
	public function open<Db:DatabaseInfo>(name:String, db:Db):Connection<Db> {
		var client = new PgClient();
		client.connect(function(e){});
		return new PostgreSqlConnection(db, client);
	} 
}

class PostgreSqlConnection<Db:DatabaseInfo> implements Connection<Db> implements Sanitizer {
	
	var client:PgClient;
	var db:Db;
	
	public function new(db, client) {
		this.db = db;
		this.client = client;
	}
	
	public function value(v:Any):String
		return PgEscape.literal(v);
		
	public function ident(s:String):String
		return PgEscape.ident(s);
	
	public function selectAll<A:{}>(t:Target<A, Db>, ?c:Condition, ?limit:Limit):Stream<A> {
		var accumulator = new Accumulator<A>();
		var query = client.query(Format.selectAll(t, c, this));
		query.on('row', function(row:A) accumulator.yield(Data(row)));
		query.on('error', function(e:js.Error) accumulator.yield(Fail(Error.withData(e.message, e))));
		query.on('end', function() accumulator.yield(End));
		return accumulator;
	}
	
	public function insert<Row:{}>(table:TableInfo<Row>, items:Array<Insert<Row>>):Surprise<Id<Row>, Error> {
		throw 'not implemented';
	}
	
	public function update<Row:{}>(table:TableInfo<Row>, ?c:Condition, ?max:Int, update:Update<Row>):Surprise<{ rowsAffected: Int }, Error> {
		throw 'not implemented';
	}
	
}

@:jsRequire('pg-escape')
private extern class PgEscape {
	static function literal(v:Dynamic):String;
	static function ident(v:String):String;
}

@:jsRequire('pg', 'Client')
private extern class PgClient {
	function new();
	function connect(cb:Dynamic->Void):Void;
	function query<T>(query:String, ?cb:js.Error->T->Void):PgQuery<T>;
}
private extern class PgQuery<T> extends js.node.events.EventEmitter<PgQuery<T>> {}

private typedef PgSelectResult = {
	command:String,
	rowCount:Int,
	oid:Dynamic,
	rows:Array<Any>,
	fields:Array<{
		name:String,
		tableID:Int,
		columnID:Int,
		dataTypeID:Int,
		dataTypeSize:Int,
		dataTypeModifier:Int,
		format:String,
	}>,
	_parsers:Array<Dynamic>,
	rowAsArray:Bool,
}