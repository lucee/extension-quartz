/**
 * The scheduler, the extension's CFC jobs (ComponentJob, implementsJava="org.quartz.Job") and a
 * CFC job listener (implementsJava="org.quartz.JobListener") must all see the same org.quartz classes.
 *
 * Regression test for 1.0 PR #8 (reverted in #10): "loadPaths" in the javaSettings of Quartz.cfc
 * loaded a second copy of Quartz, so on Lucee 7.0.2 every job failed with "Job class must implement
 * the Job interface" and addJobListener() found no matching method. Runs against the installed .lex.
 */
component extends="org.lucee.cfml.test.LuceeTestCase" labels="quartz" {

    variables.JOB      = "org.lucee.extension.quartz.example.SimpleJobExample";
    variables.LISTENER = "testAdditional.QuartzProbeListener";

    function run() {
        describe( "CFC jobs and listeners load with the scheduler classloader", function() {

            beforeEach( function() { variables.instances = []; } );
            afterEach( function() { stopAll(); } );

            it( "runs a scheduled component job and reports it to a CFC job listener", function() {
                var events = tempFile();
                var q = startScheduler( {
                    "jobs": [ { "label": "every second", "component": variables.JOB, "interval": 1, "pause": false } ],
                    "listeners": [ { "component": variables.LISTENER, "file": events, "name": "probe-scheduled" } ]
                } );
                expect( q.getJobs().len() ).toBe( 1, "the component job was not registered" );
                expect( structKeyExists( q.getListeners( true ), "probe-scheduled" ) ).toBeTrue( "the CFC job listener was not registered" );

                var jobName = hash( variables.JOB, "quick" );
                waitFor( events, "wasExecuted " & jobName );
                expect( readEvents( events ) ).toInclude( "toBeExecuted " & jobName );
                expect( readEvents( events ) ).notToInclude( "failed:" );
            } );

            it( "runs a manually triggered component job and reports it to a CFC job listener", function() {
                var events = tempFile();
                var q = startScheduler( {
                    "jobs": [ { "label": "manual", "component": variables.JOB, "cron": "0 0 0 1 1 ? 2099", "pause": true } ],
                    "listeners": [ { "component": variables.LISTENER, "file": events, "name": "probe-manual" } ]
                } );
                expect( q.getJobs().len() ).toBe( 1, "the component job was not registered" );

                var jobName = hash( variables.JOB, "quick" );
                q.triggerJob( jobName, "cfm" );
                waitFor( events, "wasExecuted " & jobName );
                expect( readEvents( events ) ).notToInclude( "failed:" );
            } );
        } );
    }

    private string function tempFile() {
        return getTempDirectory() & "quartz-classloader-" & createUniqueId() & ".txt";
    }

    private string function readEvents( required string file ) {
        return fileExists( arguments.file ) ? fileRead( arguments.file ) : "";
    }

    private void function waitFor( required string file, required string line ) {
        loop from=1 to=100 index="local.i" {
            if ( find( arguments.line, readEvents( arguments.file ) ) ) return;
            sleep( 100 );
        }
        fail( "listener did not record [#arguments.line#], got [#readEvents( arguments.file )#]" );
    }

    private function startScheduler( required struct data ) {
        var path = getTempDirectory() & "quartz-classloader-" & createUniqueId() & ".json";
        fileWrite( path, serializeJSON( arguments.data ) );
        var q = new org.lucee.extension.quartz.Quartz( path );
        q.start();
        arrayAppend( variables.instances, q );
        return q;
    }

    private void function stopAll() {
        loop array=variables.instances ?: [] item="local.q" {
            try { q.stop(); } catch ( any e ) {}
        }
        variables.instances = [];
    }
}
