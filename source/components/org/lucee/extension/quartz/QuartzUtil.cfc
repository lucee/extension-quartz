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

    public static function getTriggersAsQuery(Quartz quartz, boolean extended=false) {
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
            // cron
            if(dataMap["schedule"]=="cron") {
                querySetCell(qry, "schedule", dataMap["cron"]?:"",row);
                querySetCell(qry, "scheduleType", "cron",row);
                querySetCell(qry, "scheduleTranslated", trigger.getExpressionSummary(),row);
            }
            else {
                querySetCell(qry, "schedule", dataMap["interval"]?:"",row);
                querySetCell(qry, "scheduleType", "interval",row);
                var s=int(trigger.getRepeatInterval()/1000);
                querySetCell(qry, "scheduleTranslated", "every " &(s==1?" second":s&" seconds"),row);
            }
            if(extended){
                querySetCell(qry, "key", trigger.getKey(),row);
                querySetCell(qry, "jobDataMap", job.getJobDataMap(),row);
                querySetCell(qry, "jobKey", job.getKey(),row);
                querySetCell(qry, "jobDetail", job,row);
            }
        }
        return qry;
    }

    public static function exportJobs(Quartz quartz) {
        var triggers=quartz.getTriggers();
        var jobs={};
        loop array=quartz.getJobs() item="local.job" {
            jobs[job.getKey().getName()]=job;
        }

        var arr=[];
        loop array=triggers item="local.trigger" {
            var sct=[:];
            arrayAppend(arr, sct);
            var job=jobs[trigger.getJobKey().getName()];
            var dataMap=job.getJobDataMap();
            var state=quartz.getScheduler().getTriggerState(trigger.getKey());
            
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
        loop query=triggers {
            if(name==triggers.jobName && group==triggers.jobGroup) {
                loop array=queryColumnArray(triggers) item="local.col" {
                    data[col]=triggers[col];
                }
                break;
            }
        }
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
}