component {

    static {
        static.UNIX0 = createDate(1970, 1, 1, "UTC");
        static.BASE_DATE = createDate(1899, 12, 30); // Old scheduler base date
    }

    public static function hasTasks() {
    	// in the future the tag cfschedule may get removed, so we do it directly
        var pc=getPageContext();
        var config=pc.getConfig();
        var scheduler=config.getScheduler();
        return arrayLen(scheduler.getAllScheduleTasks())>0;
    }

    public static function deleteTasks() {
        // in the future the tag cfschedule may get removed, so we do it directly
        var pc=getPageContext();
		var config=pc.getConfig();
        var scheduler=config.getScheduler();
        var tasks = scheduler.getAllScheduleTasks();
        loop array=tasks item="local.task" {
            scheduler.removeScheduleTask(task.getTask(), true); 
		}
    }

    public static function pauseTasks() {
        // in the future the tag cfschedule may get removed, so we do it directly
        var pc=getPageContext();
		var config=pc.getConfig();
        var scheduler=config.getScheduler();
        var tasks = scheduler.getAllScheduleTasks();
        loop array=tasks item="local.task" {
            scheduler.pauseScheduleTask(task.getTask(),true, true); 
		}
    }

    public static function toSlug(str) {
        var str=lcase(arguments.str);
        if(len(str)==0) return createGUID();
        // TODO find a better solution for this
        str=replace(str,"ä","ae","all");
        str=replace(str,"ö","oe","all");
        str=replace(str,"ü","ue","all");
        str=replace(str,"é","e","all");
        str=replace(str,"è","e","all");
        str=replace(str,"à","a","all");
        
        var rtn=new java.lang.StringBuilder();
        var last=false;
        var l=len(str);
        loop from=1 to=l index="local.i" {
            var chr=str[i];
            var nbr=asc(chr);
            // a-z,0-0
            if((nbr>=97 && nbr<=122) || (nbr>=48 && nbr<=57)) {
                if(last)rtn.append("-");
                rtn.append(chr);
                last=false;
            }
            else if(!last && i>1 && (nbr==32 || nbr==45 || nbr==95)) {
                last=true;
            }
        }
        return rtn.toString();
    }

    public static function translateTasksToJobs() {
        cfsetting(show = true);
        
         // in the future the tag cfschedule may get removed, so we do it directly
        var pc=getPageContext();
		var config=pc.getConfig();
        var scheduler=config.getScheduler();
        var tasks = scheduler.getAllScheduleTasks();
        
        var jobs = [];
        loop array=tasks item="local.task" {
            arrayAppend(jobs, translateTaskToJob(task));
        }
        return jobs;
    }

    public static function translateTaskToJob(task) {

        var job = [:];
        job["label"] = task.task?:"";
        job["url"] = task.url.toString();
        job["pause"] = task.isPaused()?:(task.paused?:false);
        job["slug"] = toSlug(task.task?:"");
         
        
    
        // Handle numeric intervals (seconds)
        var interv= task.stringInterval?:(task.interval?:"");
        if (isNumeric(interv)) {
            var intervalSeconds = val(interv);
            var minutes = intervalSeconds / 60;
            var hours = minutes / 60;
            
            // Get start and end times
            var startTime = isDate(task.starttime?:"") ? task.starttime : createTime(0, 0, 0);
            var endTime = isDate(task.endtime?:"") ? task.endtime : createTime(23, 59, 59);
            
            // If interval is >= 1 hour and fits evenly into hours, use cron
            if (hours >= 1 && (intervalSeconds % 3600 == 0)) {
                // Use cron for hourly intervals
                var cronTime = timeFormat(startTime, "s m H");
                var startHour = hour(startTime);
                var endHour = isDate(task.endtime?:"") ? hour(endTime) : 23;
                var hourInterval = int(hours);
                
                // Build hour range properly
                var hourRange = "";
                if (hourInterval == 1) {
                    hourRange = "#startHour#-#endHour#";
                } else {
                    hourRange = "#startHour#-#endHour#/#hourInterval#";
                }
                
                job["cron"] = "#timeFormat(startTime, 's m')# #hourRange# * * ? *";
                
                // Add start/end dates for cron jobs too
                if (isDate(task.startdate?:"")) {
                    job["startAt"] = dateFormat(task.startdate, "YYYY-MM-DD");
                }
                if (isDate(task.enddate?:"")) {
                    job["endAt"] = dateFormat(task.enddate, "YYYY-MM-DD");
                }
            }
            else {
                // Use interval for non-hourly or complex intervals
                job["interval"] = intervalSeconds;
                
                // Add start date/time if specified
                if (isDate(task.startdate?:"") || isDate(task.starttime?:"")) {
                    var startDate = isDate(task.startdate) ? task.startdate : static.UNIX0;
                    if (isDate(task.starttime)) {
                        job["startAt"] = dateFormat(startDate, "YYYY-MM-DD") & "T" & timeFormat(startTime, "HH:MM:SS");
                    } else {
                        job["startAt"] = dateFormat(startDate, "YYYY-MM-DD");
                    }
                }
                
                // Add end date/time if specified
                if (isDate(task.enddate?:"")) {
                    var endDate = task.enddate;
                    if (isDate(task.endtime?:"")) {
                        job["endAt"] = dateFormat(endDate, "YYYY-MM-DD") & "T" & timeFormat(endTime, "HH:MM:SS");
                    } else {
                        job["endAt"] = dateFormat(endDate, "YYYY-MM-DD");
                    }
                }
            }
        }
        // Handle string intervals (daily, weekly, monthly, once)
        else {
            var dayOfWeekStr = "?";
            var dayOfMonth = "*";
            var cronTime = "0 0 0";
            var month = "*";
            var year = "*";
            
            // Get time from starttime
            if (isDate(task.starttime?:"")) {
                cronTime = timeFormat(task.starttime?:"", "s m H");
            }
            
            // Handle different interval types
            if (interv == "daily") {
                dayOfWeekStr = "?";
                dayOfMonth = "*";
            }
            else if (interv == "weekly" && isDate(task.startdate?:"")) {
                // Fix: Calculate correct day of week
                var startDateDayOfWeek = dayOfWeek(task.startdate);
                dayOfWeekStr = dayOfWeekShortAsString(startDateDayOfWeek);
                dayOfMonth = "?";
            }
            else if (interv == "monthly" && isDate(task.startdate?:"")) {
                dayOfWeekStr = "?";
                dayOfMonth = day(task.startdate);
            }
            else if (interv == "once") {
                // For "once" - could use cron or handle specially
                if (isDate(task.startdate?:"")) {
                    dayOfMonth = day(task.startdate);
                    month = month(task.startdate);
                    year = year(task.startdate);
                    dayOfWeekStr = "?";
                }
            }
            
            // Build cron expression: seconds minutes hours day-of-month month day-of-week year
            job["cron"] = "#cronTime# #dayOfMonth# #month# #dayOfWeekStr# #year#";
            
            // Add start/end dates for reference
            if (isDate(task.startdate?:"")) {
                job["startAt"] = dateFormat(task.startdate, "YYYY-MM-DD");
            }
            if (interv != "once" && isDate(task.enddate?:"")) {
                job["endAt"] = dateFormat(task.enddate, "YYYY-MM-DD");
            }
        }
        return job
    }
}