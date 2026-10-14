package org.lucee.extension.quartz;

import org.quartz.Scheduler;
import org.quartz.SchedulerException;
import org.quartz.SimpleTrigger;
import org.quartz.Trigger;
import org.quartz.TriggerKey;
import org.quartz.listeners.SchedulerListenerSupport;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Removes a triggerJob() one-shot that Quartz has already finalized.
 *
 * A second MT_* while a stateful job is running stays blocked. Past misfireThreshold,
 * RESCHEDULE_NEXT_WITH_EXISTING_COUNT leaves no next fire time and the job store marks
 * the trigger COMPLETE without executing the job, so the job listener never sees it.
 * This does not queue or refuse that second trigger; Quartz still drops it.
 *
 * triggerFinalized runs while the job store lock is held. The Redis lock is not
 * reentrant, so the unschedule happens on another thread after this method returns.
 */
public class ManualTriggerSchedulerListener extends SchedulerListenerSupport {

    public static final String NAME = "lucee-quartz-manual-trigger-scheduler";

    private static final Logger LOG = LoggerFactory.getLogger(ManualTriggerSchedulerListener.class);

    private final Scheduler scheduler;

    public ManualTriggerSchedulerListener(Scheduler scheduler) {
        this.scheduler = scheduler;
    }

    public String getName() {
        return NAME;
    }

    @Override
    public void triggerFinalized(Trigger trigger) {
        if (!isManualTrigger(trigger)) return;
        final TriggerKey key = trigger.getKey();
        if (timesTriggered(trigger) <= 0) {
            LOG.warn("Quartz Scheduler: manual trigger {}.{} was finalized without running and has been removed",
                    key.getGroup(), key.getName());
        }
        Thread remover = new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    Thread.sleep(100L);
                    scheduler.unscheduleJob(key);
                }
                catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
                catch (SchedulerException e) {
                    LOG.error("Quartz Scheduler: could not remove finalized manual trigger {}.{}: {}",
                            key.getGroup(), key.getName(), e.getMessage());
                }
            }
        }, "quartz-mt-final");
        remover.setDaemon(true);
        remover.start();
    }

    private static boolean isManualTrigger(Trigger trigger) {
        if (trigger == null) return false;
        TriggerKey key = trigger.getKey();
        return key != null
                && "DEFAULT".equals(key.getGroup())
                && key.getName() != null
                && key.getName().startsWith("MT_");
    }

    private static int timesTriggered(Trigger trigger) {
        if (trigger instanceof SimpleTrigger) {
            return ((SimpleTrigger) trigger).getTimesTriggered();
        }
        return 0;
    }
}
