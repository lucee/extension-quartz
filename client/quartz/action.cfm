<cfscript>
    setting show=false; 
    include "functions.cfm";
    name="quartz-task";
    
    if(isNull(form.action)) {
        if(isNull(url.action)) form.action="add";
        else form.action=url.action;
    }
    
    
    if("resume"==form.action) getQuartz(name).resumeJob(form.name,form.group);
    else if("pause"==form.action) getQuartz(name).pauseJob(form.name,form.group);
    else if("delete"==form.action) getQuartz(name).deleteJob(form.name,form.group);
    else if("stop"==form.action) GatewayAction("quartz-task","stop");
    else if("start"==form.action) GatewayAction("quartz-task","start");
    else if("restart"==form.action) GatewayAction("quartz-task","restart");
    else if("add"==form.action) {
        quartz=getQuartz(name);
        data=deserializeJSON(getHTTPRequestData().content);
        if(isArray(data)) {
            loop array=data item="record" {
                quartz.addJob(record);
            }
        }
        else if(isStruct(data)) {
            quartz.addJob(data);
        }
    }
    else if("copy"==form.action || "edit"==form.action) {
        try {
        data=getQuartz(name).exportJob(form.name,form.group);
        echo(serializeJSON(var:data,compact:false));
        }
        catch(e) {
            echo(serializeJSON(var:e,compact:false));
        }
    }
    </cfscript>