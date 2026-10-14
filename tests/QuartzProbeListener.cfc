/**
 * Job listener for QuartzClassloaderTest: a CFC with implementsJava="org.quartz.JobListener",
 * like a user's own listener. It appends one line per event to the file named in its config.
 */
component implementsJava="org.quartz.JobListener" {

    public function init( struct properties = {} ) {
        variables.file = arguments.properties.file;
        variables.name = arguments.properties.name ?: "QuartzProbeListener";
        return this;
    }

    public string function getName() {
        return variables.name;
    }

    public void function jobToBeExecuted( context ) {
        record( "toBeExecuted", arguments.context );
    }

    public void function jobExecutionVetoed( context ) {
        record( "vetoed", arguments.context );
    }

    public void function jobWasExecuted( context, jobException ) {
        record( isNull( arguments.jobException ) ? "wasExecuted" : "failed:" & arguments.jobException.getMessage(), arguments.context );
    }

    private void function record( required string event, required any context ) {
        lock name="QuartzProbeListener:#variables.file#" timeout=5 {
            fileAppend( variables.file, arguments.event & " " & arguments.context.getJobDetail().getKey().getName() & chr( 10 ) );
        }
    }
}
