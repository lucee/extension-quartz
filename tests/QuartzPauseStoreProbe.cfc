/**
 * Test helper for QuartzPausedJobTest (LDEV-6785), not a spec.
 * Scheduler listener that records the state a trigger has in the job store right after it was stored
 * ("<trigger name> <state>") and then holds the thread that stored it for a while. That stands in for
 * a slow node or a slow store: whatever the extension does after storing the trigger happens that much
 * later, while the scheduler threads of all nodes keep acquiring triggers from the store.
 */
component implementsJava="org.quartz.SchedulerListener" {

	public function init( required any scheduler, required string file, numeric delay = 0 ) {
		variables.scheduler = arguments.scheduler;
		variables.file = arguments.file;
		variables.delay = arguments.delay;
		return this;
	}

	public void function jobScheduled( trigger ) {
		var key = arguments.trigger.getKey();
		// triggerJob() one-shots are not configured schedules
		if ( key.getGroup() == "DEFAULT" && left( key.getName(), 3 ) == "MT_" ) return;
		var state = variables.scheduler.getTriggerState( key ).name();
		lock name="QuartzPauseStoreProbe:#variables.file#" timeout=5 {
			fileAppend( variables.file, key.getName() & " " & state & chr( 10 ) );
		}
		if ( variables.delay > 0 ) sleep( variables.delay );
	}

	public void function jobUnscheduled( triggerKey ) {}
	public void function triggerFinalized( trigger ) {}
	public void function triggerPaused( triggerKey ) {}
	public void function triggersPaused( triggerGroup ) {}
	public void function triggerResumed( triggerKey ) {}
	public void function triggersResumed( triggerGroup ) {}
	public void function jobAdded( jobDetail ) {}
	public void function jobDeleted( jobKey ) {}
	public void function jobPaused( jobKey ) {}
	public void function jobsPaused( jobGroup ) {}
	public void function jobResumed( jobKey ) {}
	public void function jobsResumed( jobGroup ) {}
	public void function schedulerError( msg, cause ) {}
	public void function schedulerInStandbyMode() {}
	public void function schedulerStarted() {}
	public void function schedulerStarting() {}
	public void function schedulerShutdown() {}
	public void function schedulerShuttingdown() {}
	public void function schedulingDataCleared() {}
}
