/**
 * StatefulURLJob - A stateful implementation of URLJob that prevents concurrent executions
 * 
 * This component extends the standard URLJob but implements the org.quartz.StatefulJob interface,
 * which signals to Quartz that instances of this job should not be executed concurrently.
 * 
 * Use this job type when:
 * - Your URL job might run longer than its trigger interval
 * - You need to ensure a job completes before the next execution begins
 * - You want to prevent job overlapping to avoid resource conflicts
 * 
 * When a StatefulURLJob is running and its trigger fires again, the second execution
 * is skipped until the current execution completes.
 * 
 * @extends URLJob
 * @implements org.quartz.StatefulJob
 */
component implementsJava="org.quartz.StatefulJob" extends="URLJob" {
    
}