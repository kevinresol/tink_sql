package tink.sql.format;

import tink.sql.Expr;
import tink.sql.Info;
import tink.sql.Format;


class SqlServerFormat {
	
	public function new() {}
	
	function binOp(o:BinOp<Dynamic, Dynamic, Dynamic>) 
		return switch o {
			case Add: '+';
			case Subt: '-';
			case Mult: '*';
			case Div: '/';
			case Mod: 'MOD';
			case Or: 'OR';
			case And: 'AND ';
			case Equals: '=';
			case Greater: '>';
			case Like: 'LIKE';
			case In: 'IN';
		}
		
	function unOp(o:UnOp<Dynamic, Dynamic>)
		return switch o {
			case Not: 'NOT';
			case Neg: '-';      
		}
		
	public function expr<A>(e:Expr<A>):{sql:String, params:Array<{name:String, type:Dynamic, value:Dynamic}>} {
		var params = [];
		
		function addParam(type:Dynamic, value:Dynamic) {
			var name = 'arg' + params.length;
			params.push({name: name, type: type, value: value});
			return name;
		}
		
		inline function isEmptyArray(e:ExprData<Dynamic>)
		return e.match(EValue([], VArray(_)));
		
		function rec(e:ExprData<Dynamic>) {
			return
				switch e {
					case EUnOp(op, a):
						unOp(op) + ' ' + rec(a);
					case EBinOp(In, a, b) if(isEmptyArray(b)): // workaround haxe's weird behavior with abstract over enum
						'@' + addParam(/*NativeTypes.Bit*/ null, false);
					case EBinOp(op, a, b):
						'(${rec(a)} ${binOp(op)} ${rec(b)})';
					case ECall(name, args):
						'$name(${[for(arg in args) rec(arg)].join(',')})';
					case EField(table, name):
						'"$table"."$name"';
					case EValue(v, VBool):
						'@' + addParam(/*NativeTypes.Bit*/ null, v);
					case EValue(v, VString):
						'@' + addParam(/*NativeTypes.VarChar*/ null, v);
					case EValue(v, VInt):
						'@' + addParam(/*NativeTypes.Int*/ null, v);
					case EValue(v, VFloat):
						'@' + addParam(/*NativeTypes.Float*/ null, v);
					case EValue(v, VDate):
						'@' + addParam(/*NativeTypes.DateTime*/ null, v);
					case EValue(bytes, VBytes):
						'@' + addParam(/*NativeTypes.VarBinary*/ null, js.node.Buffer.hxFromBytes(bytes));
					case EValue(geom, VGeometry(Point)):
						throw 'not implemented';
					case EValue(geom, VGeometry(_)):
						throw 'not implemented';
					case EValue(value, VArray(VBool)):
						'(' + [for(v in value) rec(EValue(v, VBool))].join(', ') + ')';
					case EValue(value, VArray(VInt)):          
						'(' + [for(v in value) rec(EValue(v, VInt))].join(', ') + ')';
					case EValue(value, VArray(VFloat)):          
						'(' + [for(v in value) rec(EValue(v, VFloat))].join(', ') + ')';
					case EValue(value, VArray(VString)):          
						'(' + [for(v in value) rec(EValue(v, VString))].join(', ') + ')';
					case EValue(_, VArray(_)):          
						throw 'Only arrays of primitive types are supported';
					}
		}
		
		return {
			sql: rec(e),
			params: params,
		}
	}
	
	function toValueType(dataType:DataType) {
		return switch dataType {
			case DBool: VBool;
			case DInt(bits, signed, autoIncrement): VInt;
			case DFloat(bits): VFloat;
			case DString(maxLength): VString;
			case DBlob(maxLength): VBytes;
			case DDateTime: VDate;
			case DPoint: VGeometry(Point);
		}
	}
	
	public function insert<Row:{}>(table:TableInfo<Row>, rows:Array<Insert<Row>>, s:Sanitizer) {
		return
			'INSERT INTO ${s.ident(table.getName())} (${[for (f in table.fieldnames()) s.ident(f)].join(", ")}) VALUES ' +
				[for (row in rows) '(' + table.sqlizeRow(row, s.value).join(', ') + ')'].join(', ');
	}
	
	public function selectAll<A:{}, Db>(t:Target<A, Db>, ?c:Condition, s:Sanitizer, ?limit:Limit)         
		return select(t, '*', c, s, limit);

	function select<A:{}, Db>(t:Target<A, Db>, what:String, ?c:Condition, s:Sanitizer, ?limit:Limit) {
		var sql = 'SELECT $what FROM ' + Format.target(t, s);
		
		var query = null;
		if (c != null) {
			query = expr(c);
			sql += ' WHERE ' + query.sql;
		}
		
		if (limit != null) 
		sql += 'LIMIT ${limit.limit} OFFSET ${limit.offset}';
		
		return {
			sql: sql,
			params: query == null ? [] : query.params,
		}
	}
}