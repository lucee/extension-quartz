/**
 * Test seam (not a test spec - no LuceeTestCase, no labels).
 *
 * Exposes the private loadJob() of the extension's Quartz component and lets a test
 * inject a scheduler, so the orphaned-trigger case (a trigger key with no matching
 * JobDetail, as produced by the Redis job store) can be exercised without a real store.
 *
 * Instantiate with createObject() - NOT `new` - so the inherited Quartz.init() (which
 * needs a config file) is not called.
 */
component extends="org.lucee.extension.quartz.Quartz" {

    public function callLoadJob( required scheduler, required struct data, required struct existingJobs ) {
        variables.scheduler = arguments.scheduler;
        variables.logName   = "scheduler";
        return loadJob( arguments.data, arguments.existingJobs );
    }
}
