/**
 * LDEV-6780: a trigger without a JobDetail (orphan in the Redis store) must not break the scheduler,
 * a changed trigger name must not delete the job, and a failing sync() must not leave a running scheduler "failed".
 *
 * The Redis tests need a Redis server: REDIS_SERVER (and optionally REDIS_PORT) must be set, like the CI service does.
 */
component extends="org.lucee.cfml.test.LuceeTestCase" labels="quartz" {

	variables.COMP = "org.lucee.extension.quartz.example.SimpleJobExample";

	function run( testResults, testBox ) {

		describe( "LDEV-6780 orphaned triggers and trigger renames", function() {

			beforeEach( function() { variables.instances = []; variables.redisStores = []; } );
			afterEach( function() { stopAll(); } );

			it( "gives the same trigger name for 36000, '36000' and '36000.0'", function() {
				var q = createObject( "component", "org.lucee.extension.quartz.Quartz" );
				var a = q.triggerName( { "slug": "j", "url": "/x.cfm", "interval": 36000 } );
				var b = q.triggerName( { "slug": "j", "url": "/x.cfm", "interval": "36000" } );
				var c = q.triggerName( { "slug": "j", "url": "/x.cfm", "interval": "36000.0" } );
				expect( a ).toBe( "j [every 36000s]" );
				expect( b ).toBe( a );
				expect( c ).toBe( a );
				expect( q.triggerName( { "slug": "j", "url": "/x.cfm", "interval": "1.5" } ) ).toBe( "j [every 1.5s]" );
			} );

			it( "keeps the job when a reload changes the trigger name (in-memory store)", function() {
				var q = startScheduler( { "jobs": [ intervalJob( "keep", 3600 ) ] } );
				expect( q.getTriggers().len() ).toBe( 1 );
				expect( q.getTriggers()[ 1 ].getKey().getName() ).toBe( "keep [every 3600s]" );

				rewrite( q, { "jobs": [ intervalJob( "keep", 7200 ) ] } );
				q.loadConfig();

				expect( q.getJobs().len() ).toBe( 1 );
				expect( q.getTriggers().len() ).toBe( 1 );
				expect( q.getTriggers()[ 1 ].getKey().getName() ).toBe( "keep [every 7200s]" );
				expect( q.getJobs()[ 1 ].getJobDataMap()[ "interval" ] ).toBe( 7200 );
			} );

			it( "leaves the scheduler running when sync() fails after the start", function() {
				var path = tmpConfig( { "jobs": [ intervalJob( "sync", 3600 ) ] } );
				var q = new QuartzSyncFailProxy( path );
				arrayAppend( variables.instances, q );
				q.start();
				expect( q.getState() ).toBe( "running" );
				expect( q.getJobs().len() ).toBe( 1 );
			} );

			it( title="exports the jobs that have a JobDetail and skips a trigger without one (Redis store)", skip=!hasRedis(), body=function() {
				var q = startRedisScheduler( [ intervalJob( "a", 3600 ), intervalJob( "b", 3600 ) ], "file" );
				orphan( q, "b" );
				expect( q.getTriggers().len() ).toBe( 2 );
				expect( q.getJobs().len() ).toBe( 1 );

				var exported = q.exportJobs();
				expect( exported.len() ).toBe( 1 );
				expect( exported[ 1 ].slug ).toBe( "a" );

				var exportedStatic = org.lucee.extension.quartz.QuartzUtil::exportJobs( q );
				expect( exportedStatic.len() ).toBe( 1 );
				expect( exportedStatic[ 1 ].label ).toBe( "a" );
			} );

			it( title="starts running with an orphaned trigger in the store and restores the job from the config (Redis store)", skip=!hasRedis(), body=function() {
				var q = startRedisScheduler( [ intervalJob( "a", 3600 ), intervalJob( "b", 3600 ) ], "file" );
				orphan( q, "b" );
				q.stop();

				var q2 = new org.lucee.extension.quartz.Quartz( q.getConfigFile() );
				arrayAppend( variables.instances, q2 );
				q2.start();
				expect( q2.getState() ).toBe( "running" );
				q2.loadConfig();
				assertEveryTriggerHasJob( q2, 2 );
				expect( q2.exportJobs().len() ).toBe( 2 );
			} );

			it( title="starts running with an orphaned trigger that is not in the config (Redis store)", skip=!hasRedis(), body=function() {
				var q = startRedisScheduler( [ intervalJob( "a", 3600 ), intervalJob( "b", 3600 ) ], "file" );
				orphan( q, "b" );
				q.stop();
				var path = q.getConfigFile();
				var data = deserializeJSON( fileRead( path ) );
				data.jobs = [ intervalJob( "a", 3600 ) ];
				fileWrite( path, serializeJSON( data ) );

				var q2 = new org.lucee.extension.quartz.Quartz( path );
				arrayAppend( variables.instances, q2 );
				q2.start();
				expect( q2.getState() ).toBe( "running" );
				expect( q2.exportJobs().len() ).toBe( 1 );
				expect( q2.exportJobs()[ 1 ].slug ).toBe( "a" );
				assertEveryTriggerHasJob( q2, 1 );
			} );

			it( title="keeps stateful and plain interval jobs over several restarts (Redis store)", skip=!hasRedis(), body=function() {
				var prefix = "QO" & createUniqueId() & "_";
				var path = tmpConfig( {
					"primary": "file",
					"jobs": [
						statefulUrlJob( "stateful-ok", "/ok-nonexist.cfm" ),
						statefulUrlJob( "stateful-bad", "http://localhost:1/x" ),
						{ "label": "plain", "slug": "plain", "url": "http://localhost:1/x", "interval": 36000, "pause": false }
					],
					"store": redisStore( prefix )
				} );
				loop from=1 to=4 index="local.round" {
					var q = new org.lucee.extension.quartz.Quartz( path );
					arrayAppend( variables.instances, q );
					q.start();
					expect( q.getState() ).toBe( "running" );
					// the first fire of the interval jobs (startNow) and the first reload of the config
					sleep( 1500 );
					q.loadConfig();
					sleep( 500 );
					assertEveryTriggerHasJob( q, 3, "round " & round );
					expect( q.exportJobs().len() ).toBe( 3 );
					q.stop();
				}
			} );
		} );
	}

	// ---- helpers -----------------------------------------------------------

	private boolean function hasRedis() {
		return len( server.system.environment.REDIS_SERVER ?: "" ) > 0;
	}

	private struct function redisStore( required string prefix ) {
		return {
			"type": "redis",
			"host": server.system.environment.REDIS_SERVER,
			"port": val( server.system.environment.REDIS_PORT ?: 6379 ),
			"keyPrefix": arguments.prefix
		};
	}

	private function startRedisScheduler( required array jobs, string primary = "" ) {
		var prefix = "QO" & createUniqueId() & "_";
		var data = { "jobs": arguments.jobs, "store": redisStore( prefix ) };
		if ( len( arguments.primary ) ) data[ "primary" ] = arguments.primary;
		var q = startScheduler( data );
		expect( q.getJobStore().getClass().getName() ).toInclude( "RedisJobStore" );
		arrayAppend( variables.redisStores, q );
		return q;
	}

	/**
	 * Leave the trigger of the job with that slug in the store without its JobDetail: remove the job (which
	 * removes its triggers too) and store the trigger again, which the Redis store accepts.
	 */
	private void function orphan( required any q, required string slug ) {
		var store = arguments.q.getJobStore();
		var found = "";
		loop array=arguments.q.getTriggers() item="local.t" {
			if ( t.getJobKey().getName() == arguments.slug ) found = t;
		}
		expect( isSimpleValue( found ) ).toBeFalse( "trigger of [" & arguments.slug & "] not found" );
		store.removeJob( found.getJobKey() );
		store.storeTrigger( found, true );
		expect( isNull( store.retrieveJob( found.getJobKey() ) ) ).toBeTrue();
		expect( isNull( store.retrieveTrigger( found.getKey() ) ) ).toBeFalse();
	}

	private void function assertEveryTriggerHasJob( required any q, required numeric count, string msg = "" ) {
		var store = arguments.q.getJobStore();
		var triggers = arguments.q.getTriggers();
		expect( triggers.len() ).toBe( arguments.count, arguments.msg );
		expect( arguments.q.getJobs().len() ).toBe( arguments.count, arguments.msg );
		loop array=triggers item="local.t" {
			expect( isNull( store.retrieveJob( t.getJobKey() ) ) ).toBeFalse( "trigger [" & t.getKey().getName() & "] has no job. " & arguments.msg );
		}
	}

	private struct function intervalJob( required string slug, numeric interval = 3600 ) {
		return { "label": arguments.slug, "slug": arguments.slug, "url": "/never.cfm", "interval": arguments.interval, "startAt": "2099-01-01", "pause": true };
	}

	private struct function statefulUrlJob( required string slug, required string url ) {
		return { "label": arguments.slug, "slug": arguments.slug, "url": arguments.url, "interval": 36000, "pause": false, "stateful": true };
	}

	private string function tmpConfig( required struct data ) {
		var path = getTempDirectory() & "quartz-orphan-" & createUniqueId() & ".json";
		fileWrite( path, serializeJSON( arguments.data ) );
		return path;
	}

	private function startScheduler( required struct data ) {
		var q = new org.lucee.extension.quartz.Quartz( tmpConfig( arguments.data ) );
		q.start();
		arrayAppend( variables.instances, q );
		return q;
	}

	private void function rewrite( required any scheduler, required struct data ) {
		fileWrite( arguments.scheduler.getConfigFile(), serializeJSON( arguments.data ) );
	}

	private void function stopAll() {
		if ( !isNull( variables.instances ) ) {
			loop array=variables.instances item="local.q" {
				try { q.stop(); } catch ( any e ) {}
			}
			variables.instances = [];
		}
		// do not leave the jobs in Redis
		if ( !isNull( variables.redisStores ) ) {
			loop array=variables.redisStores item="local.q" {
				try { q.getJobStore().clearAllSchedulingData(); } catch ( any e ) {}
			}
			variables.redisStores = [];
		}
	}
}
