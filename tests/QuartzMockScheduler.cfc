/**
 * Minimal stand-in for org.quartz.Scheduler used by the QuartzLoadJobProxy tests
 * (not a test spec - no LuceeTestCase, no labels).
 *
 * getJobDetail() always returns null to simulate an orphaned trigger: a store row with
 * a trigger key but no matching JobDetail, as can happen with the Redis job store.
 * scheduleJob() records that the job was (re)scheduled so the test can assert on it.
 */
component {

    variables.scheduled = false;

    public function getJobDetail( jobKey )      { return nullValue(); }
    public function unscheduleJob( triggerKey ) { return false; }
    public function deleteJob( jobKey )         { return false; }
    public function scheduleJob( job, trigger ) { variables.scheduled = true; }
    public function pauseTrigger( key )         {}
    public function pauseJob( key )             {}

    public boolean function wasScheduled()      { return variables.scheduled; }
}
