module Series2

extend javascript::Syntax;
import List;

syntax Statement
  = "swap" Id "," Id ";"
  | "test" Expression "should" "be" Expression ";"
  | "foreach" "(" "var" Id "in" Expression ")" Statement
  ;

syntax Expression
  = Id "=\>" Expression
  | "(" {Id ","}* ")" "=\>" "{" Statement* "}"
  ;

syntax Expression = "[" Expression result "|" {Generator ","}+ "]";
  
syntax Generator
  = Expression
  | "var" Id "in" Expression
  ;

keyword Keywords = "swap" | "test" | "foreach";


/*
 * 1. Swap: "swap" Id "," Id ";"
 */
Statement desugar((Statement)`swap <Id x>, <Id y>;`)
	= (Statement)	`(function(){
					'	var tmp = <Id x>;
					'	<Id x> = <Id y>;
					'	<Id y> = tmp;
					'})();`;

test bool testSwap()
  = desugar((Statement)`swap x, y;`)
  == (Statement)`(function() { 
                '   var tmp = x; 
                '   x = y; 
                '   y = tmp; 
                '})();`;
  
  
/*
 * 2. Test: "test" Expression "should" "be" Expression ";"
 */
Statement desugar((Statement)`test <Expression x> should be <Expression y>;`)
	= (Statement)	`(function(actual, expected) {
					'	if(actual !== expected) {
					'		console.log("Test failed; expected: " + expected + "; got: " + actual);
					'	}
					'})(<Expression x>, <Expression y>);`;
  
test bool testTest()
  = desugar((Statement)`test 3 * 3 should be 9;`)
  == (Statement)`(function(actual, expected) { 
  			    '	if (actual !== expected) {
  			    '   	console.log("Test failed; expected: " + expected + "; got: " + actual);    
  			    '   }
  			    '})(3 * 3, 9);`;


/*
 * 3. Foreach:  "foreach" "(" Id "in" Expression ")" Statement
 */
Statement desugar((Statement)`foreach (var <Id x> in <Expression e>) <Statement s>`)
	= (Statement)	`(function(arr) {
					'	for(var i = 0; i \< arr.length; i++) {
					'		var <Id x> = arr[i];
					'		<Statement s>
					'	}
					'})(<Expression e>);`;

test bool testForeach()
  = desugar((Statement)`foreach (var x in [1,2,3]) print(x);`)
  == (Statement)`(function(arr) {
  			    '  for (var i = 0; i \< arr.length; i++) { 
                '    var x = arr[i]; 
                '    print(x);
                '  }
                '})([1, 2, 3]);`;
 
 
/*
 * 4. Arrow functions: Id "=\>" Expression
 */
Expression desugar((Expression)`<Id param> =\> <Expression body>`) 
	= (Expression) `(function(_this){
		'	return function(<Id param>){
		'		return <Expression bodyThis>;
		'	};
		'})(this)`
		when Expression bodyThis := replaceThis(body);


Expression replaceThis(Expression e) {
  return top-down-break visit (e) {
    case Function _ : ; 
    case (Expression)`this` => (Expression)`_this`
  }
}

test bool testArrowNoThis()
  = desugar((Expression)`x =\> (x + 1)`)
  == (Expression)`(function (_this) { 
                 '   return function (x) { 
                 '      return (x + 1); 
                 '   }; 
                 '})(this)`;

test bool testArrowWithThis()
  = desugar((Expression)`x =\> (this.x + 1)`)
  == (Expression)`(function (_this) { 
                 '   return function (x) { 
                 '      return (_this.x + 1); 
                 '   }; 
                 '})(this)`;

 
/*
 * 5. Comprehensions: "[" Expression result "|" {Generator ","}+ "]";
 *    Generator: Expression | Id ":" Expression
 */
Expression desugar((Expression)`[ <Expression r> | <{Generator ","}+ gens> ]`) {
	Statement s := mapGens(r, gens);
	return (Expression)	`(function() {
				'	var result = [];
				'	<Statement s>
				'	return result;	
				'})()`;
} 

Statement mapGens(Expression r, <{Generator ","}+ gens>) {
	list[Generator] reverseGens = reverse([g | g <- gens]);
	Statment s = (Statement) `result.push(<Expression r>);`;
	
	for(int i <- [0 .. size(gens)]){
		s = mapStatement(s, gens[i]);
	}
	
	return s;
}

Statement mapStatement(Statement previous, (Generator) `var <Id id> in <Expression e>`) {
	return (Statement) `{
				'	var coll = <Expression e>;
				'	for(var i = 0; i \< col.length; i++) {
				'		var <Id id> = coll[i];
				'		<Statement previous>
				'	}
				'}`;
}

default Statement mapStatement(Statement previous, (Generator) `<Expression e>`) {
	return (Statement) `if(e){
				'	<Statement previous>
				'}`;
}

Expression dummyExp() = (Expression)`NOT_YET_IMPLEMENTED`;
Statement dummyStat() = (Statement)`NOT_YET_IMPLEMENTED;`;