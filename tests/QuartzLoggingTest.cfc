/**
 * LDEV-6662: the extension must not ship log4j 1.x or the slf4j-log4j12 binding, and Quartz's SLF4J
 * logging must resolve to the bundled no-op binding, so startup prints no log4j/SLF4J warnings.
 */
component extends="org.lucee.cfml.test.LuceeTestCase" labels="quartz" {

	variables.FORBIDDEN = [ "log4j:log4j", "org.slf4j:slf4j-log4j12", "com.mchange:c3p0", "com.zaxxer:HikariCP-java7" ];

	function run() {
		describe( "LDEV-6662 Quartz logging dependencies", function() {

			it( "declares no log4j 1.x, slf4j-log4j12 or connection pool dependencies", function() {
				loop array=[ "org.lucee.extension.quartz.Quartz", "org.lucee.extension.quartz.JavaSettings" ] item="local.cfc" {
					var coords = declaredCoords( cfc );
					expect( coords ).toInclude( "org.quartz-scheduler:quartz" );
					expect( coords ).toInclude( "org.slf4j:slf4j-nop" );
					loop array=variables.FORBIDDEN item="local.bad" {
						expect( coords ).notToInclude( bad, "#cfc# still declares #bad#" );
					}
				}
			} );

			it( "binds Quartz's SLF4J to the no-op logger, not log4j", function() {
				var js = javaSettingsOf( "org.lucee.extension.quartz.Quartz" );
				var factory = createObject( "java", "org.slf4j.LoggerFactory", js ).getILoggerFactory();
				expect( factory.getClass().getName() ).toBe( "org.slf4j.helpers.NOPLoggerFactory" );
				expect( function() {
					createObject( "java", "org.apache.log4j.Logger", js );
				} ).toThrow();
			} );
		} );
	}

	private struct function javaSettingsOf( required string cfc ) {
		var md = getComponentMetadata( arguments.cfc );
		var js = md.javaSettings ?: md.javasettings ?: "";
		return isSimpleValue( js ) ? deserializeJSON( js ) : js;
	}

	private string function declaredCoords( required string cfc ) {
		var list = "";
		loop array=javaSettingsOf( arguments.cfc ).maven item="local.m" {
			list = listAppend( list, isSimpleValue( m ) ? listDeleteAt( m, listLen( m, ":" ), ":" ) : m.groupId & ":" & m.artifactId );
		}
		return list;
	}
}
