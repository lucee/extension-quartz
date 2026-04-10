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
component implements="JavaSettings" implementsJava="org.quartz.StatefulJob"  {
    
    /**
     * Required method for the org.quartz.Job interface
     * 
     * This method is called by the Quartz scheduler when the job is triggered.
     * It makes an HTTP request to the URL specified in the job configuration.
     * For absolute URLs (http://, https://), it makes a standard HTTP request.
     * For relative URLs (/path/file.cfm), it uses internalRequest to ensure execution on the current server.
     * 
     * @param context The JobExecutionContext provided by Quartz scheduler containing job details and configuration
     */
    public void function execute( context) {
        try {
            // load config
            var dataMap = context.getJobDetail().getJobDataMap();
            var _url=dataMap.getString("url");
            var logName=dataMap.getString("log");
            if(isNull(logName)) local.logName="scheduler";
            var label=dataMap.getString("label");
            
            log log=logName type="debug" text="calling url [#_url#] from job [#label?:""#]";
            
            if(left(_url,7)=="http://" || left(_url,8)=="https://") {
            http url=_url throwOnError=true result="local.res";
            }
            else {
                var index=find("?", _url);
                var template=index==0?_url:left(_url,index-1);
                var qs=index==0?"":mid(_url,index+1);
                var res=internalRequest(
                    template:template,
                    urls=qs,
                    throwonerror:true);
            }
            
            
            if(res.status_code>=200 && res.status_code<300) {
                log log=logName type="debug" text="successfully executed [#_url#]";
            }
            else {
                log log=logName type="warn" text="failed to execute [#_url#] with status code [#res.status_code#]";
            }
        }
        catch(e) {
            e["timestamp"]=now();
            dataMap["lastException"]=e;
            log log=logName type="error" exception=e;
            throw new org.quartz.JobExecutionException(e);
        }
    }
}