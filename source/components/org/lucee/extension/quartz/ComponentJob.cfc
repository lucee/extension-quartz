/**
 * Quartz Job Proxy Component
 * 
 * This component acts as a proxy between the Quartz Scheduler and your Lucee components.
 * It implements the org.quartz.Job interface to allow your components to be executed by the Quartz scheduler.
 * 
 * Usage:
 * 1. Create a component that contains an "execute()" method for your scheduled task logic
 * 2. Configure this component in your Quartz scheduler configuration with the following parameters:
 *    - "component": fully qualified path to your component (required)
 *    - "label": descriptive name for logging purposes (optional)
 *    - "log": custom log name (defaults to "scheduler" if not specified)
 * 
 * Example configuration:
 * {
 *   "label": "every 31 seconds",
 *   "component": "org.lucee.extension.quartz.example.SimpleJobExample",
 *   "cron": "0/31 * * ?",
 *   "pause": false
 * }
 * 
 * @implementsJava org.quartz.Job
 */
component implementsJava="org.quartz.Job" {

    /**
     * Required method for the org.quartz.Job interface
     * 
     * This method is called by the Quartz scheduler when the job is triggered.
     * It instantiates the target component specified in the job configuration and calls its execute() method.
     * 
     * @param context The JobExecutionContext provided by Quartz scheduler containing job details and configuration
     */
    public void function execute( context) {
        try {
            // load config
            var dataMap = context.getJobDetail().getJobDataMap();
            var cfcName=dataMap.getString("component");
            var logName=dataMap.getString("log");
            if(isNull(logName)) local.logName="scheduler";
            var label=dataMap.getString("label");

            log log=logName type="debug" text="calling component [#cfcName#] from job [#label?:""#]";
            
            var cfc=createObject("component", cfcName)
            // TODO cfc.init(); // only call init if exist
            cfc.execute();
            log log=logName type="debug" text="successfully invoked component [#cfcName#]";
        }
        catch(e) {
            e["timestamp"]=now();
            dataMap["lastException"]=e;
            log log=logName type="error" exception=e;
            rethrow;
        }
    }
}