package tink.sql.drivers.node;

import haxe.DynamicAccess;
import tink.sql.drivers.SqlServerSettings;
import tink.sql.Connection;
import tink.sql.Expr;
import tink.sql.Info;
import tink.sql.Format;
import tink.sql.format.*;
import tink.sql.types.*;
import tink.streams.RealStream;
import tink.streams.Stream;

using tink.CoreApi;

class SqlServer implements Driver {
	var settings:SqlServerSettings;
	
	public function new(settings)
		this.settings = settings;
	
	public function open<Db:DatabaseInfo>(name:String, info:Db):Connection<Db> {
		var cnx = NativeSql.connect({
			user: settings.user,
			password: settings.password,
			server: settings.host,
			database: name,
			// options: {
				port: settings.port,
				// If you're on Windows Azure, you will need this:
				// encrypt: true,
			// },
		});
		return new SqlServerConnection(cnx);
	}
}

class SqlServerConnection<Db:DatabaseInfo> implements Connection<Db> {
	var cnx:Promise<NativeConnection>;
	var sanitizer:Sanitizer = new SqlServerSanitizer();
	var format = new SqlServerFormat();
	
	public function new(cnx) {
		this.cnx = cnx;
	}
	
	// public function value(v:Any):String {
	// 	throw '';
	// }
	
	// public function ident(s:String):String  {
	// 	throw '';
	// }
	
	
	public function dropTable<Row:{}>(table:TableInfo<Row>):Promise<Noise> {
		throw '';
	}
	
	public function createTable<Row:{}>(table:TableInfo<Row>):Promise<Noise> {
		throw '';
	}
	
	public function selectAll<A:{}>(t:Target<A, Db>, ?c:Condition, ?limit:Limit):RealStream<A> {
		
		return Stream.promise(cnx.next(function(cnx):Stream<A, Error> {
			var query = format.selectAll(t, c, sanitizer, limit);
			
			var req = cnx.request();
			req.stream = true;
			for(param in query.params) req = req.input(param.name, param.value);
			
			var signal = Signal.trigger();
			var result = new SignalStream(signal);
			
			req.on('recordset', function(columns) {
				// trace(columns);
			});
			
			
			req.on('row', function(row:DynamicAccess<Dynamic>) {
				if(t.match(TTable(_))) signal.trigger(Data((cast row:A)));
				else {
					var parts = [];
					function extractPart(t:Target<Dynamic, Db>) {
						switch t {
							case TTable(name, _):
								parts.push(name);
							case TJoin(left, right, _, _):
								extractPart(left);
								extractPart(right);
						}
					}
					extractPart(t);
					
					var result = new DynamicAccess();
					
					for(key in row.keys()) {
						var value = row.get(key);
						if(Std.is(value, Array)) {
							row.set(key, value[0]);
						}
					}
					
					// HACK: use the same object for all parts
					// FIXME: because this will screw up reflection
					for(part in parts) result.set(part, row);
					signal.trigger(Data((cast result:A)));
				}
			});
			
			req.on('error', function(err) {
				signal.trigger(Fail(Error.withData(500, err.message, err)));
			});
			
			req.on('done', function(err) {
				signal.trigger(End);
			});
			
			req.query(query.sql);
			
			return result;
		}));
		
	}
	
	public function insert<Row:{}>(table:TableInfo<Row>, items:Array<Insert<Row>>):Promise<Id<Row>>  {
		return cnx.next(function(cnx) {
			var query = format.insert(table, items, sanitizer);
			trace(query);
			return Promise.ofJsPromise(cnx.request().query(query))
				.next(function(v) {
					trace(v);
					return null;
				});
		});
	}
	
	public function update<Row:{}>(table:TableInfo<Row>, ?c:Condition, ?max:Int, update:Update<Row>):Promise<{rowsAffected:Int}> {
		throw '';
	}
	
	public function delete<Row:{}>(table:TableInfo<Row>, ?c:Condition, ?max:Int):Promise<{rowsAffected:Int}> {
		throw '';
	}
	
}

@:jsRequire('mssql')
private extern class NativeSql {
	static var Int:NativeType;
	
	static function connect(config:Dynamic):js.Promise<NativeConnection>;
}
private extern class NativeConnection {
	function request():NativeRequest;
}

private extern class NativeRequest extends js.node.events.EventEmitter<NativeRequest> {
	var stream:Bool;
	@:overload(function(name:String, value:Dynamic):NativeRequest {})
	function input(name:String, type:NativeType, value:Dynamic):NativeRequest;
	function query<T>(sql:String):js.Promise<T>;
}

abstract NativeType(Dynamic) {}