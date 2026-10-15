/**
 * test helper: puts the loaded jobs under the hashed names an older extension version used,
 * so the upgrade to readable names can be tested
 */
component extends="org.lucee.extension.quartz.Quartz" {

	public void function useLegacyNames() {
		loop array=getTriggers() item="local.trigger" {
			var job = variables.scheduler.getJobDetail( trigger.getJobKey() );
			var legacyJob = job.getJobBuilder().withIdentity( hash( job.getKey().getName(), "quick" ), "cfm" ).build();
			var legacyTrigger = trigger.getTriggerBuilder()
				.withIdentity( hash( trigger.getKey().getName(), "quick" ), "cfm" )
				.forJob( legacyJob )
				.build();
			variables.scheduler.deleteJob( job.getKey() );
			variables.scheduler.scheduleJob( legacyJob, legacyTrigger );
		}
	}
}
