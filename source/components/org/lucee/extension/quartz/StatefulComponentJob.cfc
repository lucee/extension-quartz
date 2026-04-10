
/**
 * StatefulComponentJob - A stateful implementation of ComponentJob that prevents concurrent executions
 * 
 * This component extends the standard ComponentJob but implements the org.quartz.StatefulJob interface,
 * which signals to Quartz that instances of this job should not be executed concurrently.
 * 
 * Use this job type when:
 * - Your component job might run longer than its trigger interval
 * - You need to ensure a job completes before the next execution begins
 * - You want to prevent job overlapping to avoid resource conflicts or data integrity issues
 * 
 * When a StatefulComponentJob is running and its trigger fires again, the second execution
 * is skipped until the current execution completes. This is particularly useful for:
 * - Database maintenance operations
 * - Resource-intensive processing
 * - Tasks that modify shared resources
 * 
 * @extends ComponentJob
 * @implements org.quartz.StatefulJob
 */
component  implements="JavaSettings" implementsJava="org.quartz.StatefulJob" {
    
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