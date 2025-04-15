component extends="org.lucee.cfml.test.LuceeTestCase" {
	
	function run( testResults , testBox ) {
		
		describe( title="Empty test because the test suite need a test case to run",skip=true, body=function() {
			it(title="can be removed in case we have test cases", skip=true, body = function( currentSpec ) {
			});
		});
	}


}