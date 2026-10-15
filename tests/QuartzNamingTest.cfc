/**
 * LDEV-6582: readable job and trigger names, duplicate job names in the config
 */
component extends="org.lucee.cfml.test.LuceeTestCase" labels="quartz" {

	variables.COMP = "org.lucee.extension.quartz.example.SimpleJobExample";

	function run( testResults, testBox ) {
		describe( "LDEV-6582 readable job and trigger names", function() {

			beforeEach( function() { variables.instances = []; } );
			afterEach( function() { stopAll(); } );

			it( "uses the slug as job name and builds the trigger name from it", function() {
				var q = startScheduler( { "jobs": [
					{ "label": "Nightly cleanup", "slug": "nightly-cleanup", "component": variables.COMP, "cron": "0 0 0 1 1 ? 2099", "pause": true },
					{ "label": "Ping", "slug": "ping", "url": "/never.cfm", "interval": 3600, "startAt": "2099-01-01", "pause": true }
				] } );
				var names = triggerNames( q );
				expect( names ).toHaveKey( "nightly-cleanup" );
				expect( names[ "nightly-cleanup" ] ).toBe( "nightly-cleanup:0 0 0 1 1 ? 2099" );
				expect( names ).toHaveKey( "ping" );
				expect( names[ "ping" ] ).toBe( "ping:interval:3600" );
			} );

			it( "falls back to the url or the component when there is no slug", function() {
				var q = startScheduler( { "jobs": [
					{ "label": "comp", "component": variables.COMP, "cron": "0 0 0 1 1 ? 2099", "pause": true },
					{ "label": "url", "url": "/never.cfm", "interval": 3600, "startAt": "2099-01-01", "pause": true }
				] } );
				var names = triggerNames( q );
				expect( names ).toHaveKey( variables.COMP );
				expect( names ).toHaveKey( "/never.cfm" );
				expect( names[ "/never.cfm" ] ).toBe( "/never.cfm:interval:3600" );
			} );

			it( "keeps the label in the job data", function() {
				var q = startScheduler( { "jobs": [
					{ "label": "Nightly cleanup", "slug": "nightly-cleanup", "component": variables.COMP, "cron": "0 0 0 1 1 ? 2099", "pause": true }
				] } );
				expect( q.getJobs()[ 1 ].getJobDataMap().get( "label" ) ).toBe( "Nightly cleanup" );
			} );

			it( "keeps the first of two jobs with the same name, also after a reload", function() {
				var cfg = { "jobs": [
					{ "label": "first", "slug": "same", "component": variables.COMP, "cron": "0 0 0 1 1 ? 2099", "pause": true },
					{ "label": "second", "slug": "same", "component": variables.COMP, "cron": "0 0 0 2 1 ? 2099", "pause": true }
				] };
				var q = startScheduler( cfg );
				expect( q.getState() ).toBe( "running" );
				expect( q.getJobs().len() ).toBe( 1 );
				expect( q.getJobs()[ 1 ].getJobDataMap().get( "label" ) ).toBe( "first" );

				reload( q, cfg );
				expect( q.getJobs().len() ).toBe( 1 );
				expect( q.getJobs()[ 1 ].getJobDataMap().get( "label" ) ).toBe( "first" );
			} );

			it( "replaces jobs with the old hashed names on reload (primary file)", function() {
				var cfg = { "jobs": [
					{ "label": "Nightly cleanup", "slug": "nightly-cleanup", "component": variables.COMP, "cron": "0 0 0 1 1 ? 2099", "pause": true }
				] };
				var q = new QuartzNamingProxy( tmpConfig( cfg ) );
				arrayAppend( variables.instances, q );
				q.start();
				q.useLegacyNames();
				expect( triggerNames( q ) ).notToHaveKey( "nightly-cleanup" );

				reload( q, cfg );
				var names = triggerNames( q );
				expect( structCount( names ) ).toBe( 1 );
				expect( names ).toHaveKey( "nightly-cleanup" );
				expect( q.getTriggers().len() ).toBe( 1 );
				// the config file still holds the job
				expect( deserializeJSON( fileRead( q.getConfigFile() ) ).jobs.len() ).toBe( 1 );
			} );
		} );
	}

	// job name -> trigger name
	private struct function triggerNames( required any q ) {
		var names = structNew( "casesensitive" );
		loop array=arguments.q.getTriggers() item="local.t" {
			names[ t.getJobKey().getName() ] = t.getKey().getName();
		}
		return names;
	}

	// loadConfig() skips a file that did not change, so write the same jobs with a new marker
	private void function reload( required any q, required struct cfg ) {
		var data = duplicate( arguments.cfg );
		data[ "comment" ] = createUUID();
		fileWrite( arguments.q.getConfigFile(), serializeJSON( data ) );
		arguments.q.loadConfig();
	}

	private string function tmpConfig( required struct data ) {
		var path = getTempDirectory() & "quartz-naming-" & createUniqueId() & ".json";
		fileWrite( path, serializeJSON( arguments.data ) );
		return path;
	}

	private function startScheduler( required struct data ) {
		var q = new org.lucee.extension.quartz.Quartz( tmpConfig( arguments.data ) );
		arrayAppend( variables.instances, q );
		q.start();
		return q;
	}

	private void function stopAll() {
		loop array=variables.instances ?: [] item="local.q" {
			try { q.stop(); } catch ( any e ) {}
		}
		variables.instances = [];
	}
}
