component {
    
    /**
     * Converts a cron expression into a human-readable format.
     *
     * @cronExpression The cron expression to convert (e.g., "0/5 * 9-17 ? * MON-FRI").
     * @return A human-readable string representing the cron expression (e.g., "Every 5 seconds, every minute, every hour between 9am and 17pm, no specific day of the month, every month, on Monday, Tuesday, Wednesday, Thursday, Friday").
     */
    public static function cronToReadable(cronExpression) {
        // Split the cron expression into its components
        var parts = ListToArray(cronExpression, " ");
        var readable = "";
        
        if (ArrayLen(parts) != 6) {
            return "Invalid cron expression";
        }
        
        // Handle seconds part
        var seconds = parts[1];
        if (seconds == "*") {
            readable &= "Every second";
        } else if (find("*/", seconds)) {
            readable &= "Every " & ListLast(seconds, "/") & " seconds";
        } else {
            readable &= "At second " & seconds;
        }
        readable &= ", ";
        
        // Handle minutes part
        var minutes = parts[2];
        if (minutes == "*") {
            readable &= "every minute";
        } else if (find("*/", minutes)) {
            readable &= "every " & ListLast(minutes, "/") & " minutes";
        } else {
            readable &= "at minute " & minutes;
        }
        readable &= ", ";
        
        // Handle hours part
        var hours = parts[3];
        if (hours == "*") {
            readable &= "every hour";
        } else if (find("-", hours)) {
            readable &= "every hour between " & ListFirst(hours, "-") & "am and " & ListLast(hours, "-") & "pm";
        } else {
            readable &= "at hour " & hours;
        }
        readable &= ", ";
        
        // Handle day of month part
        var dayOfMonth = parts[4];
        if (dayOfMonth == "*") {
            readable &= "every day of the month";
        } else if (dayOfMonth == "?") {
            readable &= "no specific day of the month";
        } else {
            readable &= "on day " & dayOfMonth;
        }
        readable &= ", ";
        
        // Handle month part
        var month = parts[5];
        if (month == "*") {
            readable &= "every month";
        } else {
            readable &= "in month " & month;
        }
        readable &= ", ";
        
        // Handle day of week part
        var dayOfWeek = parts[6];
        if (dayOfWeek == "*") {
            readable &= "every day of the week";
        } else if (dayOfWeek == "?") {
            readable &= "no specific day of the week";
        } else {
            var days = {
                "SUN": "Sunday",
                "MON": "Monday",
                "TUE": "Tuesday",
                "WED": "Wednesday",
                "THU": "Thursday",
                "FRI": "Friday",
                "SAT": "Saturday"
            };
            var readableDays = [];
            for (var day in ListToArray(dayOfWeek, ",")) {
                readableDays.append(days[day]);
            }
            readable &= "on " & ArrayToList(readableDays, ", ");
        }
        
        return readable;
    }

    /**
     * True for the one-shot SimpleTrigger Quartz creates in triggerJob(): name MT_* in the DEFAULT
     * group, repeat count 0 and no interval. A configured interval trigger is also a SimpleTrigger,
     * but it repeats and lives in the cfm group, so it is not matched here.
     */
    public static boolean function isManualTrigger(required trigger) {
        var key=arguments.trigger.getKey();
        if(!isNull(key) && key.getGroup()=="DEFAULT" && left(key.getName(), 3)=="MT_") return true;
        if(isSimpleTrigger(arguments.trigger)) {
            // one fire, no repeat interval: not a configured schedule
            if(arguments.trigger.getRepeatCount()==0 && arguments.trigger.getRepeatInterval()==0) return true;
        }
        return false;
    }

    // CronTriggerImpl / SimpleTriggerImpl; the class name avoids loading the interface through another classloader
    public static boolean function isCronTrigger(required trigger) {
        return find("CronTrigger", arguments.trigger.getClass().getName()) > 0;
    }

    public static boolean function isSimpleTrigger(required trigger) {
        return find("SimpleTrigger", arguments.trigger.getClass().getName()) > 0;
    }

    /**
     * Schedule columns for one trigger. The trigger type decides the columns: a CronTrigger never
     * falls through to getRepeatInterval(), and a SimpleTrigger never has getExpressionSummary()
     * called on it. The job data map's schedule string is not used, because a manual run shares
     * the job (and that string) with the configured trigger.
     */
    public static struct function describeSchedule(required trigger, dataMap) {
        if(isManualTrigger(arguments.trigger)) {
            return { "schedule":"", "scheduleType":"manual", "scheduleTranslated":"pending manual run" };
        }
        if(isCronTrigger(arguments.trigger)) {
            var cron=arguments.trigger.getCronExpression();
            if(!len(cron ?: "") && !isNull(arguments.dataMap)) cron=arguments.dataMap["cron"] ?: "";
            return { "schedule":cron ?: "", "scheduleType":"cron", "scheduleTranslated":arguments.trigger.getExpressionSummary() };
        }
        var seconds=0;
        if(isSimpleTrigger(arguments.trigger)) seconds=int(arguments.trigger.getRepeatInterval()/1000);
        else if(!isNull(arguments.dataMap) && isNumeric(arguments.dataMap["interval"] ?: "")) seconds=int(arguments.dataMap["interval"]);
        return {
            "schedule":seconds,
            "scheduleType":"interval",
            "scheduleTranslated":"every " & (seconds==1?" second":seconds & " seconds")
        };
    }

    public static function getTriggersAsQuery(Quartz quartz, boolean extended=false) {
        // same fallback as QuartzSupport: a COMPLETED manual trigger is not a pending run
        arguments.quartz.removeCompletedManualTriggers();
        var triggers=quartz.getTriggers();
        var jobs={};
        loop array=quartz.getJobs() item="local.job" {
            jobs[job.getKey().getName()]=job;
        }

        var names=["jobLabel","jobName","jobGroup","schedule","scheduleType","scheduleTranslated","endpoint","state","mayFireAgain","startTime","endTime","previousFireTime","nextFireTime","finalFireTime"];
        if(extended){
            arrayAppend(names, "key");
            arrayAppend(names, "jobDataMap");
            arrayAppend(names, "jobKey");
            arrayAppend(names, "jobDetail");
        }

        var qry=queryNew(names);
        loop array=triggers item="local.trigger" {
            var row=queryAddRow(qry);
            var job=jobs[trigger.getJobKey().getName()];
            var dataMap=job.getJobDataMap();
            var state=quartz.getScheduler().getTriggerState(trigger.getKey());
            querySetCell(qry, "jobLabel", dataMap["label"]?:"",row);
            querySetCell(qry, "jobName", job.getName(),row);
            querySetCell(qry, "jobGroup", job.getGroup(),row);
            if(structKeyExists(dataMap, "url")) querySetCell(qry, "endpoint", dataMap["url"],row);
            else if(structKeyExists(dataMap, "component")) querySetCell(qry, "endpoint", dataMap["component"],row);
            querySetCell(qry, "state", state.name(),row);
            querySetCell(qry, "mayFireAgain", trigger.mayFireAgain(),row);
            querySetCell(qry, "startTime", trigger.getStartTime(),row);
            querySetCell(qry, "endTime", trigger.getEndTime(),row);
            querySetCell(qry, "previousFireTime", trigger.getPreviousFireTime(),row);
            querySetCell(qry, "nextFireTime", trigger.getNextFireTime(),row);
            querySetCell(qry, "finalFireTime", trigger.getFinalFireTime(),row);
            var schedule=describeSchedule(trigger, dataMap);
            querySetCell(qry, "schedule", schedule.schedule,row);
            querySetCell(qry, "scheduleType", schedule.scheduleType,row);
            querySetCell(qry, "scheduleTranslated", schedule.scheduleTranslated,row);
            if(extended){
                querySetCell(qry, "key", trigger.getKey(),row);
                querySetCell(qry, "jobDataMap", job.getJobDataMap(),row);
                querySetCell(qry, "jobKey", job.getKey(),row);
                querySetCell(qry, "jobDetail", job,row);
            }
        }
        return qry;
    }

    public static function exportJobs(Quartz quartz, boolean extended=false) {
        var triggers=quartz.getTriggers();
        var jobs={};
        loop array=quartz.getJobs() item="local.job" {
            jobs[job.getKey().getName()]=job;
        }

        var arr=[];
        loop array=triggers item="local.trigger" {
            // triggerJob() leaves a one-shot beside the configured trigger; writing it would duplicate the job
            if(isManualTrigger(trigger)) continue;
            var sct=[:];
            arrayAppend(arr, sct);
            var job=jobs[trigger.getJobKey().getName()];
            var dataMap=job.getJobDataMap();
            var state=quartz.getScheduler().getTriggerState(trigger.getKey());
            if(extended) {
                sct["name"]=trigger.getJobKey().getName();
                sct["group"]=job.getGroup();
            }
            
            sct["label"]=dataMap["label"];
            if(structKeyExists(dataMap, "url")) sct["url"]=dataMap["url"];
            else if(structKeyExists(dataMap, "component")) sct["component"]=dataMap["component"];
            
            if(structKeyExists(dataMap, "cron")) sct["cron"]=dataMap["cron"];
            else if(structKeyExists(dataMap, "interval")) sct["interval"]=dataMap["interval"];

            var time=trigger.getStartTime();
            if(!isNull(time) && time>now()) sct["startAt"]= time;
            var time=trigger.getEndTime()
            if(!isNull(time) ) sct["endAt"]= time;
            
            sct["pause"]="PAUSED"==state.name();
        }
        return arr;
    }

    public static function exportJob(Quartz quartz, string name, string group) {
        loop array=exportJobs(quartz, true) item="local.data" {
            if(data.group==group && data.name==name) {
                structDelete(data, "name");
                structDelete(data, "group");
                return data;
            }
        }
    }

    public static function getJobsAsQuery(Quartz quartz, boolean extended=false) {
        var jobs=quartz.getJobs();
        var names=["label","name","group","url","component"];
        if(extended){
            arrayAppend(names, "dataMap");
            arrayAppend(names, "key");
            arrayAppend(names, "detail");
        }
            

        var qry=queryNew(names);
        loop array=jobs item="local.job" {
            var row=queryAddRow(qry);
            var dataMap=job.getJobDataMap();
            querySetCell(qry, "label", dataMap["label"]?:"",row);
            querySetCell(qry, "name", job.getName(),row);
            querySetCell(qry, "group", job.getGroup(),row);
            if(structKeyExists(dataMap, "url")) querySetCell(qry, "url", dataMap["url"],row);
            else if(structKeyExists(dataMap, "component")) querySetCell(qry, "component", dataMap["component"],row);

            if(extended){
                querySetCell(qry, "dataMap", dataMap,row);
                querySetCell(qry, "key", job.getKey(),row);
                querySetCell(qry, "detail", job,row);
            }
        }
        return qry;
    }

    public static function getJobsAsStruct(Quartz quartz) {
        var jobs=[:];
        loop array=quartz.getJobs() item="local.job" {
            jobs[job.getName()]=job;
        }
        return jobs;
    }

    public static function getTriggerForJob(Quartz quartz, string name, string group, boolean extended=false) {
        var triggers=getTriggersAsQuery( quartz, extended); 
        var jobs=getJobsAsQuery( quartz, extended);
        var data=[:];
        var manual=[:];
        loop query=triggers {
            if(name==triggers.jobName && group==triggers.jobGroup) {
                var row=[:];
                loop array=queryColumnArray(triggers) item="local.col" {
                    row[col]=triggers[col];
                }
                // a pending manual run shares the job; callers want the configured schedule
                if((triggers.scheduleType?:"")=="manual") {
                    if(!structCount(manual)) manual=row;
                    continue;
                }
                data=row;
                break;
            }
        }
        if(!structCount(data)) data=manual;
        loop query=jobs {
            if(name==jobs.name && group==jobs.group) {
                loop array=queryColumnArray(jobs) item="local.col" {
                    data[col]=jobs[col];
                }
                break;
            }
        }


        if(structCount(data)) return data;
        throw "no matching trigger found";
    }

    public static function resolveEnvVar(coll, doDuplicate=true) {
        var org=coll;
        if(doDuplicate) coll=duplicate(coll,true);
        loop collection=coll index="local.k" item="local.v" {
            if(!isSimpleValue(v)) {
                resolveEnvVar(v,false);
                continue;
            }
            v=trim(v);
            if(left(v,2)=='${' && right(v,1)=='}') {
                v = trim(mid(v,3,len(v)-3));
                coll[k]=server.system.environment[v];
            }
        }
        return coll;
    }



    public static function asString(obj) {
        return obj&"";
    }

    public static function getMetadata(Quartz quartz) {
        var meta=[:];
        var raw=quartz.getMetadata();
        if(!isNull(raw)) {
            // Get scheduler metadata
            //meta["raw"] = raw;
            meta["jobStoreClass"] = raw.getJobStoreClass().getName();
            meta["jobStoreSupportsPersistence"] = raw.isJobStoreSupportsPersistence();
            meta["jobStoreClustered"] = raw.isJobStoreClustered();
            meta["version"] = raw.getVersion();
            meta["summary"] = raw.getSummary();
            meta["runningSince"] = raw.getRunningSince();
            meta["schedulerName"] = raw.getSchedulerName();
            meta["schedulerInstanceId"] = raw.getSchedulerInstanceId();
            meta["numberOfJobsExecuted"] = raw.getNumberOfJobsExecuted();
            
            // type
            if(find("jdbcjobstore", meta["jobStoreClass"])) meta["jobStoreType"]="JDBC";
            else if(find("RedisJobStore", meta["jobStoreClass"])) meta["jobStoreType"]="Redis";
            else if(find("RAMJobStore", meta["jobStoreClass"])) meta["jobStoreType"]="Memory";
            else  meta["jobStoreType"]=listLast(meta["jobStoreClass"],".");
        }
        return meta;
	}

    public static function isJobDataMapEqual(left, right) {
        if(len(left)!=len(right)) return false;

        loop collection=left index="local.k" item="local.v" {
            if(!structKeyExists(right, k)) return false;
            if(v!=right[k]) return false;
        }
        return true;
    }

    /**
     * Resolves the request timeout (in seconds) from a job data map.
     * Accepts the native `timeout` key or the classic cfschedule `requestTimeOut` key.
     * Falls back to defaultTimeout when the value is missing or not a positive number.
     *
     * @dataMap The JobDataMap (or struct) holding the job configuration
     * @defaultTimeout The timeout in seconds to use when none is configured (default 50)
     */
    public static numeric function resolveTimeout(required dataMap, numeric defaultTimeout=50) {
        var raw=dataMap.containsKey("timeout")?dataMap.get("timeout"):(dataMap.containsKey("requestTimeOut")?dataMap.get("requestTimeOut"):"");
        var timeout=isNumeric(raw)?val(raw):arguments.defaultTimeout;
        return timeout>0?timeout:arguments.defaultTimeout;
    }

    public static function getListeners(quartz) {
        var raw=quartz.getListeners();
        var config=quartz.getConfig();
        
        var confListeners={};
        if(structKeyExists(config, "listener")) {
            loop array=config.listener item="local.l" {
                var tmp=duplicate(l);
                structDelete(tmp, "component",false);
                confListeners[l.component?:""]=tmp;
            }
        }
        
        var listeners=[];
        if(!isNull(raw)) {
            loop array=raw item="local.record" {
                var cfc=record._toComponent();
                var path=getMetaData(cfc).fullname;
                var conf=confListeners[path]?:"";
                
                var desc="";
                try {
                    desc=cfc.getDescription();
                }
                catch(e) {}
                arrayAppend(listeners, {
                    name:record.getName()
                    ,path:path
                    ,description:desc
                    ,config:conf
                });
            }
        }
        return listeners;
    }
}