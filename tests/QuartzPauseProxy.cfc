/**
 * Test seam for QuartzPausedJobTest (LDEV-6785), not a spec.
 * The scheduler is created inside start(), so the QuartzPauseStoreProbe scheduler listener is added
 * when the job listeners of the config are loaded, which happens after the scheduler was created and
 * before the jobs are loaded. A listener entry with "storeFile" (and optionally "storeDelay") adds it.
 */
component extends="org.lucee.extension.quartz.Quartz" {

	public boolean function loadListener( listenerData, existingListener ) {
		var loaded = super.loadListener( arguments.listenerData, arguments.existingListener );
		if ( !( variables.storeProbeAdded ?: false ) && structKeyExists( arguments.listenerData, "storeFile" ) ) {
			var probe = new QuartzPauseStoreProbe( variables.scheduler, arguments.listenerData.storeFile, arguments.listenerData.storeDelay ?: 0 );
			variables.scheduler.getListenerManager().addSchedulerListener( javaCast( "org.quartz.SchedulerListener", probe ) );
			variables.storeProbeAdded = true;
		}
		return loaded;
	}

	public function getTriggerStateOf( required string jobName ) {
		loop array=getTriggers() item="local.trigger" {
			if ( trigger.getJobKey().getName() == arguments.jobName ) return variables.scheduler.getTriggerState( trigger.getKey() ).name();
		}
		return "";
	}
}
