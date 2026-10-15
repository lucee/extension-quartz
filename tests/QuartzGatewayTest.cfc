component extends="org.lucee.cfml.test.LuceeTestCase" labels="quartz" {

	function run( testResults, testBox ) {
		describe( "QuartzGateway component", function() {

			it( "compiles and holds the complete DEFAULT_CONFIG (no stray quote ends the string early)", function() {
				var cfg = org.lucee.extension.quartz.QuartzGateway::DEFAULT_CONFIG;
				expect( cfg ).toInclude( '"jobs"' );
				expect( right( trim( cfg ), 1 ) ).toBe( "}" );
			});
		});

		describe( "QuartzGateway config file resolution (LDEV-6460)", function() {

			it( "resolves the config file from the gateway config", function() {
				var path = getTempDirectory() & "ldev6460-" & createUUID() & ".json";
				var resolved = org.lucee.extension.quartz.QuartzGateway::resolveConfigFile( { custom: { configFile: path } } );
				if ( isEmpty( server.system.environment.QUARTZ_CONFIGFILE ?: "" ) ) {
					expect( resolved ).toBe( path );
				}
				else {
					expect( resolved ).toBe( server.system.environment.QUARTZ_CONFIGFILE );
				}
			});

			it( "falls back to a default when no config is given", function() {
				var resolved = org.lucee.extension.quartz.QuartzGateway::resolveConfigFile( {} );
				expect( len( resolved ) ).toBeGT( 0 );
			});

			it( "getState works on an instance that did not run init()", function() {
				var gw = new org.lucee.extension.quartz.QuartzGateway();
				expect( gw.getState() ).toBe( "stopped" );
			});
		});
	}
}
