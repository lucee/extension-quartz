/**
 * calls an URL 
 */
component implementsJava="org.quartz.Job" {
    
    public void function execute( context) {
        try {
            // load config
            var dataMap = context.getJobDetail().getJobDataMap();
            var _url=dataMap.getString("url");
            var logName=dataMap.getString("log");
            if(isNull(logName)) local.logName="scheduler";
            var label=dataMap.getString("label");
            
            log log=logName type="debug" text="calling url [#_url#] from job [#label?:""#]";
            http url=_url throwOnError=true result="local.res";
            if(res.status_code>=200 && res.status_code<300) {
                log log=logName type="debug" text="successfully executed [#_url#]";
            }
            else {
                log log=logName type="warn" text="failed to execute [#_url#] with status code [#res.status_code#]";
            }
        }
        catch(e) {
            log log=logName type="error" exception=e;
        }
    }
}