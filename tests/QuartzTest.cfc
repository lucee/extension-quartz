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
    }

    // ---- helpers -----------------------------------------------------------

    // an uninitialized Quartz instance, for calling static helpers without starting a scheduler
    private any function quartz() {
        return createObject( "component", "org.lucee.extension.quartz.Quartz" );
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
}
