
/**
 * Quartz Job Proxy Component
 * 
 * This component acts as a proxy between the Quartz Scheduler and your Lucee components.
 * It implements the org.quartz.Job interface to allow your components to be executed by the Quartz scheduler.
 * 
 * Usage:
 * 1. Create a component that contains an "execute()" method for your scheduled task logic
 * 2. Optionally implement an "init()" constructor method that will receive all job configuration parameters
 * 3. Configure this component in your Quartz scheduler configuration with the following parameters:
 *    - "component": fully qualified path to your component (required)
 *    - "mode": component instantiation mode (optional, values: "transient"|"singleton", default: "transient")
 *       - "transient": Creates a new instance of the component for each execution (default)
 *       - "singleton": Creates a single instance that is reused across all executions of this job
 *    - "label": descriptive name for logging purposes (optional)
 *    - "log": custom log name (defaults to "scheduler" if not specified)
 *    - Any additional parameters will be passed to the component's init() method if it exists
 * 
 * Example configuration:
 * {
 *   "label": "every 31 seconds",
 *   "component": "org.lucee.extension.quartz.example.SimpleJobExample",
 *   "mode": "singleton",
 *   "cron": "0/31 * * ?",
 *   "pause": false,
 *   "customParam1": "value1",
 *   "customParam2": "value2"
 * }
 * 
 * @implementsJava org.quartz.Job
 */
component  implements="JavaSettings" implementsJava="org.quartz.Job" {
    
    /**
     * Required method for the org.quartz.Job interface
     * 
     * This method is called by the Quartz scheduler when the job is triggered.
     * It instantiates the target component specified in the job configuration and:
     * 1. Passes all job configuration parameters to the init() method if it exists
     * 2. Calls the execute() method to run the scheduled task
     * 
     * @param context The JobExecutionContext provided by Quartz scheduler containing job details and configuration
     */
    public void function execute( context) {
        try {
            var detail=context.getJobDetail();

            // load config
            var dataMap = detail.getJobDataMap();
            var cfcName=dataMap.getString("component");
            // log Name
            var logName=dataMap.getString("log");
            if(isNull(logName)) local.logName="scheduler";
            
            // mode
            var singleton=false;
            var mode=dataMap.getString("mode");
            if(!isNull(mode) && mode=="singleton") local.singleton=true;

            
            var label=dataMap.getString("label");

            log log=logName type="debug" text="calling component [#cfcName#] from job [#label?:""#]";
            
            var doInit=false;
            if(singleton) {
                var key=detail.getKey();
                var strKey=detail.getKey().toString();
                if(structKeyExists(static,strKey)) {
                    var cfc=static[strKey];
                }
                else {
                    var cfc=createObject("component", cfcName);
                    static[strKey]=cfc;
                    doInit=true;
                }
            }
            else {
                var cfc=createObject("component", cfcName);
                doInit=true;
            }
            
            // call init method
            if(doInit && structKeyExists(cfc,"init")) {
                // create constructor arguments
                var args=[:];
                loop collection=dataMap index="local.k" item="local.v" {
                    args[k]=v;
                }
                // call it
                cfc.init(argumentCollection=args);
            }

            // call execute
            cfc.execute();
            log log=logName type="debug" text="successfully invoked component [#cfcName#]";
        }
        catch(e) {
            e["timestamp"]=now();
            dataMap["lastException"]=e;
            log log=logName type="error" exception=e;
            throw new org.quartz.JobExecutionException(e);
        }
    }
}