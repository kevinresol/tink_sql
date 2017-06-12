package tink.sql.format;

import haxe.io.Bytes;
import tink.sql.Format;

using StringTools;
using tink.CoreApi;

class SqlServerSanitizer implements Sanitizer {
  
  public function new() {}
  
  public function value(v:Any):String 
    return
      if(Std.is(v, String)) string(v) 
      else if(Std.is(v, Bytes)) '0x' + (v:Bytes).toHex();
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
    /**
     * This is taken from https://github.com/felixge/node-mysql/blob/12979b273375971c28afc12a9d781bd0f7633820/lib/protocol/SqlString.js#L152
     * Writing your own escaping functions is questionable practice, but given that Felix worked with Oracle on this one, I think it should do.
     * 
     * TODO: port these tests too: https://github.com/felixge/node-mysql/blob/master/test/unit/protocol/test-SqlString.js
     * TODO: optimize performance. The current implementation is very naive.
     */
    var buf = new StringBuf();
    
    buf.addChar('\''.code);
    
    for (c in 0...s.length) 
      switch s.fastCodeAt(c) {
        case         0: buf.add('\\0');
        case         8: buf.add('\\b');
        case '\t'.code: buf.add('\\t');
        case '\n'.code: buf.add('\\n');
        case '\r'.code: buf.add('\\r');
        case      0x1a: buf.add('\\Z');
        // case  '"'.code: buf.add('\\"');
        case '\''.code: buf.add('\'\'');
        case '\\'.code: buf.add('\\\\');
        case v: buf.addChar(v);
      }
      
    buf.addChar('\''.code);  
    
    return buf.toString();
  }
  
}