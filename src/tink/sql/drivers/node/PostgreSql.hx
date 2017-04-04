package tink.sql.drivers.node;

import tink.streams.Accumulator;
import tink.streams.Stream;
import tink.sql.Connection;
import tink.sql.Limit;
import tink.sql.Expr;
import tink.sql.Format;
import tink.sql.Info;
import tink.sql.types.*;
import tink.sql.drivers.*;

using tink.CoreApi;
using StringTools;

class PostgreSql implements Driver {
	var settings:PostgreSqlSettings;
	
	public function new(settings) {
		this.settings = settings;
	}
	
	public function open<Db:DatabaseInfo>(name:String, db:Db):Connection<Db> {
		var client = new PgClient({
			user: settings.user,
			password: settings.password,
			host: settings.host,
			port: settings.port,
			database: name,
		});
		client.connect();
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
	
	public function value(v:Any):String {
		return 
			if(v == null) 'NULL';
			else if(Std.is(v, Bool)) v ? 'true' : 'false';
			else if(Std.is(v, Float)) Std.string(v);
			else if(Std.is(v, Date)) throw 'not implemented';
			else if(Std.is(v, haxe.io.Bytes)) throw 'not implemented'; // as BLOB
			else if(Std.is(v, Array)) throw 'not implemented';
			else if(Std.is(v, String)) "'" + v.replace("'", "''") + "'";
			else throw 'Invalid value $v';
	}
		
		
	public function ident(s:String):String
		return '"$s"';
	
	public function selectAll<A:{}>(t:Target<A, Db>, ?c:Condition, ?limit:Limit):Stream<A> {
		var accumulator = new Accumulator<A>();
		var query = client.query(Format.selectAll(t, c, this));
		query.on('row', function(row:A) accumulator.yield(Data(row)));
		query.on('error', function(e) accumulator.yield(Fail(toError(e))));
		query.on('end', function() accumulator.yield(End));
		return accumulator;
	}
	
	function toError<A>(error:js.Error):Error
		return Error.withData(error.message, error);//TODO: give more information
	
	public function insert<Row:{}>(table:TableInfo<Row>, items:Array<Insert<Row>>):Surprise<Id<Row>, Error> {
		return Future.async(function (cb) {
			client.query(
				Format.insert(table, items, this),
				function (error, result) cb(
					if(error == null)
						Success(new Id(0)) // TODO: get back the id, using the "RETURNING" keyword
					else
						Failure(toError(error))
				)
			);
		});
	}
	
	public function update<Row:{}>(table:TableInfo<Row>, ?c:Condition, ?max:Int, update:Update<Row>):Surprise<{ rowsAffected: Int }, Error> {
		return Future.async(function (cb) {
			client.query(
				Format.update(table, c, max, update, this),
				function (error, result:{rowCount:Int}) cb(
					if(error == null)
						Success({rowsAffected: result.rowCount})
					else
						Failure(toError(error))
				)
			);
		});
	}
	
}

@:jsRequire('pg-escape')
private extern class PgEscape {
	static function literal(v:Dynamic):String;
	static function ident(v:String):String;
}

@:jsRequire('pg', 'Client')
private extern class PgClient {
	function new(?options:Dynamic);
	function connect(?cb:Dynamic->Void):Void;
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