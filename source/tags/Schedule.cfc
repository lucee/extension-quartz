component {
    static {
        static.actions="run,list,update,delete,pause,resume";
    }

    // Meta data
    this.metadata.hint="Provides backward compatibility with the legacy cfschedule tag. This tag emulates the classic Lucee/ColdFusion scheduler interface while using the modern Quartz scheduler underneath. 
	Allows programmatic scheduling of tasks at specified intervals. NOTE: This is a compatibility layer for legacy code - new implementations should use the native Quartz scheduler API directly.";
    this.metadata.attributetype="fixed";
    this.metadata.attributes={
        "action": {
            required:true, 
            type:"string",
            hint:"The scheduler operation to perform. Valid values: run (executes the specified task immediately), list (returns all scheduled tasks), update (creates a new task or updates an existing one), delete (removes the specified task), pause (suspends task execution), resume (restarts a paused task)."
        },
        "result": {
            required:false, 
            type:"string",
            default:"cfschedule",
            hint:"Name of the variable that will contain the query result when action='list'. The query contains columns: task, path, file, startdate, starttime, enddate, endtime, url, component, port, interval, timeout, username, password, proxyserver, proxyport, proxyuser, proxypassword, resolveurl, publish, valid, paused, autoDelete, unique, useragent, slug, map. Default: 'cfschedule'."
        },
        "task": {
            required:false, 
            type:"string",
            hint:"Required for actions: delete, run, pause, resume. The unique name/identifier of the scheduled task to operate on. Can be either the task label or slug."
        },
        "startDate": {
            required:false, 
            type:"date",
            hint:"Required when action='update'. The date when scheduling of the task should start. Must be a valid date object."
        },
        "startTime": {
            required:false, 
            type:"time",
            hint:"Required when action='update'. The time when scheduling of the task starts. Must be a valid time object."
        },
        "endDate": {
            required:false, 
            type:"date",
            hint:"Optional. The date when the scheduled task should stop executing. Task will not run after this date."
        },
        "endTime": {
            required:false, 
            type:"time",
            hint:"Optional. The time when the scheduled task should stop executing on the endDate."
        },
        "URL": {
            required:false, 
            type:"string",
            hint:"Required when action='update'. The URL to be executed by the scheduled task. Must be a fully qualified URL (e.g., http://example.com/task.cfm)."
        },
        "interval": {
            required:false, 
            type:"string",
            hint:"Required when action='update'. The interval at which the task should execute, specified in seconds. Must be a positive number. Minimum interval is 1 second. NOTE: Classic values like 'daily', 'weekly', 'monthly' are not yet supported - use numeric seconds only."
        },
        "paused": {
            required:false, 
            type:"boolean",
            hint:"Optional. If true, the scheduled task is created in a paused state and will not execute until resumed. Default: false."
        },
        "username": {
            required:false, 
            type:"string",
            hint:"Optional. Username for HTTP authentication if the URL is protected."
        },
        "password": {
            required:false, 
            type:"string",
            hint:"Optional. Password for HTTP authentication if the URL is protected."
        },
        "proxyServer": {
            required:false, 
            type:"string",
            hint:"Optional. Host name or IP address of a proxy server through which to route the URL request."
        },
        "proxyPort": {
            required:false, 
            type:"numeric",
            hint:"Optional. The port number on the proxy server. Default is 80."
        },
        "proxyUser": {
            required:false, 
            type:"string",
            hint:"Optional. Username to authenticate with the proxy server."
        },
        "proxyPassword": {
            required:false, 
            type:"string",
            hint:"Optional. Password to authenticate with the proxy server."
        },
        "userAgent": {
            required:false, 
            type:"string",
            hint:"Optional. Custom User-Agent string to send in the HTTP request header."
        },
        "port": {
            required:false, 
            type:"numeric",
            hint:"Optional. The port number on the target server. Default is 80. When used with resolveURL, helps preserve links in retrieved documents."
        }
    };

    function init(required boolean hasEndTag, component parent) {
        return this;
    }

    boolean function onStartTag(required struct attributes, required struct caller) {
        
        // PATCH - Lucee does invoke Application.cfc as part of loading a Gateway, that can cause a infiniti loop, this will be addressed in future Lucee versions, but this prevents it.
        if(isStoreOnlyCall()) {
            return true;
        }
        
        var action=trim(attributes.action);

        // validate required attributes
        if(action != "list" && !structKeyExists(attributes,"task")) {
            throw(
                type="Schedule.MissingAttribute",
                message="Missing required attribute [task] for action [#action#]",
                detail="The 'task' attribute is required for all actions except 'list'. Please specify a task name."
            );
        }

        if (action == "list") {
            doList(attributes,caller);
        }
        else if (action == "update") {
            doUpdate(attributes,caller);
        }
        else if (action == "delete") {
            doDelete(attributes,caller);
        }
        else if (action == "run") {
            doRun(attributes,caller);
        }
        else if (action == "resume") {
            doPauseResume(attributes,caller,false);
        }
        else if (action == "pause") {
            doPauseResume(attributes,caller,true);
        }
        else {
            throw(
                type="Schedule.InvalidAction",
                message="Unsupported action [#action#]",
                detail="Supported actions are: #static.actions#"
            );
        }

        return true;
    }

    private void function doUpdate(required struct attributes, required struct caller) {
        // validate required attributes
        if(!structKeyExists(attributes,"startDate") || !structKeyExists(attributes,"startTime") || !structKeyExists(attributes,"URL") || !structKeyExists(attributes,"interval")) {
            throw(
                type="Schedule.MissingAttribute",
                message="Missing required attributes for action [update]", 
                detail="Required attributes are: task, startDate, startTime, URL, and interval. Please provide all required attributes."
            );
        }
        
        // validate interval format
        if(!isNumeric(attributes.interval) || attributes.interval < 1) {
            throw(
                type="Schedule.InvalidInterval",
                message="Invalid attribute [interval] for action [update]", 
                detail="The interval must be a positive number representing seconds. Classic interval values like 'daily', 'weekly', 'monthly' are not yet supported in the Quartz implementation. Minimum value is 1 second."
            );
        }
        
        // translate the old scheduled task to a job
        systemOutput(attributes,1,1);
        var jobData=org.lucee.extension.quartz.ClassicMigrator::translateTaskToJob(attributes);
        
        systemOutput(jobData,1,1);

        getQuartz().addJob(jobData);
    }

    private void function doRun(required struct attributes, required struct caller) {
        var quartz=getQuartz();
        var raw=quartz.getJobsAsQuery(true);
        var found=false;

        loop query=raw {
            if(raw.label==attributes.task || raw.slug==attributes.task) {
                quartz.runJob(raw.name, raw.group);
                found=true;
                break;
            }
        }
        
        if(!found) {
            throw(
                type="Schedule.TaskNotFound",
                message="Task [#attributes.task#] not found",
                detail="No scheduled task exists with the name or slug [#attributes.task#]. Use action='list' to see all available tasks."
            );
        }
    }
    
    private void function doDelete(required struct attributes, required struct caller) {
        var quartz=getQuartz();
        var raw=quartz.getJobsAsQuery(true);
        var found=false;

        loop query=raw {
            if(raw.label==attributes.task || raw.slug==attributes.task) {
                quartz.deleteJob(raw.name, raw.group);
                found=true;
                break;
            }
        }
        
        if(!found) {
            throw(
                type="Schedule.TaskNotFound",
                message="Task [#attributes.task#] not found",
                detail="No scheduled task exists with the name or slug [#attributes.task#]. Use action='list' to see all available tasks."
            );
        }
    }

    private void function doPauseResume(required struct attributes, required struct caller, required boolean pause) {
        var quartz=getQuartz();
        var raw=quartz.getJobsAsQuery(true);
        var found=false;

        loop query=raw {
            if(raw.label==attributes.task || raw.slug==attributes.task) {
                if(pause) {
                    quartz.pauseJob(raw.name, raw.group);
                }
                else {
                    quartz.resumeJob(raw.name, raw.group);
                }
                found=true;
                break;
            }
        }
        
        if(!found) {
            throw(
                type="Schedule.TaskNotFound",
                message="Task [#attributes.task#] not found",
                detail="No scheduled task exists with the name or slug [#attributes.task#]. Use action='list' to see all available tasks."
            );
        }
    }    

    private void function doList(required struct attributes, required struct caller) {
        var rtnVariable=attributes.result?:"cfschedule";
        var quartz=getQuartz();

        var raw=quartz.getJobsAsQuery(true);
        
        // Create result query with all expected columns for backward compatibility
        var rtn=queryNew("task,path,file,startdate,starttime,enddate,endtime,url,component,port,interval,timeout,username,password,proxyserver,proxyport,proxyuser,proxypassword,resolveurl,publish,valid,paused,autoDelete,unique,useragent,slug,map");
        
        loop query=raw {
            var dataMap=raw.dataMap;
            var row=queryAddRow(rtn);
            
            // Core task identification
            rtn.task[row]=raw.label;
            rtn.slug[row]=raw.slug?:"";
            rtn.url[row]=raw.url;
            rtn.component[row]=raw.component;
            rtn.map[row]=dataMap;
            
            // Extract port from URL if present
            if(len(rtn.url[row])) {
                try {
                    var jurl=new java.net.URL(rtn.url[row]);
                    rtn.port[row]=jurl.getPort() > 0 ? jurl.getPort() : "";
                }
                catch(any e) {
                    rtn.port[row]="";
                }
            }
            
            // Start date/time
            var startAt=dataMap["startAt"]?:""
            if(len(startAt)) {
                rtn.startdate[row]=createODBCDate(startAt);
                rtn.starttime[row]=createODBCTime(startAt);
            } 
            
            // End date/time
            var endAt=dataMap["endAt"]?:""
            if(len(endAt)) {
                rtn.enddate[row]=createODBCDate(endAt);
                rtn.endtime[row]=createODBCTime(endAt);
            }

            // Interval (only for interval-based schedules)
            var schedule=dataMap["schedule"]?:""
            if(schedule=="interval") {
                rtn.interval[row]=dataMap["interval"]?:"";
            }
            
            // Paused state
            rtn.paused[row]=dataMap["pause"]?:false;
            
            // Additional fields from dataMap
            rtn.timeout[row]=dataMap["requestTimeOut"]?:50;
            rtn.username[row]=dataMap["username"]?:"";
            rtn.password[row]=dataMap["password"]?:"";
            rtn.proxyserver[row]=dataMap["proxyServer"]?:"";
            rtn.proxyport[row]=dataMap["proxyPort"]?:"";
            rtn.proxyuser[row]=dataMap["proxyUser"]?:"";
            rtn.proxypassword[row]=dataMap["proxyPassword"]?:"";
            rtn.useragent[row]=dataMap["userAgent"]?:"";
            rtn.resolveurl[row]=dataMap["resolveURL"]?:false;
            rtn.publish[row]=dataMap["publish"]?:false;
            rtn.autoDelete[row]=dataMap["autoDelete"]?:false;
            rtn.unique[row]=dataMap["unique"]?:false;
            
            // File publishing info
            rtn.file[row]=dataMap["file"]?:"";
            rtn.path[row]=dataMap["path"]?:"";
            
            // Always valid for running tasks
            rtn.valid[row]=true;
        }

        caller[rtnVariable]=rtn;
    }

    private function getQuartz(string name="quartz-task") {
        return org.lucee.extension.quartz.Quartz::getInstance(name);
    }

    private function isStoreOnlyCall() {
        local.req=getPageContext().getHttpServletRequest();
        local.client=req.getAttribute("client");
        local.callType=req.getAttribute("call-type");
        
        return find("lucee-gateway-", local.client?:"")>0 && (local.callType?:"")=="store-only";
        
    }
}