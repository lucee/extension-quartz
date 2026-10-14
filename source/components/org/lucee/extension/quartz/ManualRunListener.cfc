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
 * Not a configured listener: Quartz.getListeners() hides it, and sync() does not write it out.
 */
component implements="JavaSettings" implementsJava="org.quartz.JobListener" {

    public static string function listenerName() {
        return "lucee-quartz-manual-run";
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
