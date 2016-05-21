package tink.sql;


import tink.sql.Expr;
import tink.streams.Stream;
import tink.sql.Table;

using tink.CoreApi;

class Dataset<Fields, Filter, Result:{}, Db> { 
  
  public var fields(default, null):Fields;
  
  var cnx:Connection<Db>;
  var target:Target<Result, Db>;
  var toCondition:Filter->Condition;
  var condition:Null<Condition>;
  
  function new(fields, cnx, target, toCondition, ?condition) { 
    this.fields = fields;
    this.cnx = cnx;
    this.target = target;
    this.toCondition = toCondition;
    this.condition = condition;
  }
  
  macro public function where(ethis, filter:haxe.macro.Expr.ExprOf<Filter>) {
    filter = tink.sql.macros.Filters.makeFilter(ethis, filter);
    return macro @:pos(ethis.pos) @:privateAccess $ethis._where(@:noPrivateAccess $filter);
  }
  
  function _where(filter:Filter):Dataset<Fields, Filter, Result, Db>
    return new Dataset(fields, cnx, target, toCondition, condition && toCondition(filter));
  
  public function stream():Stream<Result>
    return cnx.selectAll(target, condition);
    
  public function all():Surprise<Array<Result>, Error>
    return Future.async(function (cb) {
      var ret = [];
      stream().forEach(function (result) {
        ret.push(result);
        return true;
      }).handle(function (o) cb(o.map(function (_) return ret)));
    });
    
  macro public function leftJoin(ethis, ethat)
    return tink.sql.macros.Joins.perform(Left, ethis, ethat);
    
  macro public function join(ethis, ethat)
    return tink.sql.macros.Joins.perform(Inner, ethis, ethat);

  macro public function rightJoin(ethis, ethat)
    return tink.sql.macros.Joins.perform(Right, ethis, ethat);
    
}

class JoinPoint<Filter, Ret> {
  
  var _where:Filter->Ret;
  
  public function new(applyFilter)
    this._where = applyFilter;
    
  macro public function on(ethis, filter:haxe.macro.Expr.ExprOf<Filter>) {
    filter = tink.sql.macros.Filters.makeFilter(ethis, filter);
    return macro @:pos(ethis.pos) @:privateAccess $ethis._where(@:noPrivateAccess $filter);    
  }
    
}