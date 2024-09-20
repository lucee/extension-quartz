component extends="lucee.admin.plugin.Plugin" {
	
	variables.gatewayName="quartz-task";
	
	/**
	 * this function will be called to initialize
	 */
	public function init(struct lang, struct app) {
		//app.note=load();
	}

	public function overview(struct lang, struct app, struct req) {
		variables.state=GatewayState(variables.gatewayName);
		if("running"==variables.state) {
			variables.quartz=getQuartz(variables.gatewayName);
			variables.jobs = variables.quartz.getTriggersAsQuery(false);
			variables.meta = variables.quartz.getMetadataAsStruct();
			
			if(structKeyExists(url, "jobGroup") && structKeyExists(url, "jobName")) {
				try {
					data=variables.quartz.exportJob(url.jobName,url.jobGroup);
					variables.editval=serializeJSON(var:data,compact:false);
				}
				catch(e) {}
			}
		}
	}

	public function update(struct lang, struct app, struct req) {

		
		// stop
		if(structKeyExists(form, "stop")) {
			GatewayAction(variables.gatewayName,"stop",true);
		}
		// start
		else if(structKeyExists(form, "start")) {
			GatewayAction(variables.gatewayName,"start",true);
		}
		// restart
		else if(structKeyExists(form, "restart")) {
			GatewayAction(variables.gatewayName,"stop",true);
			GatewayAction(variables.gatewayName,"start",true);
		}
		return "redirect:overview";
	}
	
	public function getQuartz(name="quartz-task") {
        var state=sendGatewayMessage(name, {
            "action":"state"
        });
        
        if(state!="running") {
            throw "Quartz Scheduler is no running, state is [#state#]";
        }
        var varName="quartzScheduler"&hash(createUniqueID(),"quick");

        // set it to the server scope
        sendGatewayMessage(name, {
            "action":"scheduler"
            ,"variable":"server."&varName
        });
        var quartz=server[varName];
        structDelete(server, varName,false);
        return quartz;
    }


	public function diffFormat(date) {
        //date=dateAdd("s",(60*60)-1, now());
        var diff=dateDiff("s", now(), date);
        if(diff==0) return "now ("&lsTimeFormat(date,"medium")&")";
        var past=false;
        if(diff<0) {
            diff=-diff;
            var past=true;
        }
        if(diff>59) {
            var min=int(diff/60);
            if(min>59) {
                var hour=int(min/60);
                if(hour>23) {
                    if(past) return lsDatetimeFormat(date,"medium");
                    return lsDatetimeFormat(date,"medium");
                }
                var m=min-(hour*60);
                if(past) return hour & " hour#hour==1?'':'s'# #m# minute#m==1?'':'s'# ago ("&lsDatetimeFormat(date,"short")&")" ;
                return "in " & hour & " hour#hour==1?'':'s'# #m# minute#m==1?'':'s'# ("&lsDatetimeFormat(date,"short")&")";
            }
            var s=diff-(min*60);
            if(past) return min & " minute#min==1?'':'s'# #s# second#s==1?'':'s'# ago ("&lsDatetimeFormat(date,"short")&")" ;
            return "in " & min & " minute#min==1?'':'s'# #s# second#s==1?'':'s'# ("&lsDatetimeFormat(date,"short")&")";
        }

        if(past) return diff & " second#diff==1?'':'s'# ago ("&lstimeFormat(date,"medium")&")" ;
        return "in " & diff & " second#diff==1?'':'s'# ("&lsTimeFormat(date,"medium")&")";
    }

    public function getState(name="quartz-task") {
        return sendGatewayMessage("quartz-task", {
            "action":"state"
        });
    }
}