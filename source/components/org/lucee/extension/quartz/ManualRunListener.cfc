/**
 * Removes the one-shot trigger created by triggerJob() once that run has finished.
 *
 * Quartz's own triggerJob() leaves a SimpleTrigger (MT_* in DEFAULT) with the smart misfire
 * policy, which is FIRE_NOW when repeatCount is 0. The Redis job store through 2.0.0.0-RC
 * does not record that fire for a stateful job (timesTriggered stays 0, nextFireTime stays
 * set, the trigger stays acquired). releaseTriggersInterval later moves it back to waiting
 * and it fires again. Unscheduling it here, after a success or a failure, means that
 * recovery has nothing left to release.
 *
 * A second triggerJob() while a stateful job is still running is blocked, then completed
 * by the misfire instruction without ever running. The job listener does not see that
 * trigger. triggerFinalized does, and the one-shot is removed. It is not run later.
 *
 * Not a configured listener: Quartz.getListeners() hides the job listener, and sync() does not write it out.
 */
component implements="JavaSettings" implementsJava="org.quartz.JobListener,org.quartz.SchedulerListener" {

    public static string function listenerName() {
        return "lucee-quartz-manual-run";
    }

    public function init(required any scheduler, string logName="scheduler") {
        variables.scheduler = arguments.scheduler;
        variables.logName = arguments.logName;
        return this;
    }

    public string function getName() {
        return listenerName();
    }

    public void function jobToBeExecuted(context) {
    }

    public void function jobExecutionVetoed(context) {
        // a vetoed one-shot must not stay around for orphan recovery to fire
        removeManualTrigger(arguments.context);
    }

    public void function jobWasExecuted(context, jobException) {
        // jobException is set when the job threw; the one-shot is still finished
        removeManualTrigger(arguments.context);
    }

    public void function triggerFinalized(trigger) {
        if (isNull(arguments.trigger) || !QuartzUtil::isManualTrigger(arguments.trigger)) return;
        // timesTriggered stays 0 when the misfire instruction completes the trigger without a run
        var ran = false;
        try {
            ran = QuartzUtil::isSimpleTrigger(arguments.trigger) && arguments.trigger.getTimesTriggered() > 0;
        }
        catch (any ignore) {}
        if (!ran) {
            log log=variables.logName type="warn" text="Quartz Scheduler: manual trigger [#arguments.trigger.getKey()#] was finalized without running. A second triggerJob() while a stateful job is running is dropped after misfire.";
        }
        // this notification runs while the job store lock is held. The Redis lock is not
        // re-entrant, so unscheduling on this thread deadlocks. A new thread takes the lock
        // after this call returns.
        var key = arguments.trigger.getKey();
        var sched = variables.scheduler;
        var logName = variables.logName;
        try {
            thread name="lucee-quartz-manual-finalize-#createUUID()#" scheduler=sched triggerKey=key logName=logName {
                try {
                    attributes.scheduler.unscheduleJob(attributes.triggerKey);
                }
                catch (any e) {
                    log log=attributes.logName type="error" text="Quartz Scheduler: could not remove finalized manual trigger [#attributes.triggerKey#]: #e.message#";
                }
            }
        }
        catch (any e) {
            try {
                variables.scheduler.unscheduleJob(key);
            }
            catch (any again) {
                log log=variables.logName type="error" text="Quartz Scheduler: could not remove finalized manual trigger [#key#]: #again.message#";
            }
        }
    }

    public void function jobScheduled(trigger) {}
    public void function jobUnscheduled(triggerKey) {}
    public void function triggerPaused(triggerKey) {}
    public void function triggersPaused(triggerGroup) {}
    public void function triggerResumed(triggerKey) {}
    public void function triggersResumed(triggerGroup) {}
    public void function jobAdded(jobDetail) {}
    public void function jobDeleted(jobKey) {}
    public void function jobPaused(jobKey) {}
    public void function jobsPaused(jobGroup) {}
    public void function jobResumed(jobKey) {}
    public void function jobsResumed(jobGroup) {}
    public void function schedulerError(msg, cause) {}
    public void function schedulerInStandbyMode() {}
    public void function schedulerStarted() {}
    public void function schedulerStarting() {}
    public void function schedulerShutdown() {}
    public void function schedulerShuttingdown() {}
    public void function schedulingDataCleared() {}

    private void function removeManualTrigger(required context) {
        var trigger=arguments.context.getTrigger();
        if(isNull(trigger) || !QuartzUtil::isManualTrigger(trigger)) return;
        try {
            arguments.context.getScheduler().unscheduleJob(trigger.getKey());
        }
        catch(any e) {
            var logName="application";
            try {
                var fromJob=arguments.context.getJobDetail().getJobDataMap().getString("log");
                if(!isNull(fromJob) && len(fromJob)) logName=fromJob;
            }
            catch(any ignore) {}
            log log=logName type="error" text="Quartz Scheduler: could not remove manual trigger [#trigger.getKey()#] after execution: #e.message#" exception=e;
        }
    }
}
