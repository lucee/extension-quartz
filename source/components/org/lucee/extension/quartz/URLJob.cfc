/**
 * URL Caller Quartz Job Component
 * 
 * This component acts as a proxy between the Quartz Scheduler and URL endpoints.
 * It implements the org.quartz.Job interface to allow scheduled HTTP requests to both external and internal URLs.
 * 
 * Key features:
 * - Supports both external URLs (http://, https://) using HTTP requests
 * - Supports internal relative paths (/path/file.cfm) using internalRequest
 * - Internal requests are executed on the current server, which is critical in cluster environments
 * 
 * Usage:
 * Configure this component in your Quartz scheduler configuration with the following parameters:
 *    - "url": the URL to call, either absolute (http://example.com) or relative (/path/file.cfm) (required)
 *    - "label": descriptive name for logging purposes (optional)
 *    - "log": custom log name (defaults to "scheduler" if not specified)
 * 
 * Example configuration:
 * {
 *   "label": "hourly data refresh",
 *   "url": "/tasks/refresh-data.cfm",
 *   "cron": "0 0 * * * ?",
 *   "pause": false
 * }
 * 
 * @implementsJava org.quartz.Job
 */
component implements="JavaSettings" implementsJava="org.quartz.Job"  {
    
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
                    throwonerror:false);
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
            rethrow;
        }
    }
}