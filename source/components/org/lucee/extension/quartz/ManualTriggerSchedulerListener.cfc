/**
 * Removes a triggerJob() one-shot that Quartz finalized without executing it.
 *
 * A second MT_* while a stateful job is already running stays BLOCKED. Once it is older
 * than misfireThreshold, RESCHEDULE_NEXT_WITH_EXISTING_COUNT leaves it with no next fire
 * time and the job store marks it COMPLETE. No job ran, so ManualTriggerListener (a
 * JobListener) never sees it. triggerFinalized is the signal that does. The unschedule
 * is deferred: this callback runs while the job store lock is held (Redis's lock is not
 * reentrant).
 *
 * @implementsJava org.quartz.SchedulerListener
 */
component implementsJava="org.quartz.SchedulerListener" {

    public static string function listenerName() {
        return "lucee-quartz-manual-trigger-scheduler";
    }

    public string function getName() {
        return listenerName();
    }

    public function init(any scheduler, string logName = "scheduler") {
        if (!isNull(arguments.scheduler)) {
            variables.scheduler = arguments.scheduler;
            variables.logName = arguments.logName;
        }
        return this;
    }

    public void function triggerFinalized(trigger) {
        try {
            if (isNull(arguments.trigger) || !QuartzUtil::isManualTrigger(arguments.trigger)) return;
            var times = 0;
            try {
                times = arguments.trigger.getTimesTriggered();
            }
            catch (any ignore) {}
            var key = arguments.trigger.getKey();
            // timesTriggered stays 0 when the one-shot was finalized from a misfire and the job never ran
            if (times <= 0) {
                log log=variables.logName type="warning" text="Quartz Scheduler: manual trigger [#key.getGroup()#.#key.getName()#] was finalized without running and has been removed";
            }
            // return before unschedule so the store can drop its lock
            thread name="quartz-mt-final-#createUniqueId()#" sched=variables.scheduler logName=variables.logName triggerKey=key {
                sleep(100);
                try {
                    attributes.sched.unscheduleJob(attributes.triggerKey);
                }
                catch (any inner) {
                    log log=attributes.logName type="error" text="Quartz Scheduler: could not remove finalized manual trigger: #inner.message#";
                }
            }
        }
        catch (any e) {
            log log=(variables.logName ?: "scheduler") type="error" text="Quartz Scheduler: could not remove finalized manual trigger: #e.message#";
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
}
