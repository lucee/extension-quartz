/**
 * Test helper for QuartzPausedJobTest (LDEV-6785), not a spec.
 * Job listener that appends one line per job about to run ("toBeExecuted <job name>") to the file in its config.
 */
component implementsJava="org.quartz.JobListener" {

	public function init( struct properties = {} ) {
		variables.file = arguments.properties.file;
		variables.name = arguments.properties.name ?: "QuartzPauseProbe";
		return this;
	}

	public string function getName() {
		return variables.name;
	}

	public void function jobToBeExecuted( context ) {
		record( "toBeExecuted " & arguments.context.getJobDetail().getKey().getName() );
	}

	public void function jobExecutionVetoed( context ) {}

	public void function jobWasExecuted( context, jobException ) {}

	private void function record( required string line ) {
		lock name="QuartzPauseProbe:#variables.file#" timeout=5 {
			fileAppend( variables.file, arguments.line & chr( 10 ) );
		}
	}
}
