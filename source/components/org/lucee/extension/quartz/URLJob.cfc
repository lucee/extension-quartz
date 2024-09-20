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
            rethrow;
        }
    }
}