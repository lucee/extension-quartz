/**
 * Removes the one-shot trigger created by Quartz.triggerJob() once that run has finished.
 *
 * Scheduler.triggerJob() / our own one-shot is an MT_* SimpleTrigger in the DEFAULT group.
 * On the Redis job store (including 2.0.0.0-RC), a @DisallowConcurrentExecution job does not
 * get that fire recorded: timesTriggered stays 0 and nextFireTime stays set, so the store
 * does not delete the trigger. releaseTriggersInterval later moves it from ACQUIRED back to
 * WAITING and, with the smart misfire policy (FIRE_NOW), it fires again. The one-shot is
 * scheduled with RESCHEDULE_NEXT_WITH_EXISTING_COUNT so a recovered trigger has no further
 * fire. Unscheduling here still runs for a successful run, a failed run and a veto, before
 * the job store's completion handler.
 *
 * @implementsJava org.quartz.JobListener
 */
component implementsJava="org.quartz.JobListener" {

    public static string function listenerName() {
        return "lucee-quartz-manual-trigger";
    }

    public string function getName() {
        return listenerName();
    }

    public void function jobToBeExecuted(context) {
    }

    public void function jobExecutionVetoed(context) {
        removeIfManual(context);
    }

    public void function jobWasExecuted(context, jobException) {
        // jobException is set when the run failed; the one-shot must still be removed
        removeIfManual(context);
    }

    private void function removeIfManual(context) {
        try {
            var trigger = arguments.context.getTrigger();
            if (!QuartzUtil::isManualTrigger(trigger)) return;
            arguments.context.getScheduler().unscheduleJob(trigger.getKey());
        }
        catch (any e) {
            var logName = "scheduler";
            try {
                var fromJob = arguments.context.getJobDetail().getJobDataMap().getString("log");
                if (!isNull(fromJob) && len(fromJob)) logName = fromJob;
            }
            catch (any ignore) {}
            log log=logName type="error" text="Quartz Scheduler: could not remove manual trigger after execution: #e.message#";
        }
    }
}
