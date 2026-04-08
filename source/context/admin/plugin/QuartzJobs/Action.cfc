component extends="org.lucee.extension.quartz.QuartzPlugin" {
	
	static {
		static.NL="
";
	}
	variables.gatewayName="quartz-task";
	
	/**
	 * this function will be called to initialize
	 */
	public function init(struct lang, struct app) {
		super.init(lang,app);
		session.alwaysNew=true; // we need this, otherwise the action fails
	}

	public function displayTimeRange(numeric seconds) {
		// less than a minute
		if(seconds<60) {
			return "every #seconds# second#seconds==1?'':'s'#"; 
		}
		// exactly in days
		if((seconds mod (60*60*24))==0) {
			var days=int(seconds/(60*60*24));
			return "every #days# day#days==1?'':'s'#"; 
		}
		// exactly in hours
		if((seconds mod (60*60))==0) {
			var hours=int(seconds/(60*60));
			return "every #hours# hour#hours==1?'':'s'#"; 
		}
		// exactly in minutes
		if((seconds mod 60)==0) {
			var minutes=int(seconds/60);
			return "every #minutes# minute#minutes==1?'':'s'#"; 
		}

		var s=seconds;
		var h=0;
		if(seconds>=60*60) {
			h=int(seconds/(60*60));
			seconds=seconds-(h*60*60);
		}
		var m=0;
		if(seconds>=60) {
			m=int(seconds/60);
			seconds=seconds-(m*60);
		}
		
		return "#repeatString("2",0)# every (hh:mm:ss) #stringLen(h)==1?'0':''##h#:#stringLen(m)==1?'0':''##m#:#stringLen(seconds)==1?'0':''##seconds#";
		
		
	}

	public function overview(struct lang, struct app, struct req) {
		try {
			variables.state=GatewayState(variables.gatewayName);
			if("running"==variables.state) {
				variables.quartz=getQuartz(variables.gatewayName);
				variables.jobs = variables.quartz.getTriggersAsQuery(false);
				variables.meta = variables.quartz.getMetadataAsStruct();
				variables.hasClassicTasks=org.lucee.extension.quartz.ClassicMigrator::hasTasks();
				if(structKeyExists(url, "jobGroup") && structKeyExists(url, "jobName")) {
					try {
						var data=variables.quartz.exportJob(url.jobName,url.jobGroup);
						variables.editval=serializeJSON(var:data,compact:false);
					}
					catch(e) {}
				}
			}
		}
		catch(cfcatch) {
			handleException(lang, app, req, cfcatch);
		}
	}

	public function import(struct lang, struct app, struct req) {
		var deleteTasks=(form.importAnd?:"")=="delete";
		var pauseTasks=(form.importAnd?:"")=="pause";
		var jobs=org.lucee.extension.quartz.ClassicMigrator::translateTasksToJobs();
		var quartz=getQuartz(variables.gatewayName);
		if(len(jobs)) {
			loop array=jobs item="local.record" {
				quartz.addJob(record);
			}	
		}
		if(deleteTasks) {
			org.lucee.extension.quartz.ClassicMigrator::deleteTasks();
		}		
		else if(pauseTasks) {
			org.lucee.extension.quartz.ClassicMigrator::pauseTasks();
		}
		return "redirect:overview";
	}

	public function update(struct lang, struct app, struct req) {
		try {
			var rows=[];
			if(structKeyExists(form, "row")) {
				loop array=form.row item="local.id" {
					arrayAppend(rows,{
						name:listFirst(id,":"),
						group:listLast(id,":")
					});
				}
			}
			
			// pause
			if(structKeyExists(form, "pause")) {
				loop array=rows item="local.data" {
					getQuartz(variables.gatewayName).pauseJob(data.name,data.group);
				}
			}
			// resume
			else if(structKeyExists(form, "resume")) {
				loop array=rows item="local.data" {
					getQuartz(variables.gatewayName).resumeJob(data.name,data.group);
				}
			}
			// delete
			else if(structKeyExists(form, "delete")) {
				loop array=rows item="local.data" {
					getQuartz(variables.gatewayName).deleteJob(data.name,data.group);
				}
			}
			// add
			else if(structKeyExists(form, "add")) {
				var quartz=getQuartz(variables.gatewayName);
				try {
					var data=deserializeJSON(form.newval);
				}
				catch(ex) {
					cfthrow (
							message : "failed to parse the given json string with the following exception:"
							,detail : "```#static.NL##ex.message##static.NL#```"
							cause:ex
						);
				}
				if(isArray(data)) {
					loop array=data item="local.record" {
						quartz.addJob(record);
					}
				}
				else if(isStruct(data)) {
					quartz.addJob(data);
				}
			}
			// stop
			else if(structKeyExists(form, "stop")) {
				GatewayAction(variables.gatewayName,"stop");
			}
			// start
			else if(structKeyExists(form, "start")) {
				GatewayAction(variables.gatewayName,"start");
			}
			// restart
			else if(structKeyExists(form, "restart")) {
				GatewayAction(variables.gatewayName,"restart");
			}
		}
		catch(cfcatch) {
			handleException(lang, app, req, cfcatch);
		}
		return "redirect:overview";
	}
	
	public function getQuartz(name="quartz-task") {
        return org.lucee.extension.quartz.Quartz::getInstance(name);
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