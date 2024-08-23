/**
 * Simply calls an URL
 */
component implementsJava="org.quartz.Job" {
    
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
            log log=logName type="error" exception=e;
        }
    }
}