package tink.sql.drivers;

typedef PostgreSqlSettings = {
  @:optional var host(default, null):String;
  @:optional var port(default, null):Int;
  @:optional var user(default, null):String;
  @:optional var password(default, null):String;
}
