package tink.sql.format;

import haxe.io.Bytes;
import tink.sql.Format;

using DateTools;
using StringTools;
using tink.CoreApi;

class SqlServerSanitizer implements Sanitizer {
  
  public function new() {}
  
  public function value(v:Any):String 
    return
      if(v == null) 'NULL';
      else if(Std.is(v, String)) string(v) 
      else if(Std.is(v, Bool)) (v:Bool) ? '1' : '0';
      else if(Std.is(v, Bytes)) '0x' + (v:Bytes).toHex();
      else if(Std.is(v, Date)) 'DATEADD(S, ${(v:Date).getTime()/1000}, \'1970-01-01\')';
      else Std.string(v);
  
  public function ident(s:String):String {
    var buf = new StringBuf();
    
    buf.addChar('['.code);
      
    for (c in 0...s.length) 
      switch s.fastCodeAt(c) {
        case ']'.code: buf.addChar(']'.code); buf.addChar(']'.code);
        case v: buf.addChar(v);
      }
      
    buf.addChar(']'.code);
    
    return buf.toString();
  }
  
  public function string(s:String):String {
    var buf = new StringBuf();
    
    buf.addChar('\''.code);
    
    for (c in 0...s.length) 
      switch s.fastCodeAt(c) {
        // case '\t'.code: buf.add('\' + CHAR(${'\t'.code}) + \'');
        // case '\n'.code: buf.add('\' + CHAR(${'\n'.code}) + \'');
        // case '\r'.code: buf.add('\' + CHAR(${'\r'.code}) + \'');
        case '\''.code: buf.add('\'\'');
        case v: buf.addChar(v);
      }
      
    buf.addChar('\''.code);  
    
    return buf.toString();
  }
  
}