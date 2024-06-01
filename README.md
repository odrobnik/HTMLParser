This is a replacement for DTHMTLParser contained in [DTFoundation](https://github.com/Cocoanetics/DTFoundation). It is written natively in Swift as a thin wrapper around libxml2's [HTML Parser](https://opensource.apple.com/source/libxml2/libxml2-21/libxml2/doc/html/libxml-HTMLparser.html), which is Apple OpenSource.

There is some C code to deal with a variadic C function for handling parsing errors.

I welcome input and ideas for improvements. For once thing, I am unclear whether it is better to have a delegate protocol, or wether we would want to plug in handler blocks. The problem with handler blocks is that you have to use [weak self] and dereference it in the self which takes even more writing than delegate functions, where the delegate is weak itself.
