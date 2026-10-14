/**
 * Tests for the Quartz Scheduler extension.
 *
 * These run inside the Lucee test suite, which has no running HTTP server. Component
 * jobs use the bundled example component so they resolve without extra mappings, and
 * URL jobs use a relative path so they execute through internalRequest (which is
 * designed exactly for this case - no HTTP server required).
 *
 * The scheduler is exercised directly through org.lucee.extension.quartz.Quartz
 * rather than through an event gateway instance, so the gateway lifecycle does not
 * need to be wired up for the test.
 */
component extends="org.lucee.cfml.test.LuceeTestCase" labels="quartz" {

    variables.COMP     = "org.lucee.extension.quartz.example.SimpleJobExample";
    variables.LISTENER = "org.lucee.extension.quartz.ConsoleListener";

    function run() {

        describe( "Quartz static helpers", function() {

            it( "exposes the known trigger states", function() {
                var states = quartz().getStates();
                expect( states ).toBeArray();
                expect( arrayFindNoCase( states, "PAUSED" ) ).toBeGT( 0 );
                expect( arrayFindNoCase( states, "NORMAL" ) ).toBeGT( 0 );
            } );

            it( "resolves ${ENV} placeholders against the OS environment", function() {
                // pick an environment variable that is guaranteed to exist
                var key  = structKeyArray( server.system.environment )[ 1 ];
                var data = { "value": "${" & key & "}" };

                var resolved = quartz().resolveEnvVar( data );

                expect( resolved.value ).toBe( server.system.environment[ key ] );
                // the original struct must not be mutated (doDuplicate defaults to true)
                expect( data.value ).toBe( "${" & key & "}" );
            } );

            it( "reads and parses a config file via _init()", function() {
                var path = tmpConfig( {
                    "logName": "scheduler",
                    "jobs": [ compJob() ]
                } );

                var result = {};
                quartz()._init( path, result );

                expect( result.logName ).toBe( "scheduler" );
                expect( result.config.jobs.len() ).toBe( 1 );
                expect( result.config.jobs[ 1 ].component ).toBe( variables.COMP );
            } );
        } );

        describe( "QuartzUtil::resolveTimeout", function() {

            // the job data map at runtime is a Quartz JobDataMap (a java.util.Map); emulate it
            // here with a plain java.util.HashMap so the containsKey()/get() calls are exercised
            // exactly as they are in production.
            it( "defaults to 50 when no timeout is configured", function() {
                var map = new java.util.HashMap();
                map.put( "url", "http://example.com" );

                expect( resolveTimeout( map ) ).toBe( 50 );
            } );

            it( "reads the native 'timeout' key", function() {
                var map = new java.util.HashMap();
                map.put( "timeout", 30 );

                expect( resolveTimeout( map ) ).toBe( 30 );
            } );

            it( "falls back to the classic 'requestTimeOut' key", function() {
                var map = new java.util.HashMap();
                map.put( "requestTimeOut", 15 );

                expect( resolveTimeout( map ) ).toBe( 15 );
            } );

            it( "prefers 'timeout' over 'requestTimeOut'", function() {
                var map = new java.util.HashMap();
                map.put( "timeout", 30 );
                map.put( "requestTimeOut", 15 );

                expect( resolveTimeout( map ) ).toBe( 30 );
            } );

            it( "accepts a numeric value held as a string", function() {
                var map = new java.util.HashMap();
                map.put( "timeout", "45" );

                expect( resolveTimeout( map ) ).toBe( 45 );
            } );

            it( "ignores a non-numeric value and uses the default", function() {
                var map = new java.util.HashMap();
                map.put( "timeout", "soon" );

                expect( resolveTimeout( map ) ).toBe( 50 );
            } );

            it( "ignores a non-positive value and uses the default", function() {
                var map = new java.util.HashMap();
                map.put( "timeout", 0 );

                expect( resolveTimeout( map ) ).toBe( 50 );
            } );

            it( "honors a custom default when nothing is configured", function() {
                var map = new java.util.HashMap();

                expect( resolveTimeout( map, 120 ) ).toBe( 120 );
            } );
        } );

        describe( "scheduler lifecycle & job registration", function() {

            beforeEach( function() { variables.instances = []; } );
            afterEach( function() { stopAll(); } );

            it( "starts from a file config and registers all jobs", function() {
                var q = startScheduler( { "jobs": [ compJob(), urlJob() ] } );

                expect( q.getState() ).toBe( "running" );
                expect( q.getJobs().len() ).toBe( 2 );
                expect( structCount( q.getJobsAsStruct() ) ).toBe( 2 );
            } );

            it( "reports 'stopped' after stop()", function() {
                var q = startScheduler( { "jobs": [ compJob() ] } );
                expect( q.getState() ).toBe( "running" );

                q.stop();
                expect( q.getState() ).toBe( "stopped" );
            } );

            it( "starts with an empty job list", function() {
                var q = startScheduler( { "jobs": [] } );
                expect( q.getState() ).toBe( "running" );
                expect( q.getJobs().len() ).toBe( 0 );
            } );
        } );

        describe( "pause / resume / delete", function() {

            beforeEach( function() { variables.instances = []; } );
            afterEach( function() { stopAll(); } );

            it( "pauses, resumes and deletes a job", function() {
                var q    = startScheduler( { "jobs": [ compJob( pause = true ) ] } );
                var name = hash( variables.COMP, "quick" );

                // created paused
                expect( q.exportJobs()[ 1 ].pause ).toBeTrue();

                q.resumeJob( name, "cfm" );
                expect( q.exportJobs()[ 1 ].pause ).toBeFalse();

                q.pauseJob( name, "cfm" );
                expect( q.exportJobs()[ 1 ].pause ).toBeTrue();

                q.deleteJob( name, "cfm" );
                expect( q.getJobs().len() ).toBe( 0 );
            } );
        } );

        describe( "config persistence", function() {

            beforeEach( function() { variables.instances = []; } );
            afterEach( function() { stopAll(); } );

            it( "persists addJob() to the config file", function() {
                var q = startScheduler( { "jobs": [] } );

                q.addJob( compJob() );

                expect( q.getJobs().len() ).toBe( 1 );
                var onDisk = deserializeJSON( fileRead( q.getConfigFile() ) );
                expect( onDisk.jobs.len() ).toBe( 1 );
                expect( onDisk.jobs[ 1 ].component ).toBe( variables.COMP );
            } );

            // pause, resume and delete rewrite the config file from the scheduler state
            it( "keeps the settings it does not manage when pause, resume and delete rewrite the config file", function() {
                var q    = startScheduler( { "jobs": [ compJob( pause = true ) ], "threadPoolCount": 3, "misfirePolicy": "ignoreMisfires" } );
                var name = hash( variables.COMP, "quick" );

                q.resumeJob( name, "cfm" );
                assertSettingsKept( q );

                q.pauseJob( name, "cfm" );
                assertSettingsKept( q );

                q.deleteJob( name, "cfm" );
                assertSettingsKept( q );
                expect( deserializeJSON( fileRead( q.getConfigFile() ) ).jobs.len() ).toBe( 0 );
            } );

            it( "persists addListener() to the config file", function() {
                var q = startScheduler( { "jobs": [], "listeners": [] } );

                q.addListener( { "component": variables.LISTENER, "stream": "out" } );

                expect( q.getListeners().len() ).toBe( 1 );
                var onDisk = deserializeJSON( fileRead( q.getConfigFile() ) );
                expect( onDisk.listeners.len() ).toBe( 1 );
            } );
        } );

        describe( "loadConfig() live reload", function() {

            beforeEach( function() { variables.instances = []; } );
            afterEach( function() { stopAll(); } );

            it( "adds a job added to the config file", function() {
                var q = startScheduler( { "jobs": [ compJob() ] } );
                expect( q.getJobs().len() ).toBe( 1 );

                rewrite( q, { "jobs": [ compJob(), urlJob() ] } );
                expect( q.loadConfig() ).toBe( "running" );

                expect( q.getJobs().len() ).toBe( 2 );
            } );

            it( "does not rewrite the config file when nothing changed", function() {
                var q    = startScheduler( { "jobs": [ compJob() ] } );
                var path = q.getConfigFile();

                var before = getFileInfo( path ).lastmodified.getTime();
                sleep( 1100 );
                expect( q.loadConfig() ).toBe( "running" );
                var after = getFileInfo( path ).lastmodified.getTime();

                // an unchanged reload must short-circuit before touching the file
                expect( after ).toBe( before );
            } );

            it( "removes a job dropped from the config file (file is authoritative)", function() {
                var q = startScheduler( { "jobs": [ compJob(), urlJob() ] } );
                expect( q.getJobs().len() ).toBe( 2 );

                rewrite( q, { "jobs": [ compJob() ] } );
                q.loadConfig();

                expect( q.getJobs().len() ).toBe( 1 );
                expect( q.getJobsAsStruct() ).toHaveKey( hash( variables.COMP, "quick" ) );
            } );

            it( "applies a changed pause state on reload", function() {
                var q = startScheduler( { "jobs": [ compJob( pause = false ) ] } );
                expect( q.exportJobs()[ 1 ].pause ).toBeFalse();

                rewrite( q, { "jobs": [ compJob( pause = true ) ] } );
                q.loadConfig();

                expect( q.exportJobs()[ 1 ].pause ).toBeTrue();
            } );

            it( "adds and removes listeners on reload", function() {
                var q = startScheduler( { "jobs": [], "listeners": [] } );
                expect( q.getListeners().len() ).toBe( 0 );

                rewrite( q, { "jobs": [], "listeners": [ { "component": variables.LISTENER, "stream": "out" } ] } );
                q.loadConfig();
                expect( q.getListeners().len() ).toBe( 1 );

                rewrite( q, { "jobs": [], "listeners": [] } );
                q.loadConfig();
                expect( q.getListeners().len() ).toBe( 0 );
            } );

            it( "reschedules an orphaned trigger whose JobDetail is missing (e.g. Redis)", function() {
                // createObject (not `new`) so the inherited Quartz.init() is not invoked
                var proxy = createObject( "component", "QuartzLoadJobProxy" );
                var mock  = new QuartzMockScheduler();

                var data = { "label": "orphan", "component": variables.COMP, "cron": "0 0 0 1 1 ? 2099", "pause": false };
                // existingJobs claims the job exists (a trigger is present), but the mock
                // returns null for getJobDetail() - the orphaned store-row case
                var existing = { "#hash( variables.COMP, "quick" )#": { "job": "jobKey", "trigger": "triggerKey" } };

                // must not throw on the null JobDetail; must fall through to scheduleJob()
                proxy.callLoadJob( mock, data, existing );
                expect( mock.wasScheduled() ).toBeTrue();
            } );

            it( "throws when the scheduler is not running", function() {
                var path = tmpConfig( { "jobs": [] } );
                var q    = new org.lucee.extension.quartz.Quartz( path );
                arrayAppend( variables.instances, q );

                expect( function() {
                    q.loadConfig();
                } ).toThrow( type = "Schedule.SchedulerNotRunning" );
            } );
        } );

        describe( "event gateway message interface", function() {

            beforeEach( function() { variables.instances = []; } );
            afterEach( function() { stopAll(); } );

            it( "returns the state for the 'state' action", function() {
                var q = startScheduler( { "jobs": [ compJob() ] } );
                expect( q.sendMessageInstance( { "action": "state" } ) ).toBe( "running" );
            } );

            it( "returns the store as JSON for the 'store' action", function() {
                var q    = startScheduler( { "jobs": [], "store": {} } );
                var json = q.sendMessageInstance( { "action": "store" } );
                expect( isJSON( json ) ).toBeTrue();
            } );

            it( "reloads the config for the 'reload' action", function() {
                var q = startScheduler( { "jobs": [ compJob() ] } );

                rewrite( q, { "jobs": [ compJob(), urlJob() ] } );
                expect( q.sendMessageInstance( { "action": "reload" } ) ).toBe( "running" );

                expect( q.getJobs().len() ).toBe( 2 );
            } );
        } );

        describe( "component job execution", function() {

            beforeEach( function() { variables.instances = []; } );
            afterEach( function() { stopAll(); } );

            it( "actually fires a component job on an interval", function() {
                var q = startScheduler( {
                    "jobs": [ { "label": "runs", "component": variables.COMP, "interval": 1, "pause": false } ]
                } );

                var triggers = q.getTriggers();
                expect( triggers.len() ).toBe( 1 );

                // wait for at least one fire of the 1 second interval
                var fired = false;
                loop times=20 {
                    if ( !isNull( q.getTriggers()[ 1 ].getPreviousFireTime() ) ) {
                        fired = true;
                        break;
                    }
                    sleep( 250 );
                }
                expect( fired ).toBeTrue();
            } );

            it( "fires a relative URL job through internalRequest", function() {
                var token   = createUniqueId();
                // write the invoked template into the mapped tests directory: it is writable
                // (unlike the web root) and resolvable by internalRequest via "/testAdditional"
                var dir     = expandPath( "/testAdditional/" );
                var cfmName = "quartz-url-job-" & token & ".cfm";
                var cfmPath = dir & cfmName;
                // internalRequest runs this template, which writes a marker file we can observe
                var marker  = getTempDirectory() & "quartz-url-marker-" & token & ".txt";
                fileWrite( cfmPath, '<cf'&'set fileWrite("' & marker & '", "ran")>' );

                try {
                    startScheduler( {
                        "jobs": [ { "label": "url", "url": "/testAdditional/" & cfmName, "interval": 1, "pause": false } ]
                    } );

                    var ran = false;
                    loop times=20 {
                        if ( fileExists( marker ) ) { ran = true; break; }
                        sleep( 250 );
                    }
                    expect( ran ).toBeTrue();
                }
                finally {
                    if ( fileExists( cfmPath ) ) fileDelete( cfmPath );
                    if ( fileExists( marker ) ) fileDelete( marker );
                }
            } );
        } );

        describe( "thread pool & dispatch throughput config (LDEV-6468)", function() {

            beforeEach( function() { variables.instances = []; } );
            afterEach( function() { stopAll(); } );

            it( "defaults the thread pool to 10 when threadPoolCount is not set", function() {
                var q = startScheduler( { "jobs": [] } );
                expect( q.getMetadataAsStruct().threadPoolSize ).toBe( 10 );
            } );

            it( "honors a configured threadPoolCount", function() {
                var q = startScheduler( { "jobs": [], "threadPoolCount": 3 } );
                expect( q.getMetadataAsStruct().threadPoolSize ).toBe( 3 );
            } );

            it( "defaults batch acquisition to the thread count (Quartz default of 1 serialized dispatch)", function() {
                var q = startScheduler( { "jobs": [], "threadPoolCount": 4 } );
                // stringify: the resolved value is stored as configured (a string) via props
                expect( q.getMetadataAsStruct().batchTriggerAcquisitionMaxCount & "" ).toBe( "4" );
            } );

            it( "honors an explicit batchTriggerAcquisitionMaxCount", function() {
                var q = startScheduler( { "jobs": [], "threadPoolCount": 4, "batchTriggerAcquisitionMaxCount": 2 } );
                expect( q.getMetadataAsStruct().batchTriggerAcquisitionMaxCount & "" ).toBe( "2" );
            } );
        } );

        describe( "trigger misfire policy (LDEV-6468)", function() {

            beforeEach( function() { variables.instances = []; } );
            afterEach( function() { stopAll(); } );

            it( "defaults a cron trigger to DO_NOTHING (not Quartz's smart policy, which drops missed fires)", function() {
                var t = startScheduler( { "jobs": [ cronJob() ] } ).getTriggers()[ 1 ];
                expect( t.getMisfireInstruction() ).toBe( misfireConstants( t ).CRON_DO_NOTHING );
            } );

            it( "lets a cron trigger opt back into the smart policy", function() {
                var t = startScheduler( { "jobs": [ cronJob( misfirePolicy = "smart" ) ] } ).getTriggers()[ 1 ];
                expect( t.getMisfireInstruction() ).toBe( misfireConstants( t ).SMART );
            } );

            it( "maps cron 'fireAndProceed' to FIRE_ONCE_NOW", function() {
                var t = startScheduler( { "jobs": [ cronJob( misfirePolicy = "fireAndProceed" ) ] } ).getTriggers()[ 1 ];
                expect( t.getMisfireInstruction() ).toBe( misfireConstants( t ).CRON_FIRE_ONCE );
            } );

            it( "maps cron 'ignoreMisfires' to the ignore policy", function() {
                var t = startScheduler( { "jobs": [ cronJob( misfirePolicy = "ignoreMisfires" ) ] } ).getTriggers()[ 1 ];
                expect( t.getMisfireInstruction() ).toBe( misfireConstants( t ).IGNORE );
            } );

            it( "leaves an interval trigger on the smart policy by default (unchanged behavior)", function() {
                var t = startScheduler( { "jobs": [ intervalJob() ] } ).getTriggers()[ 1 ];
                expect( t.getMisfireInstruction() ).toBe( misfireConstants( t ).SMART );
            } );

            it( "maps interval 'doNothing' to NEXT_WITH_REMAINING_REPEAT_COUNT", function() {
                var t = startScheduler( { "jobs": [ intervalJob( misfirePolicy = "doNothing" ) ] } ).getTriggers()[ 1 ];
                expect( t.getMisfireInstruction() ).toBe( misfireConstants( t ).SIMPLE_NEXT_REM );
            } );

            it( "maps interval 'fireNow' to FIRE_NOW", function() {
                var t = startScheduler( { "jobs": [ intervalJob( misfirePolicy = "fireNow" ) ] } ).getTriggers()[ 1 ];
                expect( t.getMisfireInstruction() ).toBe( misfireConstants( t ).SIMPLE_FIRE_NOW );
            } );

            it( "applies a global misfirePolicy when the job declares none", function() {
                var t = startScheduler( { "misfirePolicy": "ignoreMisfires", "jobs": [ cronJob() ] } ).getTriggers()[ 1 ];
                expect( t.getMisfireInstruction() ).toBe( misfireConstants( t ).IGNORE );
            } );

            it( "lets a per-job misfirePolicy override the global one", function() {
                var t = startScheduler( { "misfirePolicy": "ignoreMisfires", "jobs": [ cronJob( misfirePolicy = "smart" ) ] } ).getTriggers()[ 1 ];
                expect( t.getMisfireInstruction() ).toBe( misfireConstants( t ).SMART );
            } );
        } );

        describe( "trigger listing getTriggersAsQuery() (LDEV-6531)", function() {

            beforeEach( function() { variables.instances = []; } );
            afterEach( function() { stopAll(); } );

            // in-memory store: no bulk read in the job store, so this is the fallback through the scheduler
            it( "lists triggers with job, schedule and state (in-memory store)", function() {
                var q = startScheduler( { "jobs": listingJobs( 5 ) } );

                expect( q.getJobStore().getClass().getName() ).toInclude( "RAMJobStore" );
                assertListing( q, 5 );
            } );

            it( "lists no triggers for an empty scheduler", function() {
                var q = startScheduler( { "jobs": [] } );
                expect( q.getTriggersAsQuery( false ).recordCount ).toBe( 0 );
            } );

            // Redis store: the job store reads everything in one go (RedisJobStore.getAllTriggerDetails()).
            // Needs a Redis server: REDIS_SERVER (and optionally REDIS_PORT) must be set, like the CI service does.
            it( title="lists triggers with job, schedule and state (Redis store, bulk read)", skip=!hasRedis(), body=function() {
                var q = startRedisScheduler( listingJobs( 25 ) );
                try {
                    expect( q.getJobStore().getClass().getName() ).toInclude( "RedisJobStore" );

                    // the library in use must have the bulk read, otherwise this test would only test the fallback
                    var details = q.getJobStore().getAllTriggerDetails();
                    expect( details.size() ).toBe( 25 );

                    assertListing( q, 25 );
                }
                finally {
                    // do not leave the jobs in Redis
                    try { q.getJobStore().clearAllSchedulingData(); } catch ( any e ) {}
                }
            } );
        } );

        // triggerJob() stores a one-shot SimpleTrigger (MT_* in DEFAULT) next to the configured
        // trigger. Listing must keep working and show that pending run; export/sync must not write
        // the job twice; a reload must keep matching the configured trigger. (LDEV-6576)
        describe( "manual triggerJob while a one-shot is pending (LDEV-6576)", function() {

            beforeEach( function() { variables.instances = []; } );
            afterEach( function() { stopAll(); } );

            it( "lists a pending manual run of a cron job and does not write it into the config", function() {
                var q    = startScheduler( { "jobs": [ cronJob() ], "threadPoolCount": 3, "misfirePolicy": "ignoreMisfires" } );
                var name = hash( variables.COMP, "quick" );
                pauseDefaultTriggerGroup( q );
                q.triggerJob( name, "cfm" );

                assertPendingManualRun( q, "cron", "0 0 0 1 1 ? 2099" );
                // the cron row still came from getExpressionSummary(), not from the one-shot
                expect( scheduleRow( q.getTriggersAsQuery( false ), "cron" ).scheduleTranslated ).toInclude( "2099" );
                // getTriggerForJob must return the configured trigger, even if the one-shot is listed first
                expect( q.getTriggerForJob( name, "cfm" ).scheduleType ).toBe( "cron" );
                expect( org.lucee.extension.quartz.QuartzUtil::getTriggerForJob( q, name, "cfm" ).scheduleType ).toBe( "cron" );

                // pause rewrites the config from exportJobs(); the one-shot must not become a second job
                q.pauseJob( name, "cfm" );
                var onDisk = deserializeJSON( fileRead( q.getConfigFile() ) );
                expect( onDisk.jobs.len() ).toBe( 1 );
                expect( onDisk.jobs[ 1 ].cron ).toBe( "0 0 0 1 1 ? 2099" );
                expect( onDisk.threadPoolCount ).toBe( 3 );
                expect( onDisk.misfirePolicy ).toBe( "ignoreMisfires" );

                // a reload reconciles through getExistingJobs(); mapping the one-shot as the job's
                // trigger would delete and reschedule, and the pending manual run would disappear
                onDisk.touched = "ldev-6576";
                rewrite( q, onDisk );
                expect( q.loadConfig() ).toBe( "running" );
                assertPendingManualRun( q, "cron", "0 0 0 1 1 ? 2099" );
                onDisk = deserializeJSON( fileRead( q.getConfigFile() ) );
                expect( onDisk.jobs.len() ).toBe( 1 );
                expect( onDisk.touched ).toBe( "ldev-6576" );
            } );

            it( "lists a pending manual run of an interval job and does not write it into the config", function() {
                var q    = startScheduler( { "jobs": [ intervalJob() ] } );
                var name = hash( variables.COMP, "quick" );
                pauseDefaultTriggerGroup( q );
                q.triggerJob( name, "cfm" );

                assertPendingManualRun( q, "interval", "3600" );
                expect( scheduleRow( q.getTriggersAsQuery( false ), "interval" ).scheduleTranslated ).toBe( "every 3600 seconds" );

                q.pauseJob( name, "cfm" );
                var onDisk = deserializeJSON( fileRead( q.getConfigFile() ) );
                expect( onDisk.jobs.len() ).toBe( 1 );
                expect( val( onDisk.jobs[ 1 ].interval ) ).toBe( 3600 );
            } );

            it( title="lists a pending manual run and does not duplicate the job (Redis store)", skip=!hasRedis(), body=function() {
                var q    = startRedisScheduler( [ cronJob() ] );
                var name = hash( variables.COMP, "quick" );
                try {
                    expect( q.getJobStore().getClass().getName() ).toInclude( "RedisJobStore" );
                    pauseDefaultTriggerGroup( q );
                    q.triggerJob( name, "cfm" );

                    // the bulk read (getAllTriggerDetails) is what getTriggersAsQuery uses for Redis
                    expect( q.getJobStore().getAllTriggerDetails().size() ).toBe( 2 );
                    assertPendingManualRun( q, "cron", "0 0 0 1 1 ? 2099" );

                    q.pauseJob( name, "cfm" );
                    expect( deserializeJSON( fileRead( q.getConfigFile() ) ).jobs.len() ).toBe( 1 );
                }
                finally {
                    try { q.getJobStore().clearAllSchedulingData(); } catch ( any e ) {}
                }
            } );

            it( "removes the manual trigger after a successful run", function() {
                var q    = startScheduler( { "jobs": [ cronJob() ] } );
                var name = hash( variables.COMP, "quick" );
                q.triggerJob( name, "cfm" );

                expect( waitUntilNoManualTrigger( q ) ).toBeTrue();
                expect( q.getTriggers().len() ).toBe( 1 );
                expect( q.getTriggers()[ 1 ].getKey().getGroup() ).toBe( "cfm" );
                var qry = q.getTriggersAsQuery( false );
                expect( qry.recordCount ).toBe( 1 );
                expect( qry.scheduleType ).toBe( "cron" );
                expect( q.exportJobs().len() ).toBe( 1 );
                expect( deserializeJSON( fileRead( q.getConfigFile() ) ).jobs.len() ).toBe( 1 );
            } );

            it( "removes the manual trigger after a failing stateful run", function() {
                var missing = "org.lucee.extension.quartz.example.DoesNotExist";
                var q = startScheduler( { "jobs": [ {
                    "label": "fail",
                    "component": missing,
                    "cron": "0 0 0 1 1 ? 2099",
                    "pause": true,
                    "stateful": true
                } ] } );
                q.triggerJob( hash( missing, "quick" ), "cfm" );

                expect( waitUntilNoManualTrigger( q ) ).toBeTrue();
                expect( countManualTriggers( q ) ).toBe( 0 );
                expect( q.getTriggers().len() ).toBe( 1 );
                var qry = q.getTriggersAsQuery( false );
                expect( qry.recordCount ).toBe( 1 );
                expect( qry.scheduleType ).toBe( "cron" );
                expect( q.exportJobs().len() ).toBe( 1 );
            } );

            it( "drops a second manual trigger while a stateful job is still running", function() {
                var job = blockingJob();
                assertSecondManualTriggerDropped( startScheduler( { "jobs": [ job ] } ), job.markerFile );
            } );

            it( title="drops a second manual trigger while a stateful job is still running (Redis store)", skip=!hasRedis(), body=function() {
                var job = blockingJob();
                var q = startRedisScheduler( [ job ] );
                try {
                    assertSecondManualTriggerDropped( q, job.markerFile );
                }
                finally {
                    try { q.getJobStore().clearAllSchedulingData(); } catch ( any e ) {}
                }
            } );

            // releaseTriggersInterval is shorter than the wait, so an orphaned one-shot would be
            // handed back and (inside the misfire threshold) fired again. It must stay gone.
            it( title="a failing stateful manual run is not released again (Redis store)", skip=!hasRedis(), body=function() {
                var missing = "org.lucee.extension.quartz.example.DoesNotExist";
                var q = startRedisScheduler( [ {
                    "label": "fail",
                    "component": missing,
                    "cron": "0 0 0 1 1 ? 2099",
                    "pause": true,
                    "stateful": true
                } ], {
                    "releaseTriggersInterval": 1000,
                    "heartbeatInterval": 1000,
                    "clusterCheckinInterval": 15000
                } );
                try {
                    q.triggerJob( hash( missing, "quick" ), "cfm" );
                    expect( waitUntilNoManualTrigger( q ) ).toBeTrue();
                    sleep( 2500 );
                    expect( countManualTriggers( q ) ).toBe( 0 );
                    expect( q.getTriggers().len() ).toBe( 1 );
                    expect( q.getTriggersAsQuery( false ).recordCount ).toBe( 1 );
                    expect( q.exportJobs().len() ).toBe( 1 );
                    expect( deserializeJSON( fileRead( q.getConfigFile() ) ).jobs.len() ).toBe( 1 );
                }
                finally {
                    try { q.getJobStore().clearAllSchedulingData(); } catch ( any e ) {}
                }
            } );
        } );
    }

    // ---- helpers -----------------------------------------------------------

    private void function assertSettingsKept( required any q ) {
        var onDisk = deserializeJSON( fileRead( arguments.q.getConfigFile() ) );
        expect( onDisk.threadPoolCount ).toBe( 3 );
        expect( onDisk.misfirePolicy ).toBe( "ignoreMisfires" );
    }

    // the one-shot from triggerJob() is created in the DEFAULT group; pausing that group
    // stores it paused so the scheduler does not fire it before the assertions run.
    // configured triggers live in group "cfm" and are left alone.
    private void function pauseDefaultTriggerGroup( required any q ) {
        // Quartz is in the extension bundle, so the matcher class is loaded from a live trigger
        var loader       = arguments.q.getTriggers()[ 1 ].getClass().getClassLoader();
        var matcherClass = loader.loadClass( "org.quartz.impl.matchers.GroupMatcher" );
        var stringClass  = loader.loadClass( "java.lang.String" );
        var method       = matcherClass.getMethod( "groupEquals", javaCast( "java.lang.Class[]", [ stringClass ] ) );
        var matcher      = method.invoke( nullValue(), javaCast( "java.lang.Object[]", [ "DEFAULT" ] ) );
        arguments.q.getJobStore().pauseTriggers( matcher );
    }

    // one row of getTriggersAsQuery() for a schedule type
    private struct function scheduleRow( required query qry, required string scheduleType ) {
        loop query=arguments.qry {
            if ( qry.scheduleType == arguments.scheduleType ) {
                return {
                    "schedule": qry.schedule,
                    "scheduleTranslated": qry.scheduleTranslated,
                    "scheduleType": qry.scheduleType
                };
            }
        }
        throw "no row with scheduleType " & arguments.scheduleType;
    }

    // listing shows the configured schedule and the pending manual run, once each;
    // export (Quartz and QuartzUtil) keeps a single job
    private void function assertPendingManualRun( required any q, required string scheduleType, required string schedule ) {
        var qry = arguments.q.getTriggersAsQuery( true );
        expect( qry.recordCount ).toBe( 2 );

        var seen = {};
        loop query=qry {
            expect( structKeyExists( seen, qry.scheduleType ) ).toBeFalse( "schedule listed twice: " & qry.scheduleType );
            seen[ qry.scheduleType ] = qry.schedule & "";
            if ( qry.scheduleType == "manual" ) {
                expect( left( qry[ "key" ].getName(), 3 ) ).toBe( "MT_" );
                expect( qry[ "key" ].getGroup() ).toBe( "DEFAULT" );
                expect( qry.scheduleTranslated ).toBe( "pending manual run" );
                expect( qry.schedule ).toBe( "" );
            }
        }
        expect( seen ).toHaveKey( "manual" );
        expect( seen ).toHaveKey( arguments.scheduleType );
        expect( seen[ arguments.scheduleType ] ).toBe( arguments.schedule );

        // the held one-shot is a single fire, and a misfire must not schedule another
        var manual = nullValue();
        loop array=arguments.q.getTriggers() item="local.t" {
            if ( org.lucee.extension.quartz.QuartzUtil::isManualTrigger( t ) ) {
                manual = t;
                break;
            }
        }
        expect( isNull( manual ) ).toBeFalse();
        expect( manual.getRepeatCount() ).toBe( 0 );
        expect( manual.getMisfireInstruction() ).toBe( misfireConstants( manual ).SIMPLE_NEXT_EXISTING );

        expect( arguments.q.exportJobs().len() ).toBe( 1 );
        var util = org.lucee.extension.quartz.QuartzUtil::getTriggersAsQuery( arguments.q, false );
        expect( util.recordCount ).toBe( 2 );
        expect( org.lucee.extension.quartz.QuartzUtil::exportJobs( arguments.q ).len() ).toBe( 1 );
    }

    private boolean function hasRedis() {
        return len( server.system.environment.REDIS_SERVER ?: "" ) > 0;
    }

    // a scheduler with a Redis job store (the server from the environment, unique key prefix).
    // store overrides are merged on top (releaseTriggersInterval and the intervals it depends on).
    private function startRedisScheduler( required array jobs, struct store = {} ) {
        var data = {
            "jobs": arguments.jobs,
            "store": {
                "type": "redis",
                "host": server.system.environment.REDIS_SERVER,
                "port": val( server.system.environment.REDIS_PORT ?: 6379 ),
                "keyPrefix": "QT" & createUniqueId() & "_"
            }
        };
        structAppend( data.store, arguments.store, true );
        return startScheduler( data );
    }

    private numeric function countManualTriggers( required any q ) {
        var n = 0;
        loop array=arguments.q.getTriggers() item="local.t" {
            if ( org.lucee.extension.quartz.QuartzUtil::isManualTrigger( t ) ) n++;
        }
        return n;
    }

    // a stateful job that stays in execute() long enough for a second triggerJob() to misfire
    private struct function blockingJob() {
        return {
            "label": "block",
            "component": "org.lucee.extension.quartz.example.BlockingJob",
            "cron": "0 0 0 1 1 ? 2099",
            "pause": true,
            "stateful": true,
            "millis": 1500,
            "markerFile": getTempDirectory() & "quartz-block-" & createUniqueId() & ".txt"
        };
    }

    private numeric function markerCount( required string path ) {
        if ( !fileExists( arguments.path ) ) return 0;
        return val( trim( fileRead( arguments.path ) ) );
    }

    // the second MT_* is completed by the misfire instruction and must not stay listed as pending.
    // the first run is the only one that executes.
    private void function assertSecondManualTriggerDropped( required any q, required string markerFile ) {
        var name = hash( "org.lucee.extension.quartz.example.BlockingJob", "quick" );
        if ( fileExists( arguments.markerFile ) ) fileDelete( arguments.markerFile );

        arguments.q.triggerJob( name, "cfm" );
        var started = false;
        loop times=80 {
            if ( markerCount( arguments.markerFile ) > 0 ) { started = true; break; }
            sleep( 25 );
        }
        expect( started ).toBeTrue( "the stateful job did not start" );
        // the default threshold is 60s, so a one-shot blocked for this run would still fire.
        // lower it only after the first run has started, or that run is completed without executing.
        tightenMisfireThreshold( arguments.q, 100 );
        arguments.q.triggerJob( name, "cfm" );

        expect( waitUntilNoManualTrigger( arguments.q, 8000 ) ).toBeTrue();
        expect( countManualTriggers( arguments.q ) ).toBe( 0 );
        var qry = arguments.q.getTriggersAsQuery( false );
        expect( qry.recordCount ).toBe( 1 );
        expect( qry.scheduleType ).toBe( "cron" );
        // give a second run time to start if the misfire did not drop it
        sleep( 300 );
        expect( markerCount( arguments.markerFile ) ).toBe( 1 );

        // reload must not bring the completed one-shot back
        var onDisk = deserializeJSON( fileRead( arguments.q.getConfigFile() ) );
        onDisk.touched = "second-manual";
        rewrite( arguments.q, onDisk );
        expect( arguments.q.loadConfig() ).toBe( "running" );
        expect( countManualTriggers( arguments.q ) ).toBe( 0 );
        expect( arguments.q.getTriggersAsQuery( false ).recordCount ).toBe( 1 );
    }

    // RAMJobStore.setMisfireThreshold(long) is the field acquireNextTriggers reads.
    // RedisJobStore.setMisfireThreshold(int) does not update the storage created in initialize().
    private void function tightenMisfireThreshold( required any q, required numeric ms ) {
        var store = arguments.q.getJobStore();
        try { store.setMisfireThreshold( javaCast( "long", arguments.ms ) ); } catch ( any e ) {}
        try { store.setMisfireThreshold( javaCast( "int", arguments.ms ) ); } catch ( any e ) {}
        try {
            var field = store.getClass().getDeclaredField( "storage" );
            field.setAccessible( true );
            var storage = field.get( store );
            if ( !isNull( storage ) ) storage.setMisfireThreshold( javaCast( "int", arguments.ms ) );
        }
        catch ( any e ) {}
    }

    // the one-shot fires on a scheduler thread; poll until the listener has removed it
    private boolean function waitUntilNoManualTrigger( required any q, numeric timeoutMs = 5000 ) {
        var started = getTickCount();
        while ( getTickCount() - started < arguments.timeoutMs ) {
            if ( countManualTriggers( arguments.q ) == 0 ) return true;
            sleep( 50 );
        }
        return countManualTriggers( arguments.q ) == 0;
    }

    // n far-future jobs, every third one paused, every second one a cron job (the others interval jobs)
    private array function listingJobs( required numeric n ) {
        var jobs = [];
        loop from=1 to=arguments.n index="local.i" {
            var job = { "label": "job " & i, "slug": "listing-job-" & i, "component": variables.COMP, "pause": ( i mod 3 == 0 ) };
            if ( i mod 2 == 0 ) job[ "cron" ] = "0 0 0 1 1 ? 2099";
            else {
                job[ "interval" ] = 3600;
                job[ "startAt" ] = "2099-01-01";
            }
            arrayAppend( jobs, job );
        }
        return jobs;
    }

    // getTriggersAsQuery() must list every trigger once, with the data of its job, schedule and state;
    // checked against what the job store itself returns for each trigger
    private void function assertListing( required any q, required numeric expectedCount ) {
        var qry = arguments.q.getTriggersAsQuery( false );
        expect( qry.recordCount ).toBe( arguments.expectedCount );

        var store = arguments.q.getJobStore();
        var jobNames = {};
        loop array=arguments.q.getJobs() item="local.j" { jobNames[ j.getKey().getName() ] = j; }

        var seen = {};
        loop query=qry {
            expect( structKeyExists( seen, qry.jobName ) ).toBeFalse( "job listed twice: " & qry.jobName );
            seen[ qry.jobName ] = true;

            var job = jobNames[ qry.jobName ];
            var dataMap = job.getJobDataMap();
            expect( qry.jobLabel ).toBe( dataMap[ "label" ] );
            expect( qry.slug ).toBe( dataMap[ "slug" ] );
            expect( qry.endpoint ).toBe( dataMap[ "component" ] );
            expect( qry.jobGroup ).toBe( job.getGroup() );

            // listing jobs: the number in the label tells the expected kind and state
            var idx = val( listLast( qry.jobLabel, " " ) );
            expect( qry.state ).toBe( idx mod 3 == 0 ? "PAUSED" : "NORMAL" );
            expect( qry.scheduleType ).toBe( idx mod 2 == 0 ? "cron" : "interval" );
            expect( qry.schedule ).toBe( idx mod 2 == 0 ? "0 0 0 1 1 ? 2099" : "3600" );

        }
        expect( structCount( seen ) ).toBe( arguments.expectedCount );

        // every trigger of the store is in the listing, with the state of the store
        loop array=arguments.q.getTriggers() item="local.t" {
            var found = false;
            loop query=qry {
                if ( qry.jobName == t.getJobKey().getName() ) {
                    found = true;
                    expect( qry.state ).toBe( store.getTriggerState( t.getKey() ).name() );
                    expect( dateCompare( qry.nextFireTime, t.getNextFireTime() ) ).toBe( 0 );
                    break;
                }
            }
            expect( found ).toBeTrue( "trigger missing in listing: " & t.getKey() );
        }
    }

    // an uninitialized Quartz instance, for calling static helpers without starting a scheduler
    private any function quartz() {
        return createObject( "component", "org.lucee.extension.quartz.Quartz" );
    }

    // delegate to the static QuartzUtil helper under test
    private numeric function resolveTimeout( required any dataMap, numeric defaultTimeout ) {
        if ( isNull( arguments.defaultTimeout ) )
            return org.lucee.extension.quartz.QuartzUtil::resolveTimeout( arguments.dataMap );
        return org.lucee.extension.quartz.QuartzUtil::resolveTimeout( arguments.dataMap, arguments.defaultTimeout );
    }

    private string function tmpConfig( required struct data ) {
        var path = getTempDirectory() & "quartz-test-" & createUniqueId() & ".json";
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
        if ( isNull( variables.instances ) ) return;
        loop array=variables.instances item="local.q" {
            try { q.stop(); } catch ( any e ) {}
        }
        variables.instances = [];
    }

    private struct function compJob( string cron = "0 0 0 1 1 ? 2099", boolean pause = true ) {
        return { "label": "comp", "component": variables.COMP, "cron": arguments.cron, "pause": arguments.pause };
    }

    private struct function urlJob() {
        return { "label": "url", "url": "/never.cfm", "interval": 3600, "startAt": "2099-01-01", "pause": true };
    }

    // a far-future cron job (never fires during the test) with an optional misfire policy
    private struct function cronJob( string cron = "0 0 0 1 1 ? 2099", string misfirePolicy = "", boolean pause = true ) {
        var j = { "label": "cron", "component": variables.COMP, "cron": arguments.cron, "pause": arguments.pause };
        if ( len( arguments.misfirePolicy ) ) j[ "misfirePolicy" ] = arguments.misfirePolicy;
        return j;
    }

    // a far-future interval job (never fires during the test) with an optional misfire policy
    private struct function intervalJob( numeric interval = 3600, string misfirePolicy = "", boolean pause = true ) {
        var j = { "label": "int", "component": variables.COMP, "interval": arguments.interval, "startAt": "2099-01-01", "pause": arguments.pause };
        if ( len( arguments.misfirePolicy ) ) j[ "misfirePolicy" ] = arguments.misfirePolicy;
        return j;
    }

    /**
     * The Quartz misfire-instruction constants, so the tests assert against the real API values
     * rather than magic numbers. Quartz ships inside the extension's OSGi bundle, so the classes
     * are loaded through the classloader of a live trigger (passed in) - the same bundle that
     * created it - rather than createObject("java",...), which resolves against Lucee's loader and
     * would not find org.quartz.*. Cached after the first call.
     */
    private struct function misfireConstants( required any liveTrigger ) {
        if ( isNull( variables.mi ) ) {
            var loader  = arguments.liveTrigger.getClass().getClassLoader();
            var trigger = loader.loadClass( "org.quartz.Trigger" );
            var cron    = loader.loadClass( "org.quartz.CronTrigger" );
            var simple  = loader.loadClass( "org.quartz.SimpleTrigger" );
            // note: not named "val" - that collides with Lucee's built-in Val() function
            var readConst = function( cls, field ) { return cls.getField( field ).getInt( nullValue() ); };
            variables.mi = {
                "SMART"           : readConst( trigger, "MISFIRE_INSTRUCTION_SMART_POLICY" ),
                "IGNORE"          : readConst( trigger, "MISFIRE_INSTRUCTION_IGNORE_MISFIRE_POLICY" ),
                "CRON_DO_NOTHING" : readConst( cron,    "MISFIRE_INSTRUCTION_DO_NOTHING" ),
                "CRON_FIRE_ONCE"  : readConst( cron,    "MISFIRE_INSTRUCTION_FIRE_ONCE_NOW" ),
                "SIMPLE_FIRE_NOW" : readConst( simple,  "MISFIRE_INSTRUCTION_FIRE_NOW" ),
                "SIMPLE_NEXT_REM" : readConst( simple,  "MISFIRE_INSTRUCTION_RESCHEDULE_NEXT_WITH_REMAINING_COUNT" ),
                // one-shot from triggerJob(): no further fire once the original instant has passed
                "SIMPLE_NEXT_EXISTING" : readConst( simple, "MISFIRE_INSTRUCTION_RESCHEDULE_NEXT_WITH_EXISTING_COUNT" )
            };
        }
        return variables.mi;
    }
}
