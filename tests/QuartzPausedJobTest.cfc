/**
 * LDEV-6785: a job with "pause": true must never fire. Its trigger has to be paused in the moment it is
 * stored, not paused in a second step: in between, the scheduler thread of this node or of any other node
 * on the same store can acquire and fire it. QuartzPauseStoreProbe records the state of every stored
 * trigger and holds the storing thread for STORE_DELAY ms, so a trigger stored as runnable fires.
 *
 * The Redis specs need a Redis server: REDIS_SERVER (and optionally REDIS_PORT) must be set, like the CI service does.
 */
component extends="org.lucee.cfml.test.LuceeTestCase" labels="quartz" {

	variables.JOB = "org.lucee.extension.quartz.example.SimpleJobExample";
	variables.PROBE = "testAdditional.QuartzPauseProbe";
	variables.EVERY_SECOND = "* * * ? * *";
	variables.FAR_FUTURE = "0 0 0 1 1 ? 2099";
	variables.STORE_DELAY = 3000;

	function run( testResults, testBox ) {

		describe( "LDEV-6785 a paused job never fires", function() {

			beforeEach( function() {
				variables.instances = [];
				variables.files = [];
			} );
			afterEach( function() {
				stopAll();
				loop array=variables.files item="local.file" {
					if ( fileExists( file ) ) fileDelete( file );
				}
			} );

			it( "stores a paused job that a reload adds to a running scheduler as paused", function() {
				var t = newTest();
				var q = startNode( t, [] );

				rewrite( q, [ cronJob( t.paused, variables.EVERY_SECOND, true ) ] );
				q.loadConfig();
				sleep( 1500 );

				expect( storedStates( t ) ).toBe( [ triggerName( t.paused, variables.EVERY_SECOND ) & " PAUSED" ] );
				expect( executions( t, t.paused ) ).toBe( 0 );
				expect( q.getTriggerStateOf( t.paused ) ).toBe( "PAUSED" );
			} );

			it( "stores the new trigger of a paused job whose schedule a reload changes as paused", function() {
				var t = newTest();
				var q = startNode( t, [ cronJob( t.paused, variables.FAR_FUTURE, true ) ] );
				expect( q.getTriggerStateOf( t.paused ) ).toBe( "PAUSED" );

				rewrite( q, [ cronJob( t.paused, variables.EVERY_SECOND, true ) ] );
				q.loadConfig();
				sleep( 1500 );

				expect( storedStates( t ) ).toBe( [
					triggerName( t.paused, variables.FAR_FUTURE ) & " PAUSED",
					triggerName( t.paused, variables.EVERY_SECOND ) & " PAUSED"
				] );
				expect( executions( t, t.paused ) ).toBe( 0 );
				expect( q.getTriggers().len() ).toBe( 1 );
				expect( q.getTriggerStateOf( t.paused ) ).toBe( "PAUSED" );
			} );

			it( "does not store the trigger of an unchanged paused job again on reload", function() {
				var t = newTest();
				var q = startNode( t, [ cronJob( t.paused, variables.FAR_FUTURE, true ) ], 0 );
				var stored = storedStates( t ).len();

				touch( q );
				q.loadConfig();

				expect( storedStates( t ).len() ).toBe( stored );
				expect( q.getTriggerStateOf( t.paused ) ).toBe( "PAUSED" );
			} );

			it( "does not store the trigger again on reload after the job was paused through the scheduler", function() {
				var t = newTest();
				var q = startNode( t, [ cronJob( t.paused, variables.FAR_FUTURE, false ) ], 0 );
				expect( q.getTriggerStateOf( t.paused ) ).toBe( "NORMAL" );

				q.pauseJob( t.paused, "cfm" );
				// pauseJob() writes the state to the config file
				expect( deserializeJSON( fileRead( q.getConfigFile() ) ).jobs[ 1 ].pause ).toBeTrue();
				var stored = storedStates( t ).len();

				touch( q );
				q.loadConfig();

				expect( storedStates( t ).len() ).toBe( stored );
				expect( q.getTriggerStateOf( t.paused ) ).toBe( "PAUSED" );
			} );

			it( "resumes and pauses again a job that was loaded paused, and keeps that state over reloads", function() {
				var t = newTest();
				var q = startNode( t, [ cronJob( t.paused, variables.FAR_FUTURE, true ) ], 0 );
				expect( q.getTriggerStateOf( t.paused ) ).toBe( "PAUSED" );

				q.resumeJob( t.paused, "cfm" );
				expect( q.getTriggerStateOf( t.paused ) ).toBe( "NORMAL" );
				expect( deserializeJSON( fileRead( q.getConfigFile() ) ).jobs[ 1 ].pause ).toBeFalse();
				touch( q );
				q.loadConfig();
				expect( q.getTriggerStateOf( t.paused ) ).toBe( "NORMAL" );
				expect( q.getTriggers().len() ).toBe( 1 );

				q.pauseJob( t.paused, "cfm" );
				expect( q.getTriggerStateOf( t.paused ) ).toBe( "PAUSED" );
				touch( q );
				q.loadConfig();
				expect( q.getTriggerStateOf( t.paused ) ).toBe( "PAUSED" );
				expect( q.getTriggers().len() ).toBe( 1 );
				expect( q.exportJobs()[ 1 ].pause ).toBeTrue();
			} );

			it( "resumes all jobs, also the ones that were loaded paused", function() {
				var t = newTest();
				var q = startNode( t, [ cronJob( t.paused, variables.FAR_FUTURE, true ) ], 0 );
				expect( q.getTriggerStateOf( t.paused ) ).toBe( "PAUSED" );

				q.pauseAllJobs();
				q.resumeAllJobs();

				expect( q.getTriggerStateOf( t.paused ) ).toBe( "NORMAL" );
				expect( q.getTriggers().len() ).toBe( 1 );
			} );

			it( title="does not fire a paused job that one node adds while another node runs (Redis store)", skip=!hasRedis(), body=function() {
				var t = newTest( true );
				var heartbeat = intervalJob( t.heartbeat, 1, false );
				var a = startNode( t, [ heartbeat ] );
				var b = startNode( t, [ heartbeat ] );

				rewrite( b, [ heartbeat, cronJob( t.paused, variables.EVERY_SECOND, true ) ] );
				b.loadConfig();
				sleep( 1500 );

				expect( storedStates( t ) ).toInclude( triggerName( t.paused, variables.EVERY_SECOND ) & " PAUSED" );
				expect( executions( t, t.heartbeat ) ).toBeGT( 0, "the nodes did not run the heartbeat job" );
				expect( executions( t, t.paused ) ).toBe( 0 );
				expect( a.getTriggerStateOf( t.paused ) ).toBe( "PAUSED" );
			} );

			it( title="does not fire a paused job of a node that starts while another node runs (Redis store)", skip=!hasRedis(), body=function() {
				var t = newTest( true );
				var heartbeat = intervalJob( t.heartbeat, 1, false );
				var a = startNode( t, [ heartbeat ] );

				startNode( t, [ heartbeat, cronJob( t.paused, variables.EVERY_SECOND, true ) ] );
				sleep( 1500 );

				expect( storedStates( t ) ).toInclude( triggerName( t.paused, variables.EVERY_SECOND ) & " PAUSED" );
				expect( executions( t, t.heartbeat ) ).toBeGT( 0, "the nodes did not run the heartbeat job" );
				expect( executions( t, t.paused ) ).toBe( 0 );
				expect( a.getTriggerStateOf( t.paused ) ).toBe( "PAUSED" );
			} );
		} );
	}

	// ---- helpers -----------------------------------------------------------

	private struct function newTest( boolean redis = false ) {
		var id = lCase( createUniqueId() );
		var t = {
			"paused": "paused-" & id,
			"heartbeat": "heartbeat-" & id,
			"events": getTempDirectory() & "quartz-paused-events-" & id & ".txt",
			"stored": getTempDirectory() & "quartz-paused-stored-" & id & ".txt"
		};
		arrayAppend( variables.files, t.events );
		arrayAppend( variables.files, t.stored );
		if ( arguments.redis ) t[ "store" ] = {
			"type": "redis",
			"host": server.system.environment.REDIS_SERVER,
			"port": val( server.system.environment.REDIS_PORT ?: 6379 ),
			"keyPrefix": "QP" & id & "_"
		};
		return t;
	}

	private function startNode( required struct t, required array jobs, numeric storeDelay = variables.STORE_DELAY ) {
		var data = {
			"primary": "file",
			"jobs": arguments.jobs,
			"listeners": [ {
				"component": variables.PROBE,
				"name": "paused-probe",
				"file": arguments.t.events,
				"storeFile": arguments.t.stored,
				"storeDelay": arguments.storeDelay
			} ]
		};
		if ( structKeyExists( arguments.t, "store" ) ) data[ "store" ] = arguments.t.store;
		var path = getTempDirectory() & "quartz-paused-" & createUniqueId() & ".json";
		fileWrite( path, serializeJSON( data ) );
		arrayAppend( variables.files, path );
		var q = new QuartzPauseProxy( path );
		arrayAppend( variables.instances, q );
		q.start();
		expect( q.getState() ).toBe( "running" );
		if ( structKeyExists( arguments.t, "store" ) ) expect( q.getJobStore().getClass().getName() ).toInclude( "RedisJobStore" );
		return q;
	}

	private void function rewrite( required any q, required array jobs ) {
		var path = arguments.q.getConfigFile();
		var data = deserializeJSON( fileRead( path ) );
		data.jobs = arguments.jobs;
		fileWrite( path, serializeJSON( data ) & chr( 10 ) );
	}

	// loadConfig() skips a config file that did not change since it was loaded or written
	private void function touch( required any q ) {
		var path = arguments.q.getConfigFile();
		fileWrite( path, fileRead( path ) & chr( 10 ) );
	}

	private struct function cronJob( required string slug, required string cron, required boolean pause ) {
		return { "label": arguments.slug, "slug": arguments.slug, "component": variables.JOB, "cron": arguments.cron, "pause": arguments.pause };
	}

	private struct function intervalJob( required string slug, required numeric interval, required boolean pause ) {
		return { "label": arguments.slug, "slug": arguments.slug, "component": variables.JOB, "interval": arguments.interval, "pause": arguments.pause };
	}

	private string function triggerName( required string slug, required string cron ) {
		return arguments.slug & " [" & arguments.cron & "]";
	}

	private array function storedStates( required struct t ) {
		if ( !fileExists( arguments.t.stored ) ) return [];
		return listToArray( fileRead( arguments.t.stored ), chr( 10 ) );
	}

	private numeric function executions( required struct t, required string jobName ) {
		if ( !fileExists( arguments.t.events ) ) return 0;
		var count = 0;
		loop list=fileRead( arguments.t.events ) delimiters=chr( 10 ) item="local.line" {
			if ( line == "toBeExecuted " & arguments.jobName ) count++;
		}
		return count;
	}

	private boolean function hasRedis() {
		return len( server.system.environment.REDIS_SERVER ?: "" ) > 0;
	}

	private void function stopAll() {
		var stores = [];
		loop array=variables.instances item="local.q" {
			if ( q.getState() == "running" && q.getJobStore().getClass().getName() contains "RedisJobStore" ) arrayAppend( stores, q );
		}
		// the nodes of a test share one key prefix; clearing it through one node clears it for all
		if ( stores.len() ) stores[ 1 ].getJobStore().clearAllSchedulingData();
		loop array=variables.instances item="local.q" {
			q.stop();
		}
		variables.instances = [];
	}
}
